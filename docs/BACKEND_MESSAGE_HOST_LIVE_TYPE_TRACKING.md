# Backend Message — Live Time/Earning Must Be Bucketed by liveType

## Problem

When a host runs a **video live**, the same minutes get recorded under **both**
`audio` and `video` buckets in `hostLiveHistory` (and vice-versa). Symptoms seen
in the app (Host Center):

- A 17m video live shows up as "Video Live 17m" **and** "Audio Live 17m/34m".
- "Audio Today" card increments while the host is only on video live.
- "Audio Live Task" shows full progress (77/70 min, 168K/100K earning) even
  though no audio room was hosted.
- Claiming it fails: `PATCH /task/claimTaskReward` →
  `"You don't have enough coins earning to claim this task"` — because the
  backend's own audio bucket is actually empty (all gifts came in video live).

Root cause: live-time updates previously carried no `liveType`, so the backend
could not attribute the session and wrote/double-counted both buckets.

## What the app now sends (client already updated)

`liveType` (`"audio"` | `"video"`) is now included in every place live time is
reported:

| Channel | Fields |
|---|---|
| `POST /liveUser/updateLiveTime` | query: `userId, liveStreamingId, time, liveType` · body: `liveType, roomType, time, duration, watchSeconds, elapsedSeconds` |
| `PATCH /liveUser/live` (fallback) | form: `liveType, roomType, time, duration, watchSeconds, elapsedSeconds` |
| Socket `roomTime` + `liveTimeSync` | `liveType, roomType, liveStreamingId, liveUserId, userId, watchSeconds, elapsedSeconds, seconds, duration, time, micOn, isHost` |
| Stream-end sockets (`liveHostEnd`, `hostLiveEnd`, `liveEndByEnd`, `endLive`, `audioLiveHostRemove`) | `liveType, roomType, time, duration, elapsedSeconds` |
| `PATCH /task/claimTaskReward?hostId=&taskId=` | `liveType, taskType, type` (the task's type), `audioDuration`, `videoDuration`, `rCoin`/`coin` = **type-scoped** earning, `totalEarning`/`totalRcoin`/`totalCoin` = combined day earning, `liveStreamingId` = a session of the matching type when available |

## Backend TODO

1. **Attribute by liveType.** When processing `updateLiveTime` / `roomTime` /
   `liveTimeSync` / end-of-stream events, resolve the session type from the
   `liveType` field. Fallback: look up the `liveUser`/room doc by
   `liveStreamingId` and use its stored type. Increment **only** that type's
   duration (and earning) in `hostLiveHistory`. Never write to both buckets.
2. **`hostLiveHistory` rows.** Create/update only the row whose `type` matches
   the session. Do not create an `audio` row for a video session.
3. **`GET /hostLiveHistory/hostLiveHistoryToday`** — keep `audioDuration` /
   `videoDuration` accurate per type, and (recommended) also return per-type
   earnings as `audioEarning` / `videoEarning` (rCoin/beans earned in that live
   type today).
4. **`GET /hostLiveHistory/hostLive?liveType=`** — actually filter by type:
   `todayMinutes`/`duration`/earnings in the response must be the requested
   type's values, not the combined day total.
5. **`GET /task/getTask`** — legacy tasks with `type: "audio" | "video"` +
   `timeRequired`/`coinRequired` should compute `progress`/`completed` from the
   matching type's daily values.
6. **`PATCH /task/claimTaskReward`** — validate `timeRequired`/`coinRequired`
   against the matching type bucket (`liveType` from the body, else `task.type`).
   The existing failure message is correct behaviour — the client was just
   displaying wrong (combined) progress before.
7. **Reward currency = Beans (rCoin), not Diamonds (coin).** Host task rewards
   are earnings — credit `user.rCoin` and write the Wallet entry in rCoin, both
   for legacy `task` claims and `claimDashboardTask`. The client now sends
   `rewardCurrency: "rCoin"` in the claim body and renders the reward with the
   Beans icon.
   - Also: `taskRewardHistory` entries should expose the credited amount under
     a stable field (`rewardCoins` or `coinsRewarded`) — older docs returned it
     under names the app didn't read, so history tiles showed **0**.
8. **Data cleanup (recommended)** — for hosts whose history was double-written,
   recompute per-type durations/earnings from `LiveStreamingHistory` session
   rows (each session already knows its own type) and fix today's
   `hostLiveHistory` docs so pending task claims can succeed.

## Notes

- Old app builds don't send `liveType` — use the `liveStreamingId` → room-type
  lookup fallback for them.
- Client-side is fully updated and backward compatible (extra fields are
  ignored by older backends).
