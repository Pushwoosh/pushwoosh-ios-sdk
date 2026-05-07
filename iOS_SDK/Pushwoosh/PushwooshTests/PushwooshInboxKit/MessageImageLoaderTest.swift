//
//  MessageImageLoaderTest.swift
//  PushwooshTests
//
//  Created by André Kis on 29.04.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import XCTest
import UIKit
@testable import PushwooshInboxKit

class MessageImageLoaderTest: XCTestCase {

    override func setUp() {
        super.setUp()
        URLProtocolStub.reset()
        URLProtocol.registerClass(URLProtocolStub.self)
    }

    override func tearDown() {
        URLProtocol.unregisterClass(URLProtocolStub.self)
        super.tearDown()
    }

    /// Verifies that the second load for the same URL hits the cache instead of the network.
    func testCachesImageOnSecondCall() {
        let pixel = UIImage(systemName: "circle.fill") ?? UIImage()
        guard let pngData = pixel.pngData() else {
            XCTFail("Could not encode placeholder image.")
            return
        }
        URLProtocolStub.responseData = pngData

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)
        let loader = MessageImageLoader(session: session)
        loader.clearCache()

        let url = "https://example.invalid/inbox-image.png"
        let imageView = UIImageView()

        let firstLoad = expectation(description: "first")
        loader.load(url, into: imageView, placeholder: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { firstLoad.fulfill() }
        wait(for: [firstLoad], timeout: 2.0)

        let firstHits = URLProtocolStub.requestCount

        let secondLoad = expectation(description: "second")
        let secondImageView = UIImageView()
        loader.load(url, into: secondImageView, placeholder: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { secondLoad.fulfill() }
        wait(for: [secondLoad], timeout: 2.0)

        XCTAssertEqual(URLProtocolStub.requestCount, firstHits, "Second load should hit cache, not network.")
    }
}

private class URLProtocolStub: URLProtocol {

    static var responseData: Data?
    static var requestCount: Int = 0

    static func reset() {
        responseData = nil
        requestCount = 0
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        URLProtocolStub.requestCount += 1
        if let data = URLProtocolStub.responseData,
           let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil) {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
