//
//  GRPCFraming.swift
//  PushwooshGRPC
//
//  Created by André Kis on 27.01.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import Foundation

enum GRPCFraming {

    static func frame(_ message: Data) -> Data {
        var frame = Data(capacity: 5 + message.count)
        frame.append(0) // compression flag
        var length = UInt32(message.count).bigEndian
        frame.append(Data(bytes: &length, count: 4))
        frame.append(message)
        return frame
    }

    static func parse(_ data: Data) -> Data? {
        guard data.count >= 5 else { return nil }

        let length = data.subdata(in: 1..<5).withUnsafeBytes { ptr in
            UInt32(bigEndian: ptr.load(as: UInt32.self))
        }

        let maxMessageSize: UInt32 = 10 * 1024 * 1024
        guard length <= maxMessageSize else { return nil }

        let messageStart = 5
        let messageEnd = messageStart + Int(length)
        guard data.count >= messageEnd else { return nil }

        return data.subdata(in: messageStart..<messageEnd)
    }
}
