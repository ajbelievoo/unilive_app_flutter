# Call Flow Backend Fixes — Flutter Integration Guide

> **Date:** 2026-08-22  
> **Project:** UniLive Backend (`Unilive-backend/`)  
> **Status:** All 8 spec points implemented  

---

## TL;DR for Flutter team

Aapke call-flow ke saare backend issues ab fix ho chuke hain:

1. `POST /history/call` balance, block, DND check ke saath `callId`, `token`, `callRate`, `freeTrialSeconds` return karta hai.
2. `callRequest` socket event receiver (`userId1`) tak direct jaata hai; background mein FCM aata hai with `token` + `channel`.
3. `callAnswer`, `callCancel`, `callDisconnect` ab correct doosre user ko relay hote hain.
4. Har 10-sec deduction ke baad caller ko `walletUpdate` event push hota hai.
5. 45 sec timeout ke baad auto `missed_call` FCM jaata hai.
6. Call history ab `pending/connected/completed/missed/rejected` sahi status mein aata hai.

---

## Files changed

| File | What changed |
|------|--------------|
| `Unilive-backend/server/wallet/wallet.controller.js` | `exports.call` and `exports.callHistory` updated |
| `Unilive-backend/socket.js` | `callRequest`, `callAnswer`, `callCancel`, `callDisconnect`, `callReceive` handlers updated |
| `Unilive-backend/util/callRate.js` | New call helpers: rate, FCM builder, missed-call timer |
| `Unilive-backend/server/user/user.model.js` | Added `isDnd` field |
| `Unilive-backend/server/setting/setting.model.js` | Added `freeTrialSeconds`, `freeTrialEnabled`, `minBalanceMinutes` |
| `Unilive-backend/server/wallet/wallet.model.js` | Added `callStatus` enum |

---

## 1. REST API — `POST /history/call`

**Endpoint:** `POST /history/call`

### Request (same as before)

```json
{
  "callerUserId": "caller_mongo_id",
  "receiverUserId": "receiver_mongo_id",
  "channel": "receiver_mongo_id",
  "callType": "Male" | "Female"
}
```

### Response

```json
{
  "status": true,
  "message": "Call initiated",
  "callId": "call_room_id",
  "token": "agora_token",
  "callRate": 50,
  "freeTrialSeconds": 15
}
```

### New checks before creating call

| Check | Fail message |
|-------|--------------|
| Caller balance ≥ `callRate × minBalanceMinutes` | `Insufficient balance` |
| Caller/receiver blocked each other | `Blocked` |
| Receiver `isDnd === true` or `isBusy === true` | `User is on Do Not Disturb` |

`callRate` host-level effective rate le raha hai agar receiver host hai, else `maleCallCharge` / `femaleCallCharge` setting.

`freeTrialSeconds` setting se aa raha hai (`freeTrialSeconds` default `15`).

---

## 2. Socket — `callRequest`

**Flutter emit kare:**

```json
{
  "userId1": "receiver_id",
  "userId2": "caller_id",
  "user2Name": "Caller Name",
  "user2Image": "https://...",
  "user2ImageFrameImage": "https://...",
  "callRoomId": "xxx",
  "token": "agora_token",
  "channel": "receiver_id",
  "isAudioCall": false,
  "callRate": 50,
  "freeTrialSeconds": 15
}
```

**Backend kya karega:**

- Sirf `globalRoom:<userId1>` (receiver) ko forward karega.
- Agar receiver socket pe nahi hai, toh **incoming call FCM** bhejega with complete payload including `token`, `channel`, `callRate`, `freeTrialSeconds`.
- Agar 45 sec tak call accept nahi hoti, auto `missed_call` FCM receiver ko jaayega.

---

## 3. Socket — `callAnswer`

**Flutter emit kare (receiver side):**

```json
{
  "userId1": "receiver_id",
  "userId2": "caller_id",
  "token": "agora_token",
  "callRoomId": "xxx",
  "channel": "receiver_id",
  "isAccept": true | false
}
```

**Backend kya karega:**

- `isAccept: true` → dono users `callRoomId` room mein join; missed-call timer clear; `callStatus` = `connected`.
- `isAccept: false` → `callStatus` = `rejected`; missed-call timer clear.
- Answer ko **doosre user** ko relay karega (sender ko nahi).

