//
//  User.swift
//  FBTT
//
//  Created by Christoph on 6/6/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import SwiftyMarkdown

struct Person: Codable, Equatable {

    let bio: String?
    let id: String
    let identity: Identity
    let image: String?
    let image_url: String?
    let in_directory: Bool?
    let name: String
    let shortcode: String?

    var attributedBio: NSAttributedString {
        let md = SwiftyMarkdown(string: self.bio ?? "")
        return md.attributedString()
    }

    static func == (lhs: Person, rhs: Person) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Person: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.identity)
    }
}
