# Family Feature — Backend Implementation Message

> This is the list of backend endpoints and contracts the Flutter Family feature needs to be 100% functional. The Flutter code has already been fixed to call these endpoints correctly.

---

## 1. Endpoints already documented in `API_ENDPOINTS.md` (must be implemented)

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/family/create` | Create family (already used by Flutter, accept `logo` + `coverImage` multipart) |
| GET | `/family/:familyId` | Return family detail as `{status, data: family}` or direct family object |
| DELETE | `/family/:familyId` | Delete family |
| POST | `/family/join` | Join public family (or apply, if `requireApproval`) |
| POST | `/family/leave` | Leave family |
| GET | `/family/list` | Family list; support `userId`, `keyword`, `start`, `limit` |
| GET | `/family/members` | Return members wrapped in `{status, data: {members: [...]}}` or `{status, data: [familyWithMembers]}` |
| GET | `/family/rewards` | Family tasks/rewards |
| POST | `/family/transferLeadership` | Transfer leadership |
| GET | `/family/userFamily` | **CRITICAL**: Return the current user's family directly; Flutter now calls this first |

### Required response shapes

- `GET /family/:familyId` and `GET /family/userFamily` must return either:
  - `{ "status": true, "data": { ...family object } }`, or
  - directly the family object (Flutter tolerates both).
- `GET /family/list` entries should include `members` array OR at least `leaderId` so Flutter can detect the user's family.
- `GET /family/members` should return a clear shape. Flutter supports:
  - `{ "status": true, "data": { "members": [ ... ] } }`
  - `{ "status": true, "data": [ { ...member object... } ] }` (if each item has `userId`)

---

## 2. Endpoints the Flutter app already calls (need implementation)

These are used in the UI and currently fail if the backend does not support them.

| Method | Path | Used in |
|--------|------|---------|
| POST | `/family/treasury/donate` | Family treasury donation |
| POST | `/family/treasury/purchase-perk` | Perk purchase from treasury |
| POST | `/family/claimTask` | Claim family task reward |
| POST | `/family/dailySignIn` | Daily family sign-in |
| GET | `/family/:familyId/join-requests` | Join request queue |
| POST | `/family/join-request/:requestId/approve` | Approve request |
| POST | `/family/join-request/:requestId/reject` | Reject request |
| POST | `/family/banMember` | Ban a member |
| POST | `/family/unbanMember` | Unban a member |
| GET | `/family/:familyId/banned` | Banned user list |
| POST | `/family/kickMember` | Kick member |
| POST | `/family/updateMemberRole` | Promote/demote co-leader |
| POST | `/family/invite` | Invite user to family |
| GET | `/family/ranking` | Weekly family ranking |
| GET | `/family/:familyId/contribution` | Contribution leaderboard |
| GET | `/family/week-config` | Weekly ranking countdown config |
| POST | `/family/pk-challenge` | Start family vs family PK |
| GET | `/family/:familyId/battles` | Family PK history |
| GET | `/family/:familyId/achievements` | Family achievements |
| GET | `/family/:familyId/level-info` | Level/capacity/exp data (replaces hardcoded formulas) |
| GET | `/family/:familyId/level-rewards` | Level reward list |
| POST | `/family/:familyId/level-rewards/:rewardId/claim` | Claim level reward |
| GET | `/family/:familyId/transactions` | Treasury transaction history |
| GET | `/family/:familyId/announcements` | Family announcements |
| POST | `/family/:familyId/announcements` | Create announcement |
| GET | `/family/:familyId/events` | Family events |
| POST | `/family/:familyId/broadcast` | Broadcast message to all members |
| GET | `/family/suggested` | Suggested families |

---

## 3. Family Chat / Red Packets

Family chat uses socket event `familyChat` and group-chat history. Two options for backend:

### Option A (recommended): family chat uses existing group-chat endpoint
- `GET /chatGroup/getOldChat?groupId=family_<familyId>&start=&limit=`
- Messages are sent/received via socket `familyChat` with `familyId` field.
- Image upload: `POST /chat/uploadImage` with `topic=family_<familyId>` and `messageType=image`.

### Option B: dedicated family chat
- `GET /family/:familyId/chat/history?start=&limit=`
- `POST /family/:familyId/chat/image` for image upload.

### Red packets (lucky bags)
Flutter now creates/claims via:

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/family/:familyId/lucky-bag` | Create a red packet (returns `_id` / `id` in `data`) |
| POST | `/family/:familyId/lucky-bag/:luckyBagId/claim` | Claim red packet (return `coin` amount) |

---

## 4. Critical backend fixes needed

1. **`/family/create` cost check**: Flutter shows 6,000,000 diamonds cost but the backend must deduct `coin` and enforce creation rules (SVIP4 free, 7-day auto-disband, name/cover change limit).

2. **Family creation fields**: Backend must accept and store `minLevelToJoin`, `requireApproval`, `isPublic`, `welcomeMessage`, `slogan`, `announcement`, `coverImage`.

3. **`/family/userFamily`**: Must exist and return the user's family. Flutter no longer relies on client-side filtering.

4. **`/family/join`**: Must support both instant join (public, no approval) and application (private / `requireApproval`). Return clear `status`/`message`.

5. **`/family/list`**: Must support `keyword` for search and `userId` to flag `isMember`.

6. **`/family/members`**: Must include `role`, `contribution`, `userId`, `name`, `image` for each member.

7. **`/family/:familyId`**: Must return full family data including `members`, `treasury`, `level`, `rank`, `maxMembers`, `isPublic`, `minLevelToJoin`, `requireApproval`, `welcomeMessage`, `slogan`, `announcement`, `hasSignedInToday`, `dailySignInReward`.

---

## 5. Recommended test checklist for backend

- [ ] Create family with cover/logo, cost deducted.
- [ ] Join public family instantly; join private family with code.
- [ ] Apply to family with approval required; leader/co-leader approves/rejects.
- [ ] Member promote/demote/kick/ban/unban.
- [ ] Treasury donation and perk purchase.
- [ ] Daily sign-in and task claim.
- [ ] Family chat send/receive text, image, red packet.
- [ ] Family ranking and contribution leaderboard.
- [ ] Family PK challenge and battle history.
- [ ] Announcements, events, broadcast.
- [ ] Level info, achievements, level rewards.

Once these endpoints are implemented, the Flutter Family feature is fully wired and ready.
