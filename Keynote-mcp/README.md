# KeynoteMCP

A Swift MCP (Model Context Protocol) server that lets Claude Code control Apple Keynote via AppleScript and Accessibility APIs over stdio.

---

## Requirements

- macOS 13+
- Xcode 16+ / Swift 6.0+
- Apple Keynote installed

---

## Installation

### Option A — Homebrew (recommended)

```bash
brew tap Sablesync/tap
brew install keynote-mcp
```

The binary is installed at `/opt/homebrew/bin/keynote-mcp`.

### Option B — Build from source

```bash
git clone https://github.com/Sablesync/Keynote-mcp.git
cd Keynote-mcp/Keynote-mcp
swift build -c release
```

The compiled binary will be at:
```
.build/release/keynote-mcp
```

Optionally copy it to a permanent location:
```bash
cp .build/release/keynote-mcp /usr/local/bin/keynote-mcp
```

---

## Connect to Claude Code

Run the following command using the path that matches your install method:

**Homebrew install:**
```bash
claude mcp add keynote-mcp /opt/homebrew/bin/keynote-mcp
```

**Built from source:**
```bash
claude mcp add keynote-mcp /path/to/Keynote-mcp/Keynote-mcp/.build/release/keynote-mcp
```

Then restart Claude Code. Verify the server is connected by running `/mcp` inside Claude Code — you should see `keynote-mcp` listed as active.

---

## Permissions

Two permissions are required on first use:

### 1. Accessibility
Go to **System Settings → Privacy & Security → Accessibility** and enable your terminal app (Terminal, iTerm2, etc.).

### 2. Automation
On first run macOS will prompt you to allow your terminal to control Keynote. Click **OK**, or go to **System Settings → Privacy & Security → Automation** and enable **Keynote** under your terminal app.

---

## Available Tools

### Create & Edit
| Tool | Description |
|---|---|
| `create_presentation` | Create a new `.key` file with optional theme |
| `add_slide` | Append or insert a slide at a position |
| `set_slide_content` | Set title and/or body text on a slide |
| `add_text_box` | Add a free-floating text box to a slide |
| `add_image` | Add an image file to a slide |
| `add_3d_object` | Insert a USDZ/USDA/USDC 3D object onto a slide |
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

---

## Example Prompts

### Create a pitch deck from scratch
```
Create a 6-slide pitch deck at ~/Desktop/pitch.key using the Black theme.
Slide 1: Title "AVELA AI", subtitle "On-device intelligence for Apple platforms"
Slide 2: Title "The Problem", body "Current AI requires cloud — slow, expensive, private data exposed"
Slide 3: Title "Our Solution", body "On-device inference with sub-100ms latency"
Slide 4: Title "Market Opportunity", body "$42B TAM by 2027"
Slide 5: Title "Team", body "Ex-Apple, Google, and OpenAI engineers"
Slide 6: Title "Ask", body "Raising $3M seed round"
Then export it to PDF at ~/Desktop/pitch.pdf
```

### Open and read an existing presentation
```
Open ~/Desktop/pitch.key and list all slides with their titles.
```

### Edit a specific slide
```
Open ~/Desktop/pitch.key, go to slide 3, and update the body text to
include three bullet points about our traction metrics.
```

### Insert a 3D object
```
Open ~/Desktop/pitch.key, go to slide 2, and insert the 3D model at ~/Desktop/product.usdz.
```

### Export to multiple formats
```
Export ~/Desktop/pitch.key as both a PDF and a PowerPoint file to ~/Desktop/.
```

---

## Troubleshooting

### `keynote-mcp` not showing in `/mcp`
- Restart Claude Code after running `claude mcp add`
- Verify the binary path is correct: `ls /opt/homebrew/bin/keynote-mcp`
- Check Claude Code logs for startup errors

### "Keynote is not running"
- Open Keynote and load a presentation before calling any tool
- Use `open_presentation` as the first tool call to open your file

### "Accessibility permission denied"
- Go to **System Settings → Privacy & Security → Accessibility**
- Make sure your terminal app is listed and toggled **on**
- If it's not listed, drag your terminal app into the list manually

### "Could not find menu item 'Insert > 3D Object'"
- The `add_3d_object` tool requires Keynote to be the frontmost app
- Make sure no other dialog is open in Keynote before calling the tool

### Build fails with PCH module cache error
This happens when the project folder is moved. Fix by clearing the build cache:
```bash
rm -rf .build
swift build -c release
```

---

## Architecture

```
Keynote-mcp/
├── Package.swift
└── Sources/KeynoteMCP/
    ├── main.swift                # stdio MCP server entry point
    ├── KeynoteBridge.swift       # AppleScript automation layer
    ├── AccessibilityBridge.swift # AX API layer for 3D object insertion
    ├── ToolDefinitions.swift     # MCP tool schemas
    └── ToolDispatcher.swift      # Routes tool calls to bridge
```

The server communicates via JSON-RPC 2.0 over stdio using the official [modelcontextprotocol/swift-sdk](https://github.com/modelcontextprotocol/swift-sdk). All AppleScript and Accessibility errors are surfaced as MCP error responses with full detail.

---

## Extending

To add a new tool:
1. Add a constant in `ToolDefinitions.swift`
2. Add the `Tool(...)` definition to `ToolDefinitions.all`
3. Add the implementation to `KeynoteBridge.swift` or `AccessibilityBridge.swift`
4. Add the dispatch `case` in `ToolDispatcher.dispatch`
