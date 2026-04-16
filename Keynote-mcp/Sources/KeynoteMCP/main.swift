import MCP
import Foundation

// MARK: - Entry Point

// Log startup to stderr (stdout is reserved for MCP JSON-RPC)
fputs("[keynote-mcp] Starting KeynoteMCP server\n", stderr)

// Build the server
let server = Server(
    name: "keynote-mcp",
    version: "1.0.0",
    capabilities: Server.Capabilities(
        tools: Server.Capabilities.Tools(listChanged: false)
    )
)

// Register tool list handler
await server.withMethodHandler(ListTools.self) { _ in
    return ListTools.Result(tools: ToolDefinitions.all)
}

// Register tool call handler
await server.withMethodHandler(CallTool.self) { params in
    fputs("[keynote-mcp] Calling tool: \(params.name)\n", stderr)
    do {
        let result = try ToolDispatcher.dispatch(name: params.name, arguments: params.arguments)
        fputs("[keynote-mcp] Tool \(params.name) succeeded\n", stderr)
        return CallTool.Result(
            content: [.text(text: result, annotations: nil, _meta: nil)],
            isError: false
        )
    } catch {
        // Surface the full error message so Claude can see exactly what went wrong
        fputs("[keynote-mcp] Tool \(params.name) failed: \(error.localizedDescription)\n", stderr)
        return CallTool.Result(
            content: [.text(text: "ERROR: \(error.localizedDescription)", annotations: nil, _meta: nil)],
            isError: true
        )
    }
}

// Connect via stdio and run until the client disconnects
let transport = StdioTransport()
try await server.start(transport: transport)
fputs("[keynote-mcp] Connected via stdio\n", stderr)

// Keep alive until transport closes
await server.waitUntilCompleted()
fputs("[keynote-mcp] Server shutting down\n", stderr)
