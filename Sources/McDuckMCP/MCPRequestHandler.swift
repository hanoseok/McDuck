import Foundation

/// Handles MCP JSON-RPC requests over an injected `UsageProviding` source.
/// Pure (no stdio): the executable feeds it decoded requests and writes the
/// encoded responses, which keeps the protocol logic unit-testable.
public struct MCPRequestHandler: Sendable {
    private let provider: any UsageProviding
    private let serverName: String
    private let serverVersion: String
    private let protocolVersion: String

    public init(
        provider: any UsageProviding,
        serverName: String = "mcduck",
        serverVersion: String = "0.1.0",
        protocolVersion: String = "2025-06-18"
    ) {
        self.provider = provider
        self.serverName = serverName
        self.serverVersion = serverVersion
        self.protocolVersion = protocolVersion
    }

    /// Produces a response, or `nil` for notifications (requests without an id),
    /// which JSON-RPC says must not be answered.
    public func handle(_ request: JSONRPCRequest) async -> JSONRPCResponse? {
        switch request.method {
        case "initialize":
            return .success(id: request.id, result: initializeResult())
        case "tools/list":
            return .success(id: request.id, result: .object(["tools": MCPTools.definitions()]))
        case "tools/call":
            return await callTool(request)
        case "ping":
            return .success(id: request.id, result: .object([:]))
        default:
            // Notifications (e.g. notifications/initialized) carry no id and are
            // simply acknowledged by sending nothing back.
            guard request.id != nil else { return nil }
            return .failure(
                id: request.id,
                error: JSONRPCError(code: JSONRPCError.methodNotFound, message: "Method not found: \(request.method)")
            )
        }
    }

    private func initializeResult() -> JSONValue {
        .object([
            "protocolVersion": .string(protocolVersion),
            "capabilities": .object([
                "tools": .object([:])
            ]),
            "serverInfo": .object([
                "name": .string(serverName),
                "version": .string(serverVersion)
            ])
        ])
    }

    private func callTool(_ request: JSONRPCRequest) async -> JSONRPCResponse? {
        guard let name = request.params?["name"]?.stringValue else {
            return .failure(
                id: request.id,
                error: JSONRPCError(code: JSONRPCError.invalidParams, message: "Missing tool name")
            )
        }
        let arguments = request.params?["arguments"]

        do {
            let report = try await provider.report()
            let result = try MCPTools.call(name: name, arguments: arguments, report: report)
            return .success(id: request.id, result: result)
        } catch let error as JSONRPCError {
            return .failure(id: request.id, error: error)
        } catch {
            // Surface ccusage/provider failures as a tool error result rather
            // than a transport error so the client can show the message.
            let message = error.localizedDescription
            let result = JSONValue.object([
                "content": .array([
                    .object(["type": .string("text"), "text": .string("Failed to load usage: \(message)")])
                ]),
                "isError": .bool(true)
            ])
            return .success(id: request.id, result: result)
        }
    }
}
