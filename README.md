# OpenClaw Operator for iOS

Native SwiftUI operator client scaffold for a self-hosted OpenClaw gateway.

## What is implemented

- `OpenClawOperatorApp/` contains the iPhone app shell, 4-tab navigation, SwiftData persistence, Keychain storage, APNs registration flow, and the primary Chat / Sessions / Ops / Settings surfaces.
- `Shared/` contains the reusable core layer: domain models, JSON-RPC envelope handling, WebSocket transport, connection state machine, live `GatewayClient`, repository protocol, diagnostics capture, and a mock client for previews or offline demos.
- `Tests/OpenClawCoreTests/` contains baseline tests for JSON encoding, connection state transitions, and repository behavior.
- `project.yml` defines a complete XcodeGen project with a framework target for `OpenClawCore`, the iOS app target, and an iOS unit test bundle.

## Architecture

- `OpenClawCore` is intentionally UI-free. It owns `GatewayProfile`, `GatewayClient`, `CapabilitySet`, `OpsSnapshot`, diagnostics, caching, and the repository abstraction consumed by the app.
- `OpenClawOperatorApp` owns SwiftUI state, system integrations, and local persistence. `AppModel` is the single state coordinator for the current Beta scope.
- The connection lifecycle follows the plan state machine:
  - `idle -> connecting -> challenged -> authenticated -> subscribed -> degraded/reconnecting -> offline`
- Capability gating is enforced in the app UI. Chat remains available with a limited token, while Ops shows an empty state when the gateway does not expose the necessary methods.

## Important assumptions

- The RPC method names are scaffolded around these defaults and may need to be aligned with your deployment:
  - `connect.hello`
  - `connect.refresh`
  - `sessions.list`
  - `chat.history`
  - `chat.send`
  - `health.snapshot`
  - `presence.list`
  - `approvals.list`
  - `usage.summary`
  - `push.register`
- The live client expects `JSON-RPC 2.0` style envelopes over WebSocket.
- `wss://` is required for remote access. `ws://` only works when `allowInsecureLocal` is enabled in Settings and the profile transport mode is switched to `Trusted Local WebSocket`.
- The app bundle identifier is currently `ai.openclaw.operator`. Update it alongside `project.yml` and the APNs credentials you configure on the server side.

## How to open it

1. Install full Xcode 16+ on a Mac.
2. Install XcodeGen if it is not already available.
3. From the repo root, run `xcodegen generate`.
4. Open `OpenClawOperator.xcodeproj`.
5. Set your signing team, bundle id, and APNs environment.
6. Run on an iPhone or simulator with iOS 17+.

## APNs + gateway checklist

- Create an APNs key for the bundle id you choose.
- Configure your OpenClaw gateway or relay with:
  - Team ID
  - Key ID
  - `.p8` key material
  - bundle id
- Ensure the gateway emits notification payloads with a `sessionId` field so the app can deep-link into the correct conversation.
- For Tailscale or private-network deployment, expose a reachable `wss://` endpoint to the phone.

## Notes on validation in this workspace

- This workspace does not have full Xcode installed, only Command Line Tools.
- `swift test` also fails here because the local toolchain/SDK setup is mismatched and cannot build Swift modules reliably from this environment.
- The source tree, project generation config, and iOS resources are implemented, but you should perform the first real compile and signing pass on a machine with full Xcode.
