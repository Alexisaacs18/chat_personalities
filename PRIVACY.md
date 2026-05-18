# ToneChat Privacy Policy

**Last updated:** May 17, 2026

ToneChat ("we", "the app") is a chat application with fictional character voices.

## What we collect

- **Anonymous device identifier** — a random UUID stored on your device in the Keychain. Used to issue a guest session and enforce rate limits. No Apple account required.
- **Apple Sign In identifier** (optional) — only if you choose to sign in. Used for a higher message limit on our servers.
- **Chat messages** — sent to our backend to generate AI replies. Messages are not sold to third parties.

## How we use data

- Issue guest or signed-in sessions and enforce rate limits.
- Generate in-character responses via Anthropic's API.
- Operate and improve the service.

## Storage

- Chat history is stored **on your device** (SwiftData) for all users, signed in or not.
- Guest users have no server-side account; only a hashed device identifier is associated with their session token.
- Signed-in users have a minimal account record on our server. We do not retain full chat logs on the server in the MVP.

## Third parties

- **Apple** — Sign in with Apple (optional).
- **Anthropic** — LLM inference for chat replies.

## Your choices

- **Use without signing in** — chat works in guest mode with lower rate limits; history stays on your device.
- **Sign in with Apple** (optional) — higher message limits; chats still stay on this device.
- **Delete account** — Settings → Delete account (signed-in users only) removes your server account record.
- **Sign out** — returns you to guest mode; local chats are kept.

## Contact

Open an issue in this repository or contact the app developer listed in App Store Connect.

## Children

ToneChat is not directed at children under 13.
