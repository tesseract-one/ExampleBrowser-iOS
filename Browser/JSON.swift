//
//  JSON.swift
//  Browser
//
//  Created by Yehor Popovych on 3/17/19.
//  Copyright © 2019 Daniel Leping. All rights reserved.
//

import Foundation
import Web3

extension JSONValue {
    init(_ dict: Dictionary<String, JSONValueEncodable>) {
        self = .object(dict.mapValues{$0.encode()})
    }
    
    public var jsonData: Data {
        switch self {
        case .null: return "null".data(using: .utf8)!
        case .bool(let bool): return (bool ? "true" : "false").data(using: .utf8)!
        case .number(let num): return "\(num)".data(using: .utf8)!
        case .string(let str):
            let fixed = str.replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(fixed)\"".data(using: .utf8)!
        default:
            return try! JSONEncoder().encode(self)
        }
    }
}

public protocol JSONValueEncodable {
    func encode() -> JSONValue
}

extension JSONValue: JSONValueEncodable {
    public func encode() -> JSONValue {
        return self
    }
}

extension Int: JSONValueEncodable {
    public func encode() -> JSONValue {
        return .number(Double(self))
    }
}

extension Double: JSONValueEncodable {
    public func encode() -> JSONValue {
        return .number(self)
    }
}

extension String: JSONValueEncodable {
    public func encode() -> JSONValue {
        return .string(self.replacingOccurrences(of: "\"", with: "\\\""))
    }
}

extension Bool: JSONValueEncodable {
    public func encode() -> JSONValue {
        return .bool(self)
    }
}

extension Array: JSONValueEncodable where Element: JSONValueEncodable {
    public func encode() -> JSONValue {
        return .array(self.map { $0.encode() })
    }
}

extension Dictionary: JSONValueEncodable where Key == String, Value: JSONValueEncodable {
    public func encode() -> JSONValue {
        return .object(self.mapValues{$0.encode()})
    }
}
extension Optional: JSONValueEncodable where Wrapped: JSONValueEncodable {
    public func encode() -> JSONValue {
        switch self {
        case .none:
            return .null
        case .some(let wrpd):
            return wrpd.encode()
        }
    }
}
