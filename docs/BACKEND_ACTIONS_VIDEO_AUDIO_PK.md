# Backend Actions Required — Video Live / Audio Room / PK

This doc lists the backend work needed to make the Flutter audio rooms, video live, and PK battle flows fully production-ready. The Flutter app-side fixes are already in progress/done.

---

## 1. LiveKit is intentionally NOT supported right now
- **Flutter status:** Agora-only. Do not return `service: 'livekit'`, `livekitUrl`, `livekitToken`, or `livekitRoom` in `LiveUser` / `AudioRoomUser` payloads.
- **Action:** If LiveKit is desired later, both the Flutter `livekit_client` integration and the backend contract must be added together. For now, always set `service: 'agora'` (or omit the field).

---

## 2. Audio PK is still "Coming Soon"
- **Flutter status:** Hard-disabled (`_audioPkEnabled = false`) in the audio room.
- **Action:** No backend work required until the feature is enabled.

---

## 3. `createAudioRoom` — `isPublic` type consistency
- **Issue:** The endpoint is called both as multipart (cover image upload) and as JSON (no cover). Multipart sends `isPublic` as a string `"true"`/`"false"`, while JSON sends it as a boolean.
- **Action:** The backend must accept both shapes, or the frontend should be told which one to use. Currently the JSON path is kept as a boolean; the multipart path is a string.

---

## 4. Host ending own video stream — wrong endpoint
- **Flutter call:** `ApiService.userHostLiveEnd` calls `POST /liveUser/liveStreamingCutByAdmin`.
- **Issue:** The endpoint name implies an admin action. The host is calling it for self-termination.
- **Action:** Provide a host-facing endpoint (e.g. `POST /liveUser/liveStreamingEnd` or `/api/v1/live/end-stream`) and update the Flutter `ApiService` to use it.

---

## 5. Moderation endpoints
- **Flutter calls:**
  - `POST /liveUser/banUser`
  - `POST /liveUser/muteViewer`
- **Issue:** Not listed in `API_ENDPOINTS.md`.
- **Action:** Confirm payload and response shape. Expected fields: `liveStreamingId`, `userId` (actor), `viewerId`/`targetUserId`, and `mute` (true/false).

---

## 6. Private audio room join endpoint
- **Flutter call:** `POST /audioRoom/join` with `{roomId, userId, passcode}`.
- **Issue:** Not documented in `API_ENDPOINTS.md`.
- **Action:** Implement or confirm the endpoint, and return the full `AudioRoomUser` in the response so the seat layout is refreshed.

---

## 7. Audio room admin endpoints
- **Flutter calls:**
  - `POST /audioRoom/makeAdmin` / `POST /api/v1/audio-room/make-admin`
  - `POST /audioRoom/setAdminPermissions`
- **Issue:** Used during room creation to restore cached admins, but the backend contract is unclear.
- **Action:** Confirm the endpoints, payload, and that they do not fail if the room is not yet fully persisted.

---

## 8. Audio room task system
- **Flutter status:** UI / counters are present but not wired to any backend task progress.
- **Action:** Implement the Audio Room Task System described in `AGENTS.md` so the Flutter app can call `/api/v1/tasks/active` and `/api/v1/tasks/claim` and receive `taskProgressUpdate` events.

---

## 9. Audio room seat counter
- **Flutter status:** Local counter only; no persistence or reward.
- **Action:** Implement the backend seat counter module and the socket events `seatCounterToggle`, `seatCounterUpdate`, `seatCounterError`.

---

## 10. PK battle token / relay contract
- **Flutter status:** The app now sends `host1Token`, `host2Token`, `host1SrcToken`, `host2SrcToken`, `host1RelayDestToken`, `host2RelayDestToken` in the `pkAnswer` payload.
- **Required backend fields in `pkConfig`:**
  - `host1Channel` / `host2Channel`
  - `host1AgoraUID` / `host2AgoraUID`
  - `host1Token` — token for Host1's UID in Host1's channel.
  - `host2Token` — token for Host2's UID in Host2's channel.
  - `host1SrcToken` / `host2SrcToken` — tokens for media relay source (or fallback to `host1Token`/`host2Token`).
  - `host1RelayDestToken` — token for Host1's UID in Host2's channel (the opponent channel).
  - `host2RelayDestToken` — token for Host2's UID in Host1's channel.
- **Action:** Generate and forward all of these in `pkAnswer`/`pkStart`. If the relay-dest tokens are missing, the app falls back to generating tokens locally when it has the Agora certificate, which may not work in production.

