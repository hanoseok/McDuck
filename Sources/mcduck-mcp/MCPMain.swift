import Foundation
import McDuckCore
import McDuckMCP

/// The real usage source: runs ccusage through McDuckCore's client.
private struct CcusageUsageProvider: UsageProviding {
    let client = CcusageClient()

    func report() async throws -> UsageReport {
        try await client.loadDailyReport()
    }
}

/// `mcduck-mcp`: a stdio MCP server. Reads newline-delimited JSON-RPC requests
/// from stdin and writes newline-delimited responses to stdout, the framing the
/// MCP stdio transport expects.
@main
struct MCDuckMCPServer {
    static func main() async {
        let handler = MCPRequestHandler(provider: CcusageUsageProvider())
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()

        while let line = readLine(strippingNewline: true) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
                continue
            }

            let response: JSONRPCResponse?
            do {
                let request = try decoder.decode(JSONRPCRequest.self, from: data)
                response = await handler.handle(request)
            } catch {
                response = .failure(
                    id: nil,
                    error: JSONRPCError(code: JSONRPCError.parseError, message: "Parse error")
                )
            }

            if let response, let out = try? encoder.encode(response) {
                write(out)
            }
        }
    }

    /// Writes one JSON-RPC message followed by a newline, directly to stdout so
    /// nothing is left in a block buffer when the output is a pipe.
    private static func write(_ data: Data) {
        var line = data
        line.append(0x0A)
        try? FileHandle.standardOutput.write(contentsOf: line)
    }
}
