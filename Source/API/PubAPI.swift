//
//  VerseAPI+Pubs.swift
//  FBTT
//
//  Created by Christoph on 6/11/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

typealias PubAPICompletion = ((Bool, APIError?) -> Void)

// MARK:- Base implementation

class PubAPI: API {

    // TODO: get this token from onboarding/verify signup?
    var headers: APIHeaders = ["Verse-Authorize-Pub": Environment.Pub.token]
    var httpPort: Int = 443
    var httpHost = Environment.Pub.host
    var httpPathPrefix = "/FollowbackAfterOnboardingTest"

    init() {}

    func send(method: APIMethod,
              path: String,
              query: [URLQueryItem] = [],
              body: Data? = nil,
              headers: APIHeaders? = nil,
              completion: @escaping APICompletion)
    {
        assert(Thread.isMainThread)
        assert(query.isEmpty || body == nil, "Cannot use query and body at the same time")
        guard path.beginsWithSlash else { completion(nil, .invalidPath(path)); return }

        var components = URLComponents()
        components.scheme = "https"
        components.host = self.httpHost
        components.path = "\(self.httpPathPrefix)\(path)"
        components.port = self.httpPort
        
        guard let url = components.url else { completion(nil, .invalidURL); return }

        var request = URLRequest(url: url)
        request.add(self.headers)
        if let headers = headers { request.add(headers) }
        request.httpMethod = method.rawValue
        request.httpBody = body

        URLSession.shared.dataTask(with: request) {
            data, response, error in
            let apiError = response?.httpStatusCodeError ?? APIError.optional(error)
            DispatchQueue.main.async { completion(data, apiError) }
            Log.optional(apiError, from: response)
        }.resume()
    }
}

// MARK:- Specific endpoints

extension PubAPI {

    func pubsAreOnline(completion: @escaping PubAPICompletion) {
        self.get(path: "/v1/ping") {
            data, error in
            completion(data?.isPong() ?? false, error)
        }
    }

    func invitePubsToFollow(_ identity: Identity,
                                   completion: @escaping PubAPICompletion)
    {
        let headers: APIHeaders = ["Verse-New-Key": identity]
        self.get(path: "/v1/invite", headers: headers) {
            data, error in
            completion(error == nil, error)
        }
    }
}

// MARK:- Custom decoding

fileprivate extension Data {

    func isPong() -> Bool {
        guard let pong = String(data: self, encoding: .utf8) else { return false }
        return pong.contains("pong")
    }
}
