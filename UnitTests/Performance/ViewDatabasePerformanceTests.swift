//
//  ViewDatabasePerformanceTests.swift
//  UnitTests
//
//  Created by Matthew Lorentz on 1/13/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import XCTest

// swiftlint:disable implicitly_unwrapped_optional force_try

/// Tests to measure performance of `ViewDatabase`.
class ViewDatabasePerformanceTests: XCTestCase {

    var dbURL: URL!
    var viewDatabase = ViewDatabase()
    let testFeed = DatabaseFixture.bigFeed
    var dbDirPath: String!
    var maxAge: Double!
    
    override func setUpWithError() throws {
        try setUpSmallDB()
        try super.setUpWithError()
    }
    
    override func tearDownWithError() throws {
        viewDatabase.close()
        try FileManager.default.removeItem(at: self.dbURL)
        try super.tearDownWithError()
    }
    
    func setUpEmptyDB(user: Identity) throws {
        viewDatabase.close()
        viewDatabase = ViewDatabase()
        let dbDir = FileManager.default.temporaryDirectory.appendingPathComponent("ViewDatabaseBenchmarkTests")
        dbURL = dbDir.appendingPathComponent("schema-built\(ViewDatabase.schemaVersion).sqlite")
        try? FileManager.default.removeItem(at: dbURL)
        try FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        
        // open DB
        dbDirPath = dbDir.absoluteString.replacingOccurrences(of: "file://", with: "")
        maxAge = -60 * 60 * 24 * 30 * 48  // 48 month (so roughtly until 2023)
        try viewDatabase.open(path: dbDirPath, user: user, maxAge: maxAge)
    }
    
    func setUpSmallDB() throws {
        try loadDB(named: "Feed_big", user: testFeed.owner)
    }
    
    func loadDB(named dbName: String, user: Identity) throws {
        viewDatabase.close()
        viewDatabase = ViewDatabase()
        let dbDir = FileManager.default.temporaryDirectory.appendingPathComponent("ViewDatabaseBenchmarkTests")
        dbURL = dbDir.appendingPathComponent("schema-built\(ViewDatabase.schemaVersion).sqlite")
        try? FileManager.default.removeItem(at: dbURL)
        try FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let sqliteURL = try XCTUnwrap(Bundle(for: type(of: self)).url(forResource: dbName, withExtension: "sqlite"))
        try FileManager.default.copyItem(at: sqliteURL, to: dbURL)
        
        // open DB
        dbDirPath = dbDir.absoluteString.replacingOccurrences(of: "file://", with: "")
        maxAge = -60 * 60 * 24 * 30 * 48  // 48 month (so roughtly until 2023)
        try viewDatabase.open(path: dbDirPath, user: user, maxAge: maxAge)
    }
    
    func resetSmallDB() throws {
        try tearDownWithError()
        try setUpSmallDB()
    }

    /// Measures the peformance of `fillMessages(msgs:)`. This is the function that is called to copy posts from go-ssb
    /// to sqlite.
    func testFillMessagesGivenSmallDB() throws {
        let data = self.data(for: DatabaseFixture.bigFeed.fileName)

        // get test messages from JSON
        let msgs = try JSONDecoder().decode([KeyValue].self, from: data)
        XCTAssertNotNil(msgs)
        XCTAssertEqual(msgs.count, 2500)
        
        measureMetrics([XCTPerformanceMetric.wallClockTime], automaticallyStartMeasuring: false) {
            try! setUpEmptyDB(user: testFeed.owner)
            startMeasuring()
            try? viewDatabase.fillMessages(msgs: msgs)
            stopMeasuring()
        }
    }

    func testDiscoverAlgorithmGivenSmallDb() throws {
        let strategy = PostsAlgorithm(wantPrivate: false, onlyFollowed: false)
        measureMetrics([XCTPerformanceMetric.wallClockTime], automaticallyStartMeasuring: false) {
            try! resetSmallDB()
            startMeasuring()
            let keyValues = try? self.viewDatabase.recentPosts(strategy: strategy, limit: 100, offset: 0)
            XCTAssertEqual(keyValues?.count, 100)
            stopMeasuring()
        }
    }
    
