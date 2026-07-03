//
//  AnyCodableTests.swift
//  PushwooshLiveActivitiesTests
//
//  Created by André Kis on 20.05.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import XCTest
@testable import PushwooshLiveActivities

final class AnyCodableTests: XCTestCase {

    /// Verifies string values survive encode-decode roundtrip.
    func test_encode_decode_string_roundtrip() throws {
        let value: AnyCodable = "hello"
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        XCTAssertEqual(decoded.asString(), "hello")
    }

    /// Verifies integer values survive encode-decode roundtrip.
    func test_encode_decode_int_roundtrip() throws {
        let value: AnyCodable = 42
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        XCTAssertEqual(decoded.asInt(), 42)
    }

    /// Verifies double values survive encode-decode roundtrip.
    func test_encode_decode_double_roundtrip() throws {
        let value: AnyCodable = 3.14
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        XCTAssertEqual(decoded.asDouble() ?? 0.0, 3.14, accuracy: 0.0001)
    }

    /// Verifies booleans survive encode-decode roundtrip.
    func test_encode_decode_bool_roundtrip() throws {
        let value: AnyCodable = true
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        XCTAssertEqual(decoded.asBool(), true)
    }

    /// Verifies null encodes and decodes back to NSNull.
    func test_encode_decode_null_roundtrip() throws {
        let value = AnyCodable(NSNull())
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        XCTAssertTrue(decoded.value is NSNull)
    }

    /// Verifies arrays of mixed scalars survive encode-decode roundtrip.
    func test_encode_decode_array_roundtrip() throws {
        let value: AnyCodable = AnyCodable([1, 2, 3])
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        let arr = decoded.asArray()
        XCTAssertEqual(arr?.count, 3)
        XCTAssertEqual(arr?[0].asInt(), 1)
        XCTAssertEqual(arr?[2].asInt(), 3)
    }

    /// Verifies dictionaries survive encode-decode roundtrip.
    func test_encode_decode_dict_roundtrip() throws {
        let value: AnyCodable = AnyCodable(["key": "val"])
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        XCTAssertEqual(decoded.asDict()?["key"]?.asString(), "val")
    }

    /// L10 regression guard — Void and NSNull both equal NSNull, only one match arm remains.
    func test_equality_void_and_nsnull() throws {
        let nullA = AnyCodable(NSNull())
        let nullB = AnyCodable(NSNull())
        let voidA: AnyCodable = AnyCodable(nil as Any?)

        XCTAssertEqual(nullA, nullB)
        XCTAssertEqual(voidA, AnyCodable(nil as Any?))
    }

    /// Verifies mixed type equality returns false.
    func test_equality_mixed_types() throws {
        let intVal: AnyCodable = 1
        let strVal: AnyCodable = "1"

        XCTAssertNotEqual(intVal, strVal)
    }

    /// Verifies hash stability across equal values.
    func test_hash_stability() throws {
        let a: AnyCodable = "abc"
        let b: AnyCodable = "abc"

        var hasherA = Hasher()
        a.hash(into: &hasherA)
        var hasherB = Hasher()
        b.hash(into: &hasherB)

        XCTAssertEqual(hasherA.finalize(), hasherB.finalize())
    }

    // MARK: - NSNumber path

    // The typeless `defaultStart` / `DefaultLiveActivityAttributes` flow is fed `[String: Any]` from
    // Obj-C / cross-platform plugins (RN/Flutter/Unity), so dictionary values arrive as NSNumber,
    // not Swift Int/Bool. These pin down that an NSNumber integer is NOT mis-encoded as a Bool.

    /// An NSNumber integer 1 must encode as `1`, not `true`.
    func test_encode_nsNumberIntOne_encodesAsInt_notBool() throws {
        let json = String(data: try JSONEncoder().encode(AnyCodable(NSNumber(value: 1))), encoding: .utf8)!
        XCTAssertEqual(json, "1", "NSNumber(1) must encode as 1, got: \(json)")
    }

    /// An NSNumber integer 0 must encode as `0`, not `false`.
    func test_encode_nsNumberIntZero_encodesAsInt_notBool() throws {
        let json = String(data: try JSONEncoder().encode(AnyCodable(NSNumber(value: 0))), encoding: .utf8)!
        XCTAssertEqual(json, "0", "NSNumber(0) must encode as 0, got: \(json)")
    }

    /// A non-0/1 NSNumber integer encodes as that integer (control).
    func test_encode_nsNumberIntFortyTwo_encodesAsInt() throws {
        let json = String(data: try JSONEncoder().encode(AnyCodable(NSNumber(value: 42))), encoding: .utf8)!
        XCTAssertEqual(json, "42", "got: \(json)")
    }

    /// An NSNumber boolean true must encode as `true`.
    func test_encode_nsNumberBoolTrue_encodesAsBool() throws {
        let json = String(data: try JSONEncoder().encode(AnyCodable(NSNumber(value: true))), encoding: .utf8)!
        XCTAssertEqual(json, "true", "got: \(json)")
    }

    /// An NSNumber double must encode as a number.
    func test_encode_nsNumberDouble_encodesAsDouble() throws {
        let json = String(data: try JSONEncoder().encode(AnyCodable(NSNumber(value: 3.14))), encoding: .utf8)!
        XCTAssertEqual(json, "3.14", "got: \(json)")
    }

    /// A nested-dictionary value that is an NSNumber integer must still encode as a number, not a bool.
    /// The `[String: Any?]` encode arm re-wraps each value into AnyCodable, so the NSNumber guard has to
    /// re-apply one level down — this is the real cross-platform payload shape (`[String: Any]` with
    /// NSNumber values from Obj-C / RN / Flutter / Unity).
    func test_encode_nestedDict_nsNumberIntOne_encodesAsInt_notBool() throws {
        let json = String(data: try JSONEncoder().encode(AnyCodable(["count": NSNumber(value: 1)])), encoding: .utf8)!
        XCTAssertEqual(json, "{\"count\":1}", "nested NSNumber(1) must encode as 1, got: \(json)")
    }
}
