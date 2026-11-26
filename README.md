# Open Chat — Text & Voice

A lightweight, mobile-friendly real-time chat with a public lounge, invite-only private rooms, client-side encryption for private messages, and browser-based voice calls.

## Hosting on GitHub Pages

This repository includes a GitHub Actions workflow that publishes the site whenever code is pushed to the main branch. In the repository, open **Settings → Pages** and choose **GitHub Actions** as the build and deployment source if Pages has not been enabled yet. The site URL will appear there after the first successful deployment.

The repository is already public. Users do not need GitHub sign-in to use the chat.

## One-time backend setup (required)

GitHub Pages only hosts static files. It does not provide a realtime database or WebRTC signalling server, so this app uses your own Supabase project for anonymous sessions, message storage and realtime signalling.

1. Create a project at https://supabase.com/.
2. In Project Settings → API, copy the Project URL and the public anon / publishable key. Never put a service_role key in this website.
3. Open SQL Editor, paste all of supabase/schema.sql, and run it.
4. Open Authentication → Sign In / Providers and enable Anonymous Sign-Ins.
5. If API origin restrictions are enabled, allow your GitHub Pages origin, for example https://mohamed20034.github.io.
6. Open the deployed site, paste the Project URL and public anon key into the first-run screen, and connect. They are saved only in that browser's local storage.

The Supabase anon key is intended for browser use. Database access is restricted by Row Level Security in the supplied SQL. Do not use a service-role key.

## Features

- Public live text lounge with the latest 100 messages loaded on entry.
- Invite-only private rooms. An invite contains a high-entropy room ID and a separate encryption key in the URL fragment. Private message text is encrypted in the browser with AES-GCM before storage; the key is not sent to Supabase.
- Voice rooms use browser microphone access and peer-to-peer WebRTC audio. There is no account registration; Supabase anonymous auth creates an anonymous session.
- Responsive desktop and mobile layout. User messages are rendered as text, not HTML.

## Privacy and network notes

A private-room invite is a bearer secret: anyone with the complete invite link can join and decrypt that room. Do not post private invite links publicly. Supabase stores private message ciphertext, but room IDs, sender names, timestamps and message sizes remain visible to the project owner. The supplied SQL permits authenticated anonymous users to read message rows; private message bodies are encrypted client-side.

Voice calls use public STUN servers for connection discovery. Some corporate, school, mobile or restrictive networks block peer-to-peer UDP/WebRTC. For more reliable calls across such networks, configure a reputable TURN relay and add its credentials to the iceServers array in app.js. This project does not bypass network blocks or managed-device restrictions, and no browser-only app can guarantee connectivity on every network.

For voice calls, use a browser that supports WebRTC and grant microphone permission. HTTPS is required; GitHub Pages provides it. A microphone and speakers or headphones are required. Multiple participants form a peer-to-peer mesh, so very large voice rooms are not recommended.

## Local testing

Serve the repository root over HTTP (not file://) using a static server, for example python -m http.server 8000, then open http://localhost:8000. Use a real Supabase project to test cross-device messages and calls. Microphone access is available on localhost and HTTPS.

## Limitations

- Chat history is stored in Supabase, not GitHub. The latest 100 messages are shown when joining a room.
- Private-room access is link-based, not a user-account membership system. Anyone with the full invite can join.
- Voice quality and availability depend on browser support, microphone permissions, NAT and firewall rules, and STUN/TURN reachability.
- Supabase plan quotas and policies may change; check the current dashboard for limits.