---

## 4. Socket — `callCancel` / `callDisconnect`

### `callCancel`

```json
{
  "userId1": "xxx",
  "userId2": "xxx",
  "callRoomId": "xxx"
}
```

- Doosre user ko relay karega.
- Wallet `callStatus` update: receiver ne cancel kiya → `rejected`; caller ne cancel kiya → `missed`.
- Missed-call timer clear.

### `callDisconnect`

```json
{
  "userId1": "xxx",
  "userId2": "xxx",
  "callRoomId": "xxx"
}
```

- Object payload accept karega (pehle se string bhi chalega backward compat ke liye).
- Doosre user ko relay karega with `reason: "disconnected"`.
- Wallet `callStatus` update: `connected` → `completed`; `pending` → `missed`.
- Missed-call timer clear.

---

## 5. FCM payloads

### Incoming call (receiver offline/background)

```json
{
  "notification": {
    "title": "Incoming Video Call",
    "body": "Caller Name"
  },
  "data": {
    "type": "call",
    "userId1": "receiver_id",
    "userId2": "caller_id",
    "user2Name": "Caller Name",
    "user2Image": "https://...",
    "callRoomId": "xxx",
    "token": "agora_token",
    "channel": "receiver_id",
    "isAudioCall": "false",
    "callRate": "50",
    "freeTrialSeconds": "15",
    "data": "{...json string...}"
  }
}
```

### Missed call

```json
{
  "notification": {
    "title": "Missed Call",
    "body": "Caller Name called you"
  },
  "data": {
    "type": "missed_call",
    "callerId": "xxx",
    "callerName": "Caller Name",
    "callerImage": "https://...",
    "callRoomId": "xxx"
  }
}
```

---

## 6. REST API — `GET /history/callHistory`

**Endpoint:** `GET /history/callHistory?userId=xxx&start=0&limit=30`

**Response:**

```json
{
  "status": true,
  "message": "Success",
  "total": 1,
  "history": [
    {
      "_id": "record_id",
      "callerUserId": "xxx",
      "receiverUserId": "xxx",
      "callType": "audio" | "video",
      "isAudio": true | false,
      "duration": 120,
      "coin": 100,
      "status": "completed" | "missed" | "rejected",
      "date": "2026-08-23T...",
      "name": "Other User Name",
      "image": "https://..."
    }
  ]
}
```

`status` ab `pending`, `connected`, `completed`, `missed`, `rejected` mein se koi ho sakta hai.

---

## 7. Socket — `walletUpdate`

Har `callReceive` deduction ke baad caller ke `globalRoom:<callerId>` pe emit hota hai:

```json
{
  "event": "walletUpdate",
  "data": {
    "coin": 400,
    "diamond": 400
  }
}
```

Agar balance kam ho jaaye toh `callDisconnect` emit hota hai with `reason: "insufficient_balance"`.

---

## 8. Important notes for Flutter

- **`userId1 = receiver`, `user2 = caller`** in all call socket events.
- Flutter ko `POST /history/call` success ke baad **turant** `callRequest` socket event emit karna hai.
- `callRequest` payload mein `token`, `channel`, `callRate`, `freeTrialSeconds` include karein jo API se mile hain.
- Caller ko har 10 second mein `callReceive` emit karte rehna hai jab tak call chale. Backend har pulse pe coins deduct karega aur `walletUpdate` push karega.
- `callDisconnect` object payload bhejein: `{ userId1, userId2, callRoomId }`.

---

## Verification checklist

- [x] `POST /history/call` returns `callId + token + callRate + freeTrialSeconds`
- [x] `POST /history/call` checks balance, block, DND
- [x] `callRequest` socket forwarded to `userId1` only
- [x] `callRequest` offline FCM with `token` and `channel`
- [x] `callAnswer` relayed to other user
- [x] `callCancel` / `callDisconnect` relayed to other user
- [x] `walletUpdate` pushed to caller on deduction
- [x] Missed call FCM after 45s timeout
- [x] `GET /history/callHistory` returns records with correct status

---

*Generated by Devin for UniLive backend call-flow parity.*