---

## 11. PK accept flow — backend must create and broadcast the session
- **Flutter status:** When the invited host clicks Accept, the app emits `pkAnswer` (`isAccept: true`). It also calls `POST /pkCall/create` as a fallback.
- **Required backend behavior on `pkAnswer` / `POST /pkCall/create`:**
  1. Create a `PkSession` record.
  2. Generate the 6 tokens from point 10.
  3. Store the session in both `LiveUser` records (`pkConfig` / `pkCall`).
  4. Return/broadcast a `pkConfig` map containing all token/relay fields, `host1Id`, `host2Id`, `host1LiveId`, `host2LiveId`, `host1Channel`, `host2Channel`, `host1AgoraUID`, `host2AgoraUID`, `durationSeconds`, and `pkRoundCount`.
  5. Emit `pkAnswer` (or `pkStart`) to **both** host sockets/rooms (requester + accepter) with the same `pkConfig`.
- **Why this matters:** If the backend only broadcasts to the requester, the accepting host never receives the session data and the PK UI does not open. The `pkAccept` issue is caused by a missing/broken step here.

---

## 12. PK request routing
- **Flutter status:** The app emits `pkRequest` with `host2Id` (target user id), `host2LiveId`/`targetRoomId` (target room id), and `host1LiveId` (requester room id).
- **Required backend behavior:** The server must forward `pkRequest` to the **target host's room/socket**, not only to the requester's room. If the server broadcasts by `liveStreamingId`, it should use the target room id (from `host2LiveId`/`targetRoomId`), or route by the target `userId`/`host2Id` directly.
- **Symptom if missing:** Requester sees "PK invite sent", the target host never receives the dialog, and the acceptor cannot tap Accept.

---

## 12. PK punishment-round socket semantics
- **Issue:** Both battle-end and punishment-complete use `eventPkPunishmentRound` with overlapping flags (`isPKPunishment`, `showStartButton`).
- **Action:** Either keep the single event and document the exact combination of flags, or split into:
  - `pkPunishmentStart`
  - `pkPunishmentComplete`
  - `pkBattleEnd` (which should be `pkEnd`)

---

## 12. PK score updates
- **Issue:** The app applies optimistic score updates locally and also broadcasts `pkScoreUpdate`. Two hosts doing this at the same time can cause score drift.
- **Action:** The backend should be the single source of truth for PK scores. When a gift is received, the backend should calculate and emit `pkScoreUpdate` to all clients.

---

## 13. Host presence guard (compliance)
- **Flutter status:** Now enabled in `live_room`.
- **Required backend support:**
  - Store and query active face-detection bans.
  - Accept the compliance termination call (`ApiService.endStreamForCompliance`) and gracefully end the stream.
  - Return the ban window so the Flutter `HostPresenceGuardService` can show a dialog before allowing the next stream.

---

## 14. Camera on/off event
- **Flutter change:** The app now adds `isHost: true/false` to the `cameraOffCallJoin` socket event.
- **Action:** Broadcast this event to all viewers so they can update the host or co-host video tile. The `userId` and `isHost` fields must be preserved.

---

## 15. Level field in socket payloads
- **Flutter change:** The app now sends `level` as a JSON object (`{name, ...}`) and also `levelName` as a plain string fallback.
- **Action:** Accept either `level` (object) or `levelName` (string) when building join/viewer comments.

---

## 16. Backend message guide
- **Issue:** `docs/BACKEND_MESSAGE_VIDEO_LIVE.md` was missing from the backend repo. The workspace copy exists at `/home/UniLive/BACKEND_MESSAGE_VIDEO_LIVE.md`.
- **Action:** The document is now placed at `Unilive-backend/docs/BACKEND_MESSAGE_VIDEO_LIVE.md` and updated to reflect the Agora-only, LiveKit-skipped release.

---

## 17. Room participant endpoint duplication
- **Issue:** The Flutter app has two model classes (`RoomParticipantRoot` and `GuestLiveModel`) calling the same `GET /liveUser/retrieveRoomParticipantDetails?toUserId=`.
- **Action:** Confirm the exact JSON response shape and the field used for the target user's Mongo ID (`_id`/`id`/`userId`).

---

## Notes
- Audio PK: no backend work for now.
- LiveKit: do not enable from backend until the Flutter side is also built.
- The above actions are in priority order; items 1-5, 10, and 11 are the most critical for the next release.
