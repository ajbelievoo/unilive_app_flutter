# Backend Message — Video Live `view` Roster Returns Empty (Viewer Count Shows 0)

## Problem

In **video live rooms** the viewer count (eye icon, top-right) and the online
viewer avatar strip are wrong on every device:

- A viewer joins → count briefly shows the right number (2-3 seconds), then
  drops to **0** on all devices — host and viewers — while the audience is
  still sitting inside.
- After that every device shows 0 until someone new joins (then it flickers
  to 1 and back to 0 again).
- The same `view` event works correctly in **audio rooms**.

The client requests the online list every 5s and rebuilds from the reply.
The symptoms mean the `view` reply for video rooms arrives with an **empty /
missing roster** — so each 5s reply wipes the locally correct list.

## What the app sends (client)

`emit('view', payload)` — sent on room join, on app-resume, when the viewers
sheet opens, and on a 5s refresh timer:

```json
{
  "liveStreamingId": "<liveUser doc _id>",
  "roomId": "<liveUser doc _id>",
  "liveRoom": "<liveUser doc _id>",
  "liveUserMongoId": "<liveUser doc _id>",
  "liveUserId": "<host userId>",
  "userId": "<requesting user's userId>",
  "requestFullList": true
}
```

Viewers also emit `addView` on join (full profile: `userId`, `name`, `image`,
`isVIP`, `Invisible: false`, `liveType: 'video'`, `vipDetails`, etc.) and a
`comment` with `isJoined: true`. On exit they emit `lessView` (+ a `comment`
with `isLeft: true`).

## What the app expects back

`emit('view', rosterArray, extraMap?)` — arg0 = array of **all current room
members** (host included is fine, the client filters the host out). Each entry
like the audio room already sends:

```json
{
  "userId": "…",
  "name": "…",
  "image": "…",
  "isAdd": true,
  "Invisible": false,
  "isVIP": false,
  "vipDetails": { … },
  "avatarFrameImage": "…",
  "level": { "name": "3" }
}
```

`extraMap` (optional) is the joiner's entry-effect map
(`entrySvga`, `vehicleImage`, …) or a leave marker `{userId, isLeave: true}`.

## Backend TODO

1. **Room lookup must accept video-live ids.** The `view` handler should
   resolve the roster by `liveStreamingId` OR `roomId` OR `liveRoom`
   (all carry the same liveUser doc `_id`). If the roster is keyed under a
   different field for video rooms, accept it — currently the reply for video
   rooms looks empty while audio rooms return the full list.
2. **Register video-live viewers in the roster.** When a socket emits
   `addView` (or the join `comment`) for a video room, add that user to the
   room's viewer roster; remove on `lessView` / `isLeft` comment / socket
   disconnect. The roster must reflect video rooms exactly like audio rooms.
3. **Reply shape.** Broadcast/reply `view` with arg0 = the roster array.
   Per-requester replies are fine (client keeps its own self-entry). Do not
   mark existing members `isAdd: false` in the roster — presence in the array
   already means "in the room" (`isAdd` is only meaningful for single-user
   delta emits).
4. **`view` count on `liveRejoin`** — if that event carries `view`, keep it
   as total-joins-including-host (client subtracts the host).
5. **`lessView` on disconnect.** When a viewer's socket drops, remove them
   from the roster and broadcast `lessView` (or a `view` roster without them)
   so all devices stay in sync.

## Follow-up observed after deploy (still needs backend cleanup)

The roster now returns correctly — good. But the payload shows the **host is
registered inside the viewer roster**:

```
view event raw: [[
  {userId: 69f7b1f1..., name: RJAAAAA, isHost: false, isAdd: true, ...},   ← host
  {userId: 6a89457d..., name: hellop,  isHost: false, isAdd: true, ...}    ← viewer
], {liveStreamingId: 6ab96b4b..., liveUserId: 6a3ac260..., userId: 6a89457d...}]
```

Two problems visible here:

1. **Host appears as a viewer** (`isHost: false`, `isAdd: true`). The host's
   `view` poll / `liveRoomConnect` seems to register them into the roster.
   The roster should either exclude the room owner or mark them
   `isHost: true` — otherwise every client over-counts by one and shows the
   host's avatar inside the viewer strip.
2. **Inconsistent id conventions.** The roster entry uses the host's User
   `_id` (`69f7b1f1...`) while the room's `liveUserId` is `6a3ac260...` — a
   different field. Clients that filter the host by `liveUserId` can't match
   it. Please store the SAME id in the roster `userId` slot as
   `liveUserId` (or send the roster `userId` as the User `_id` everywhere and
   include `liveUserId` inside each entry so both conventions are available).

The client now tolerates this by maintaining a host-id set (liveUserId +
liveUser doc `_id` + fetched User `_id`), but fixing it server-side is the
clean solution.

## Notes

- Client-side is already resilient: non-empty rosters rebuild the list
  authoritatively; empty replies no longer wipe it. But the count can only be
  *correct and consistent across devices* if the roster actually contains the
  room's viewers — that part must be fixed server-side.
- Debugging: the client logs every incoming payload as
  `[LiveRoom] view event raw: <payload>` — reproduce once and check logcat to
  see exactly what the backend returned (empty array vs. wrong shape vs.
  filtered entries).
- Audio rooms work correctly today — the video-live path is the only one
  returning an unusable roster.