    func testCurrentPostsAlgorithmGivenSmallDb() throws {
        let strategy = PostsAlgorithm(wantPrivate: false, onlyFollowed: true)
        measureMetrics([XCTPerformanceMetric.wallClockTime], automaticallyStartMeasuring: false) {
            try! resetSmallDB()
            startMeasuring()
            let keyValues = try? self.viewDatabase.recentPosts(strategy: strategy, limit: 100, offset: 0)
            XCTAssertEqual(keyValues?.count, 91)
            stopMeasuring()
        }
    }
    
    func testPostsAndContactsAlgorithmGivenSmallDB() throws {
        viewDatabase.close()
        let strategy = PostsAndContactsAlgorithm()
        measureMetrics([XCTPerformanceMetric.wallClockTime], automaticallyStartMeasuring: false) {
            try! resetSmallDB()
            startMeasuring()
            let keyValues = try? self.viewDatabase.recentPosts(strategy: strategy, limit: 100, offset: 0)
            XCTAssertEqual(keyValues?.count, 100)
            stopMeasuring()
        }
    }
    
    func testGetFollows() {
        measureMetrics([XCTPerformanceMetric.wallClockTime], automaticallyStartMeasuring: false) {
            try! resetSmallDB()
            startMeasuring()
            for _ in 0..<30 {
                // artificially inflate times to meet 0.1 second threshold, otherwise test will never fail.
                for feed in testFeed.identities {
                    _ = try? self.viewDatabase.getFollows(feed: feed) as [Identity]
                }
            }
            stopMeasuring()
            try? resetSmallDB()
        }
    }
    
    func testFeedForIdentity() {
        measureMetrics([XCTPerformanceMetric.wallClockTime], automaticallyStartMeasuring: false) {
            try! resetSmallDB()
            startMeasuring()
            _ = try? self.viewDatabase.feed(for: testFeed.identities[0])
            stopMeasuring()
        }
    }

    /// This test performs a lot of feed loading (reads) while another thread is writing to the SQLite database. The
    /// reader threads are expected to finish before the long write does, verifying that we are optimizing for
    /// reading (see ADR #4).
    func testSimultanousReadsAndWrites() throws {
        let data = self.data(for: DatabaseFixture.bigFeed.fileName)
        let msgs = try JSONDecoder().decode([KeyValue].self, from: data)
        
        measureMetrics([XCTPerformanceMetric.wallClockTime], automaticallyStartMeasuring: false) {
            try! resetSmallDB()
            startMeasuring()
            var writerIsFinished = false
            let writesFinished = self.expectation(description: "Writes finished")
            let writer = {
                try? self.viewDatabase.fillMessages(msgs: msgs)
                
                // Synchronize the writerIsFinished property because readers may be using it from other threads.
                objc_sync_enter(self)
                writerIsFinished = true
                objc_sync_exit(self)
                writesFinished.fulfill()
            }
            
            var readers = [() -> Void]()
            for i in 0..<100 {
                let readFinished = self.expectation(description: "Read \(i) finished")
                let reader = { [self] in
                    _ = try? self.viewDatabase.feed(for: self.testFeed.identities[0])
                    
                    // Verify that we weren't blocked by the writer.
                    objc_sync_enter(self)
                    XCTAssertEqual(writerIsFinished, false)
                    objc_sync_exit(self)
                    readFinished.fulfill()
                }
                
                readers.append(reader)
            }
            
            DispatchQueue(label: "write").async {
                writer()
            }
            
            for (i, reader) in readers.enumerated() {
                DispatchQueue(label: "readQueue \(i)").async {
                    reader()
                }
            }
            
            waitForExpectations(timeout: 10)
            stopMeasuring()
        }
    }
}
