import Foundation
import McDuckCore

/// Supplies the parsed ccusage report to the MCP tools. Abstracted so the
/// request handler can be driven by a fake in tests without running ccusage.
public protocol UsageProviding: Sendable {
    func report() async throws -> UsageReport
}
