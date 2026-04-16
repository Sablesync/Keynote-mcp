# KeynoteMCP

A Swift MCP (Model Context Protocol) server that lets Claude Code control Apple Keynote via AppleScript over stdio.

## Requirements

- macOS 13+
- Xcode 16+ / Swift 6.0+
- Apple Keynote installed

## Build

```bash
cd KeynoteMCP
swift build -c release
```

The compiled binary will be at:
```
.build/release/keynote-mcp
```

Optionally install it somewhere permanent:
```bash
cp .build/release/keynote-mcp /usr/local/bin/keynote-mcp
```

## Configure Claude Code

Add to your project's `.claude/settings.json`:

```json
{
  "mcpServers": {
    "keynote": {
      "command": "/usr/local/bin/keynote-mcp",
      "args": []
    }
  }
}
```

Or use the absolute path to `.build/release/keynote-mcp` if you haven't installed it globally.

Then restart Claude Code. You should see `keynote` in your MCP server list.

## Permissions

On first run, macOS will ask you to grant Automation permissions to Terminal (or whichever app runs Claude Code) to control Keynote. Accept the prompt or go to:

> **System Settings → Privacy & Security → Automation**

and enable the toggle for Keynote under your terminal app.

## Available Tools

### Create & Edit
| Tool | Description |
|---|---|
| `create_presentation` | Create a new `.key` file with optional theme |
| `add_slide` | Append or insert a slide at a position |
| `set_slide_content` | Set title and/or body text on a slide |
| `add_text_box` | Add a free-floating text box to a slide |
| `add_image` | Add an image file to a slide |
| `set_theme` | Change the presentation theme |

### Read
| Tool | Description |
|---|---|
| `get_presentation_info` | Name, slide count, theme |
| `list_slides` | All slides with index and title |
| `get_slide_content` | Title, body, and presenter notes for one slide |

### Run & Export
| Tool | Description |
|---|---|
| `open_presentation` | Open a `.key` file in Keynote |
| `start_slideshow` | Start the slideshow |
| `stop_slideshow` | Stop the slideshow |
| `export_presentation` | Export to PDF, PowerPoint, HTML, or QuickTime |

## Example Prompts

```
Create a 5-slide pitch deck at ~/Desktop/pitch.key using the Black theme.
Slide 1: Title "AVELA AI", subtitle "On-device intelligence for Apple platforms"
Slide 2–5: add relevant content sections, then export it to PDF.
```

```
Open ~/Desktop/pitch.key and list all slides with their titles.
```

## Architecture

```
KeynoteMCP/
├── Package.swift
└── Sources/KeynoteMCP/
    ├── main.swift            # stdio MCP server entry point
    ├── KeynoteBridge.swift   # AppleScript automation layer
    ├── ToolDefinitions.swift # MCP tool schemas
    └── ToolDispatcher.swift  # Routes tool calls to bridge
```

The server speaks JSON-RPC 2.0 over stdio using the official
[modelcontextprotocol/swift-sdk](https://github.com/modelcontextprotocol/swift-sdk).
All AppleScript errors are surfaced as MCP error responses with full detail.

## Extending

To add a new tool:
1. Add a `ToolName` constant in `ToolDefinitions.swift`
2. Add the `Tool(...)` definition to `ToolDefinitions.all`
3. Add the AppleScript implementation to `KeynoteBridge.swift`
4. Add the dispatch `case` in `ToolDispatcher.dispatch`
