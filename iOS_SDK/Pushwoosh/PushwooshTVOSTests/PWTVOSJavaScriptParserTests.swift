//
//  PWTVOSJavaScriptParserTests.swift
//  PushwooshTVOSTests
//
//  Created by André Kis on 23.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import XCTest
@testable import PushwooshTVOS

@available(tvOS 11.0, *)
final class PWTVOSJavaScriptParserTests: XCTestCase {

    var parser: PWTVOSJavaScriptParser!

    override func setUpWithError() throws {
        try super.setUpWithError()
        parser = PWTVOSJavaScriptParser()
    }

    override func tearDownWithError() throws {
        parser = nil
        try super.tearDownWithError()
    }

    func testParsePostEventWithSingleQuotes() throws {
        let jsCode = "Pushwoosh.postEvent('ButtonClicked', {category: 'ui', value: 123})"
        let result = parser.parseJavaScriptCall(jsCode)

        if case .postEvent(let name, let attributes) = result {
            XCTAssertEqual(name, "ButtonClicked")
            XCTAssertNotNil(attributes)
            XCTAssertEqual(attributes?["category"] as? String, "ui")
            XCTAssertEqual(attributes?["value"] as? Int, 123)
        } else {
            XCTFail("Expected postEvent call")
        }
    }

    func testParsePostEventWithDoubleQuotes() throws {
        let jsCode = "Pushwoosh.postEvent(\"AppOpened\", {\"source\": \"push\"})"
        let result = parser.parseJavaScriptCall(jsCode)

        if case .postEvent(let name, let attributes) = result {
            XCTAssertEqual(name, "AppOpened")
            XCTAssertEqual(attributes?["source"] as? String, "push")
        } else {
            XCTFail("Expected postEvent call")
        }
    }

    func testParsePostEventWithoutAttributes() throws {
        let jsCode = "Pushwoosh.postEvent('SimpleEvent')"
        let result = parser.parseJavaScriptCall(jsCode)

        if case .postEvent(let name, _) = result {
            XCTAssertEqual(name, "SimpleEvent")
        } else {
            XCTFail("Expected postEvent call")
        }
    }

    func testParseSendTagsWithSingleQuotes() throws {
        let jsCode = "Pushwoosh.sendTags({username: 'john_doe', age: 30, premium: true})"
        let result = parser.parseJavaScriptCall(jsCode)

        if case .sendTags(let tags) = result {
            XCTAssertEqual(tags["username"] as? String, "john_doe")
            XCTAssertEqual(tags["age"] as? Int, 30)
            XCTAssertEqual(tags["premium"] as? Bool, true)
        } else {
            XCTFail("Expected sendTags call")
        }
    }

    func testParseSendTagsWithDoubleQuotes() throws {
        let jsCode = "Pushwoosh.sendTags({\"email\": \"test@example.com\"})"
        let result = parser.parseJavaScriptCall(jsCode)

        if case .sendTags(let tags) = result {
            XCTAssertEqual(tags["email"] as? String, "test@example.com")
        } else {
            XCTFail("Expected sendTags call")
        }
    }

