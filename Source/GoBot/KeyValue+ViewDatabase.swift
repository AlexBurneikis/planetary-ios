//
//  KeyValue+ViewDatabase.swift
//  Planetary
//
//  Created by Matthew Lorentz on 6/30/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite

extension KeyValue {
    
    /// Creates a KeyValue from a database row. Copied from ViewDatabase.swift, still very messy. It's unclear what
    /// columns are required for this function to succeed, but in general I think it's messages joined with message keys
    /// joined with the post type (i.e posts) joined with authors. See `ViewDatabase.fillMessages` for a working
    /// example.
    /// - Parameters:
    ///   - row: The SQLite row that should be used to make the KeyValue.
    ///   - database: A database instance that will be used to fetch supplementary information.
    ///   - useNamespacedTables: A boolean that tells the initializer to include table names before some common column
    ///     names that appear in multiple tables like `name`.
    ///   - hasMentionColumns: A flag that lets the parser know whether the row includes the columns `hasblobs`,
    ///     `has_feed_mentions`, `has_message_mentions`. These columns are an optimization to speed up the loading of
    ///     Posts.
    ///   - hasReplies: A flag that lets the parse know whether the row `replies_count` and `replies` columns as an
    ///     optimization for loading post replies.
    init?(
        row: Row,
        database: ViewDatabase,
        useNamespacedTables: Bool = false,
        hasMentionColumns: Bool = true,
        hasReplies: Bool = true
    ) throws {
        // tried 'return try row.decode()'
        // but failed - see https://github.com/VerseApp/ios/issues/29
        
        let db = database
        
        let msgKey = try row.get(db.colKey)
        let msgAuthor = try row.get(db.colAuthor)

        guard let value = try Value(row: row, db: db, hasMentionColumns: hasMentionColumns) else {
            return nil
        }

        var keyValue = KeyValue(
            key: msgKey,
            value: value,
            timestamp: try row.get(db.colReceivedAt),
            offChain: try row.get(db.colOffChain)
        )
        let aboutName = useNamespacedTables ? db.abouts[db.colName] : db.colName
        keyValue.metadata.author.about = About(
            about: msgAuthor,
            name: try row.get(aboutName),
            description: try row.get(db.colDescr),
            imageLink: try row.get(db.colImage)
        )
        if hasReplies {
            let numberOfReplies = try row.get(Expression<Int>("replies_count"))
            let replies = try row.get(Expression<String?>("replies"))
            let abouts = replies?.split(separator: ";").map { About(about: String($0)) } ?? []
            keyValue.metadata.replies.count = numberOfReplies
            keyValue.metadata.replies.abouts = abouts
        }
        keyValue.metadata.isPrivate = try row.get(db.colDecrypted)
        self = keyValue
    }
}
