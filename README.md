# ToneChat

iOS chat app with layered character voices and a backend proxy for Anthropic.

## Structure

- `ToneChat/` — SwiftUI iOS app (iOS 17+)
- `ToneChatBackend/` — Node.js API (guest + Apple auth, streaming chat)

## Auth and rate limits

| Mode | Sign-in | Rate limit (default) | Chat storage |
|------|---------|----------------------|--------------|
| Guest | Not required | 10 messages/min (`GUEST_RATE_LIMIT_PER_MINUTE`) | On-device only |
| Apple | Optional in Settings | 30 messages/min (`RATE_LIMIT_PER_MINUTE`) | On-device only |

On first launch the app obtains a **guest session** using an anonymous device UUID. Sign in with Apple is optional and only increases server rate limits.

Guest limits are a cost control measure; reinstalling the app resets the device identifier.

## Quick start

### Backend

```bash
cd ToneChatBackend
cp .env.example .env
# Set ANTHROPIC_API_KEY and JWT_SECRET
npm install
npm run dev
```

Health check: `curl http://127.0.0.1:8787/v1/health`

Guest auth:

```bash
curl -s -X POST http://127.0.0.1:8787/v1/auth/guest \
  -H 'Content-Type: application/json' \
  -d '{"deviceId":"550e8400-e29b-41d4-a716-446655440000"}'
```

### iOS

1. Open `ToneChat.xcodeproj` in Xcode.
2. Set your **Team** and update bundle ID if needed (`com.tonechat.app`).
3. Enable **Sign in with Apple** for the App ID in Developer Portal (optional sign-in still requires capability).
4. Scheme environment (Simulator): `TONECHAT_API_BASE` = `http://127.0.0.1:8787` (default in Info.plist).
5. Build & run — no sign-in required to chat.

For a physical device, point `TONECHAT_API_BASE` in Info.plist to your deployed backend HTTPS URL.

## TestFlight

1. Apple Developer Program membership.
2. Register bundle ID `com.tonechat.app` with Sign in with Apple.
3. Deploy backend with HTTPS; set `ALLOW_DEV_AUTH=false` in production.
4. Update `TONECHAT_API_BASE` in Info.plist to production URL.
5. Archive → Distribute App → TestFlight.

## Presets

Bundled JSON in `ToneChat/Presets/`:

- Festival Wook
- Recovery Mentor (NE DC)
- Angry Old Australian

Customize per-chat with intensity sliders or build custom voices in-app.