    func testParseGetTags() throws {
        let jsCode = "Pushwoosh.getTags()"
        let result = parser.parseJavaScriptCall(jsCode)

        if case .getTags = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected getTags call")
        }
    }

    func testParseSetEmailWithSingleQuotes() throws {
        let jsCode = "Pushwoosh.setEmail('user@example.com')"
        let result = parser.parseJavaScriptCall(jsCode)

        if case .setEmail(let email) = result {
            XCTAssertEqual(email, "user@example.com")
        } else {
            XCTFail("Expected setEmail call")
        }
    }

    func testParseSetEmailWithDoubleQuotes() throws {
        let jsCode = "Pushwoosh.setEmail(\"admin@test.com\")"
        let result = parser.parseJavaScriptCall(jsCode)

        if case .setEmail(let email) = result {
            XCTAssertEqual(email, "admin@test.com")
        } else {
            XCTFail("Expected setEmail call")
        }
    }

    func testParseCloseInApp() throws {
        let jsCode = "Pushwoosh.closeInApp()"
        let result = parser.parseJavaScriptCall(jsCode)

        if case .closeInApp = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected closeInApp call")
        }
    }

    func testParseOpenAppSettings() throws {
        let jsCode = "Pushwoosh.openAppSettings()"
        let result = parser.parseJavaScriptCall(jsCode)

        if case .openAppSettings = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected openAppSettings call")
        }
    }

    func testParseRegisterForPushNotifications() throws {
        let jsCode = "Pushwoosh.registerForPushNotifications()"
        let result = parser.parseJavaScriptCall(jsCode)

        if case .registerForPushNotifications = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected registerForPushNotifications call")
        }
    }

    func testParseUnregisterForPushNotifications() throws {
        let jsCode = "Pushwoosh.unregisterForPushNotifications()"
        let result = parser.parseJavaScriptCall(jsCode)

        if case .unregisterForPushNotifications = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected unregisterForPushNotifications call")
        }
    }

    func testParseGetHwid() throws {
        let jsCode = "Pushwoosh.getHwid()"
        let result = parser.parseJavaScriptCall(jsCode)

        if case .getHwid = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected getHwid call")
        }
    }

    func testParseGetVersion() throws {
        let jsCode = "Pushwoosh.getVersion()"
        let result = parser.parseJavaScriptCall(jsCode)

        if case .getVersion = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected getVersion call")
        }
    }

    func testParseGetApplication() throws {
        let jsCode = "Pushwoosh.getApplication()"
        let result = parser.parseJavaScriptCall(jsCode)

        if case .getApplication = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected getApplication call")
        }
    }

    func testParseGetUserId() throws {
        let jsCode = "Pushwoosh.getUserId()"
        let result = parser.parseJavaScriptCall(jsCode)

        if case .getUserId = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected getUserId call")
        }
    }

    func testParseGetRichmediaCode() throws {
        let jsCode = "Pushwoosh.getRichmediaCode()"
        let result = parser.parseJavaScriptCall(jsCode)

        if case .getRichmediaCode = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected getRichmediaCode call")
        }
    }

    func testParseGetDeviceType() throws {
        let jsCode = "Pushwoosh.getDeviceType()"
        let result = parser.parseJavaScriptCall(jsCode)

        if case .getDeviceType = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected getDeviceType call")
        }
    }

    func testParseGetMessageHash() throws {
        let jsCode = "Pushwoosh.getMessageHash()"
        let result = parser.parseJavaScriptCall(jsCode)

        if case .getMessageHash = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected getMessageHash call")
        }
    }

    func testParseGetInAppCode() throws {
        let jsCode = "Pushwoosh.getInAppCode()"
        let result = parser.parseJavaScriptCall(jsCode)

        if case .getInAppCode = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected getInAppCode call")
        }
    }

    func testParseUnknownCall() throws {
        let jsCode = "SomeOtherLibrary.doSomething()"
        let result = parser.parseJavaScriptCall(jsCode)

        if case .unknown = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected unknown call")
        }
    }

    func testParseWithExtraWhitespace() throws {
        let jsCode = "  Pushwoosh.postEvent  (  'EventName'  ,  {key: 'value'}  )  "
        let result = parser.parseJavaScriptCall(jsCode)

        if case .postEvent(let name, let attributes) = result {
            XCTAssertEqual(name, "EventName")
            XCTAssertEqual(attributes?["key"] as? String, "value")
        } else {
            XCTFail("Expected postEvent call")
        }
    }

    func testParseComplexNestedJSON() throws {
        let jsCode = "Pushwoosh.sendTags({user: {name: 'John', age: 30}, preferences: {theme: 'dark'}})"
        let result = parser.parseJavaScriptCall(jsCode)

        if case .sendTags(let tags) = result {
            XCTAssertNotNil(tags["user"])
            XCTAssertNotNil(tags["preferences"])
        } else {
            XCTFail("Expected sendTags call")
        }
    }
}
