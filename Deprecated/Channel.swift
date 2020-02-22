//
//  Channel.swift
//  FBTTUnitTests
//
//  Created by Christoph on 1/28/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

@available(*, deprecated)
struct Channel: ContentCodable {

    let type: ContentType = .channel
    let name: String
    let root: Identifier?

    init(name: String, root: String?) {
        self.name = name
        self.root = root
    }

    init(hashtag: String) {
        self.name = hashtag.withoutHashPrefix
        self.root = nil
    }
}

extension Channel {

    var isModern: Bool {
        return self.root != nil
    }

    var hashtag: String {
        return "#\(self.name)"
    }
}

extension Channel: Markdownable {

    var markdown: String {
        return self.hashtag
    }
}
