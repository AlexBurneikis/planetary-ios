//
//  RecentStrategy.swift
//  Planetary
//
//  Created by Martin Dutra on 12/4/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite

protocol FeedStrategy {

    var connection: Connection { get set }

    var currentUserID: Int64 { get set }

    func countNumberOfRecentPosts() throws -> Int
    
    func recentPosts(limit: Int, offset: Int?) throws -> [KeyValue]

    func recentIdentifiers(limit: Int, offset: Int?) throws -> [MessageIdentifier]
}

