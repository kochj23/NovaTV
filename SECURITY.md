# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x     | Yes                |

## Reporting a Vulnerability

If you discover a security vulnerability in NovaTV, please report it responsibly.

**Contact:** Open a GitHub issue with the label `security` or email the repository owner.

**Response Time:** Security issues will be triaged within 48 hours.

## Security Features

- **Local network only** — NovaTV connects exclusively to the local Nova Control dashboard
- **No cloud services** — All data sourced from the local network
- **No external API calls** — No connections to OpenAI, Anthropic, or any cloud provider
- **Read-only consumer** — NovaTV only reads dashboard state, never writes or controls services
- **No credentials stored** — No API keys, tokens, or passwords in the app
- **No analytics or tracking** — Zero telemetry, zero third-party SDKs

## Architecture Security

NovaTV is a pure display client:

1. Connects to local Nova Control dashboard via WebSocket (port 37450)
2. Receives JSON state updates every 2.5 seconds
3. Renders data on screen
4. No data is sent upstream (read-only)

## Dependencies

NovaTV has zero third-party dependencies. It uses only:
- Foundation/SwiftUI/Combine (Apple standard libraries)
