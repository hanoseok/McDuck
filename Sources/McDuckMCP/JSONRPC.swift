import Foundation

/// JSON-RPC 2.0 request id: a number or a string. Notifications omit it.
public enum JSONRPCID: Codable, Sendable, Equatable {
    case int(Int)
    case string(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        }
    }
}

/// A decoded JSON-RPC 2.0 request (or notification when `id` is nil).
public struct JSONRPCRequest: Decodable, Sendable, Equatable {
    public let id: JSONRPCID?
    public let method: String
    public let params: JSONValue?

    public init(id: JSONRPCID?, method: String, params: JSONValue?) {
        self.id = id
        self.method = method
        self.params = params
    }

    private enum CodingKeys: String, CodingKey {
        case id, method, params
    }
}

/// A JSON-RPC 2.0 error object.
public struct JSONRPCError: Error, Sendable, Equatable {
    public let code: Int
    public let message: String
    public let data: JSONValue?

    public init(code: Int, message: String, data: JSONValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }

    // Standard codes used by the server.
    public static let parseError = -32700
    public static let invalidRequest = -32600
    public static let methodNotFound = -32601
    public static let invalidParams = -32602
    public static let internalError = -32603
}

/// A JSON-RPC 2.0 response carrying either a result or an error.
public struct JSONRPCResponse: Encodable, Sendable, Equatable {
    public let id: JSONRPCID?
    public let result: JSONValue?
    public let error: JSONRPCError?

    public static func success(id: JSONRPCID?, result: JSONValue) -> JSONRPCResponse {
        JSONRPCResponse(id: id, result: result, error: nil)
    }

    public static func failure(id: JSONRPCID?, error: JSONRPCError) -> JSONRPCResponse {
        JSONRPCResponse(id: id, result: nil, error: error)
    }

    private init(id: JSONRPCID?, result: JSONValue?, error: JSONRPCError?) {
        self.id = id
        self.result = result
        self.error = error
    }

    private enum CodingKeys: String, CodingKey {
        case jsonrpc, id, result, error
    }

    private enum ErrorKeys: String, CodingKey {
        case code, message, data
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("2.0", forKey: .jsonrpc)
        // id is always present in the response (null when unknown).
        if let id {
            try container.encode(id, forKey: .id)
        } else {
            try container.encodeNil(forKey: .id)
        }
        if let result {
            try container.encode(result, forKey: .result)
        }
        if let error {
            var errorContainer = container.nestedContainer(keyedBy: ErrorKeys.self, forKey: .error)
            try errorContainer.encode(error.code, forKey: .code)
            try errorContainer.encode(error.message, forKey: .message)
            if let data = error.data {
                try errorContainer.encode(data, forKey: .data)
            }
        }
    }
}
