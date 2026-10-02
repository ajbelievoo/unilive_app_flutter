# Belive - Flutter Live Streaming App

## Effect Settings & Audio Room Settings (added 2026-10-02)
- `EffectSettingsService` (`lib/services/effect_settings_service.dart`) — 9
  toggles persisted per-key in SharedPreferences; `getSettings()` refreshes the
  cached `settings`. Consumers: `live_broadcast_overlay` (all broadcast types),
  `vip_entry_overlay` (skips vehicle phase when Vehicle Effect off),
  `in_app_notification_banner` (lucky-bag marquee), both room screens
  (join/leave comments, gift/vehicle/game/PK/fighter/lucky-bag banners).
- Audio room settings: `roomChatPermission` (chatMode anyone|admins) and
  `micPermission` (micMode anyone|invite) socket events — persisted on the
  LiveUser doc; `chatMode==admins` blocks non-admin `_sendComment`, `micMode==
  invite` forces raise-hand even in wheat mode. Admins tile →
  `GET /audioRoom/admin-list`, Blocked List → `GET /audioRoom/bannedUsers`
  (room-scoped), Kick History → `GET /audioRoom/kickHistory`.
- PK voting: `pkVote` socket = free once-per-user vote; `POST
  /audioRoom/pkVote` = paid diamond vote ({pkId, liveStreamingId,
  voterUserId, hostChoice, coin}) — server debits + broadcasts pkScoreUpdate.

## Project Overview
Belive is a Flutter port of the native Android "UnilivePro" live streaming app.
It provides live streaming, audio rooms, PK battles, reels, chat, gifting, wallet,
VIP, agency, family, and CP (Couple) features.

## Currency Naming (UI Rename — Backend Keys Unchanged)
The in-app currencies have been renamed in the UI. **Backend JSON keys are unchanged.**
- **Diamonds** (UI) = `coin` (backend) — purchasable currency for gifting, games, store, recharge. Icon: `assets/icon/icon_dimoand.png`
- **Beans** (UI) = `rCoin` (backend) — host earning currency, converts & withdraws. Icon: `assets/icon/ubean_bling.webp`
- **Legacy `diamond` field** — backend now syncs `diamond = coin` (Option A merge). Flutter reads `user.coin` everywhere for the "Diamonds" balance; `diamond` field kept in sync for old app compatibility. See `docs/CURRENCY_RENAME_BACKEND_API.md`.
- **Constants**: `Const.coinName` ('Diamonds'), `Const.rCoinName` ('Beans'), `Const.diamondIconAsset`, `Const.beanIconAsset` in `lib/constants/const.dart`
- **Widget**: `CurrencyIcon(CurrencyType.diamond|bean)` in `lib/widgets/currency_icon.dart` — use next to balances/prices
- **Backend spec**: `docs/CURRENCY_RENAME_BACKEND_API.md` — full API contract + the `coin`/`diamond` field inconsistency the backend team must resolve

## CP (Couple) & Friend Feature
- **CP Models**: `lib/models/cp_models.dart` — CPItem, CPRequest, CPTask, CPRankItem, CPLevel, CPMilestone, CPHistoryItem, CPPrivilege, CPRing
- **Friend Models**: `lib/models/friend_models.dart` — FriendItem, FriendRequest, FriendLevel, FriendPrivilege, FriendRankItem, FriendHistoryItem
- **Providers**: `lib/providers/cp_provider.dart` (CpProvider), `lib/providers/friend_provider.dart` (FriendProvider)
- **API**: `ApiService` CP methods under `// ---- CP (Couple) ----` (all `/cp/*` endpoints), Friend methods under `// ---- Friend ----` (all `/friend/*` endpoints)
- **Screens**: `lib/screens/cp/` — cp_screen (hub with CP/Friend toggle), cp_detail_screen, cp_requests_screen, cp_ranking_screen, cp_level_screen, cp_milestones_screen, cp_history_screen, cp_rules_screen, cp_ring_gallery_screen, cp_privileges_screen
- **Widgets**: `lib/widgets/cp_widgets.dart` — CoupleAvatarPair, CPLevelBadge, BondProgressBar, CPStatTile, CPUserRow
- **Routes**: `AppRoutes.cp`, `cpDetail`, `cpRequests`, `cpRanking`, `cpLevel`, `cpMilestones`, `cpHistory`, `cpRules`, `cpRingGallery`, `cpPrivileges`, `friendLevel`, `friendHistory`, `friendRules`, `friendPrivileges`
- **Backend spec**: `docs/CP_BACKEND_API.md` — full API contract for CP + Friend backend implementation
- **Friend system**: Max 9 friends, 600,000 coins to bind, 1 coin = 1 intimacy, 120 Exp per 5 min co-stream (max 12,000/day)

## Build & Run Commands
- `flutter pub get` - Install dependencies
- `flutter analyze` - Static analysis
- `flutter build apk` - Build Android APK
- `flutter run` - Run on connected device

## Architecture
- **Models**: `lib/models/` - Data classes with hand-written `fromJson` factories (no build_runner)
- **Services**: `lib/services/` - API client, API service, session manager, FCM
- **Providers**: `lib/providers/` - ChangeNotifier-based state management with Provider
- **Screens**: `lib/screens/` - Feature-organized UI screens
- **Widgets**: `lib/widgets/` - Reusable UI components
- **Routes**: `lib/routes/app_routes.dart` - GoRouter-based navigation
- **Theme**: `lib/theme/app_theme.dart` - Centralized theme with brand colors
- **Constants**: `lib/constants/` - API keys, app constants
- **Utils**: `lib/utils/` - Logging, formatting helpers

## Key Conventions
- JSON parsing uses helpers from `lib/models/json_annotation_helper.dart` (`parseString`, `parseInt`, `parseBool`, `parseList`)
- All API calls go through `ApiService` in `lib/services/api_service.dart`
- Auth state managed by `AuthProvider` in `lib/providers/auth_provider.dart`
- Session persistence via `SessionManager` in `lib/services/session_manager.dart`
- Routing uses named GoRouter routes defined in `AppRoutes`

## Master Dynamic AI Control Engine
- **Frontend spec**: `FLUTTER_AI_FEATURES_INTEGRATION.md` — written by the backend team; defines 26 AI features (14 free + 12 paid), the `GET /api/v1/ai-config/get-active-features` endpoint, and the exact `featureKey` strings.
- **Backend spec**: `docs/AI_FEATURE_BACKEND_API.md` — compact reference + the extra endpoints the Flutter client calls (dynamic coin packs, compliance stream termination).
- **Models**: `lib/models/ai_feature_model.dart` — `AIFeatureConfigRoot` (parses `features` as a JSON object keyed by `featureKey`, tolerates arrays), `AIFeature` (with `name`, `category` free|paid, `is_enabled`), `AIFeatureAccess` (`category` is the gate type: all/level/vip/family/cp/host, plus `minLevel`/`minVipTier`), `AIFeatureUiBehavior` (`disabledBehavior` hide|locked + `lockedMessage`), `AIFeatureKeys` (all 26 well-known keys).
- **Service**: `lib/services/ai_feature_service.dart` — `AIFeatureService.getActiveFeatures()` calls `GET /api/v1/ai-config/get-active-features`.
- **Provider**: `lib/providers/ai_feature_manager.dart` — `AIFeatureManager` (ChangeNotifier) caches config in SharedPreferences, re-fetches on app launch + room join + every 10 min, exposes `isFeatureEnabled(key)`, `stateForCurrentUser(key, context)`, `shouldShowButton(key)`, `lockedMessageFor(key)`. Gate evaluation switches on `access.category`. Optional `AIAccessContext` for family/CP gates (not on User model). Strict billing rule: cloud SDKs are never initialised when `is_enabled == false`.
- **Widget**: `lib/widgets/ai_feature_guard.dart` — `AIFeatureGuard` wraps any UI button; renders child / locked (with lock badge + toast) / hidden based on the feature state.
- **Agora AI extensions**: `lib/services/agora_extensions_service.dart` — `AgoraExtensionsService` wraps `enableVoiceAITuner` (voice changer, key `ai_realtime_voice_changer`) and `enableSpatialAudio` (3D spatial audio, key `ai_3d_spatial_audio`), gated by `AIFeatureManager`. `kVoiceChangerPresets` is the top-level preset list.
- **Host compliance guard**: `lib/services/host_presence_guard_service.dart` — `HostPresenceGuardService` runs on-device face detection (ML Kit) every ~12s; escalates warning (1min) → block gifts (2min) → terminate stream (3min). Two modes: `startWithCamera` (GoLive) and `startWithAgora` (LiveRoom via VideoFrameObserver). Gated by `ai_host_compliance_guard`. Zero cloud cost.
- **Compliance UI**: `lib/widgets/host_compliance_overlay.dart` — `HostComplianceBanner` shows a red countdown banner + alert dialog + suspension toast.
- **Dynamic features**: `lib/services/dynamic_ai_features_service.dart` — `DynamicAIFeaturesService` drives voice-triggered 3D gifts (`ai_voice_triggered_3d_gifts`), PK matchmaker (`ai_pk_battle_matchmaker`), and dynamic coin packs (`ai_dynamic_coin_pricing`, falls back to `/coinPlan` when disabled).
- **Integration points**: `main.dart` registers `AIFeatureManager` in MultiProvider; `splash_screen.dart` triggers the first fetch; `live_room_screen.dart` and `audio_room_screen.dart` re-fetch on join, enable spatial audio, gate beauty button (`ai_realtime_beauty_makeup`) with `AIFeatureGuard`, add Quick PK Match, and start the host compliance guard; `recharge_screen.dart` uses dynamic coin packs.

## VIP Exclusive Privileges (Client-Side Enforcement)
All VIP exclusive privileges are enforced client-side based on the user's `vipDetails` (populated by backend on login/refresh) and per-payload `vipDetails` in socket events. Centralized in `lib/utils/vip_privilege_helper.dart` (`VipPrivilegeHelper`).
- **Helper**: `VipPrivilegeHelper` — local-user privilege checks (`canSendSvipGifts`, `canSendMessagePictures`, `canSendRoomPictures`, `canUsePremiumEmoji`, `hasGoldenName`, `hasColoredChat`, `hasNameAnimation`, `hasAntiKick`, `hasAntiMute`, `hasSpecialEntrance`, `hasRoomOnlineListTop`, etc.) + socket-payload VIP visual extraction (`chatStyleFromPayload` → `VipChatStyle`, `identityFromPayload` → `VipIdentity`). Self-asset accessors (`selfNameColor`, `selfChatBubbleUrl`, `selfBadgeUrl`, `selfFrameUrl`, `selfEntranceAnimationUrl`, `selfVoiceWaveUrl`). `parseHexColor` for `#RRGGBB`/`#AARRGGBB` strings.
- **Chat rendering** (live_room + audio_room): `_LiveComment` carries `VipChatStyle` (nameColor, chatBubbleUrl, isGoldenName, isColoredChat, isNameAnimation). `_buildCommentBubble` renders: custom name color (colored-chat), golden gradient bubble (golden-name), VIP chat bubble image (chatBubbleUrl as `DecorationImage`), shimmer name animation (isNameAnimation via `Shimmer.fromColors`). Extracted from socket payload `vipDetails` on receive; from local user's `vipDetails` on send.
- **Anti-kick**: `profile_room_card_sheet.dart` (audio room seat kick/mute/remove — checks `seat.isAntiKickEnabled`/`seat.isAntiMuteEnabled`); `live_room_screen.dart` viewer kick (`_onViewerTap` → `onKick` checks `v.isAntiKickEnabled`); `audio_room_screen.dart` mute-all (`_muteAllSeats` skips `seat.isAntiMuteEnabled`). `ViewerEntry` model carries `isAntiKickEnabled`/`isAntiMuteEnabled` parsed from `vipDetails`.
- **Anti-mute**: `audio_room_screen.dart` `_muteAllSeats` skips VIP-protected seats; `profile_room_card_sheet.dart` `_toggleMute` blocks mute of protected users.
- **SVIP gifts**: `gift_bottom_sheet.dart` `_selectGift` + `_sendGift` gate VIP-exclusive gifts (`gift.isVipGift || gift.isVipExclusive`) by `canSendSvipGifts`.
- **DM pictures**: `chat_screen.dart` `_pickAndSendMedia` gates image sending by `canSendMessagePictures`.
- **Room pictures**: `live_room_screen.dart` `_pickAndUploadRoomImage` gates by `user.vipDetails.isSendRoomPicturesEnabled` (pre-existing).
- **Premium emoji/stickers**: `emoji_picker_sheet.dart` `_giftGrid` gates VIP-exclusive emojis by `canUsePremiumEmoji`.
- **Entrance animation**: `vip_entry_overlay.dart` `VipEntryData` carries `isSpecialEntrance` (from `vipDetails.isSpecialRoomEntranceAnimationEnabled`); full-screen SVGA entrance only plays when flag is true, otherwise simple corner entry.
- **Viewer list top**: `live_room_screen.dart` + `audio_room_screen.dart` sort viewers by `isRoomOnlineListTopEnabled || isVIP` (pre-existing).
- **Profile background**: `profile_background_screen.dart` gates by `isProfileBackgroundEnabled`/`isMultipleProfileBackgroundsEnabled` (pre-existing).
- **VIP settings**: `vip_settings_screen.dart` gates View Visitor Records (VIP2), Profile Background (VIP3), Customized Theme (VIP3), Special ID (VIP5), Dynamic Avatar (VIP5), Unban Account (VIP7), Ban Account (VIP9), Hide Visitor Records (VIP2), Avoid Disturbing (VIP4), Hide Online Status (VIP6) by `_userVipLevel`.
- **EXP boost**: `gift_bottom_sheet.dart` sends `isExpBoostEnabled` flag in gift socket events for backend multiplier (pre-existing).
- **Backend dependency**: The backend must include `vipDetails` (with all `is*Enabled` flags + visual asset URLs) in: user object (login/refresh), chat socket events (`eventComment`/`eventCommentAudio`), seat data (`eventSeat`), viewer list (`eventView`), gift events. Without `vipDetails` in payloads, the client falls back to the generic `isVIP` boolean for golden styling only.

## Dependencies
- State management: `provider`
- Routing: `go_router`
- Networking: `dio`
- Firebase: `firebase_core`, `firebase_messaging`
- Local notifications: `flutter_local_notifications`
- Image picker: `image_picker`
- Toast: `fluttertoast`
- Video: `video_player`, `chewie`, `camera`
- Socket.IO: `socket_io_client`
- Shared prefs: `shared_preferences`
- Live streaming: `agora_rtc_engine`, `agora_token_generator`, `livekit_client` (with `flutter_webrtc`)
- Dependency overrides: `meta`, `device_info_plus`, `connectivity_plus`, `protobuf` (for livekit_client compatibility)

## Video Live Streaming — Dual Engine Support (Agora + LiveKit)
- **Service detection**: `shouldUseLiveKit()` in `lib/services/livekit_service.dart` — mirrors native `isLiveKit()` logic. Checks `service` field first (authoritative), then falls back to `livekitUrl`/`livekitToken` field detection.
- **LiveKit service**: `lib/services/livekit_service.dart` — `LiveKitService` wraps `livekit_client` SDK. Connect, publish audio/video (host), subscribe remote tracks (viewer), render video via `VideoTrackRenderer`, disconnect.
- **LiveRoomScreen integration**: `lib/screens/live/live_room_screen.dart` branches to LiveKit or Agora based on `shouldUseLiveKit()`. Mic/camera toggle, video render, and cleanup all support both engines.
- **PK Media Relay**: `lib/screens/live/pk_battle_screen.dart` uses `startOrUpdateChannelMediaRelay` (native `startMediaRelay2` approach) — both hosts stay in their own channels, video relayed cross-channel. No dual-channel join.
- **PK audience join** (`PkBattleScreen`, route `pkBattle`, pushed from `live_list_screen`/`live_room_join_service` when `room.isPkMode && room.pkConfig != null`): the tapped `LiveUser` is passed as `room` in route extras — its `channel`/`agoraUID` are authoritative for the watched host because late-join `pkConfig` payloads often omit `host1Channel`/`host1AgoraUID`. The viewer joins `room.channel` (fallback: pkConfig side channel → `liveUserId`/`liveRoomId`), then binds tiles via `_resolveViewerVideoUids`: left = room.agoraUID → config uid → first discovered publisher; right = config opponent uid → remaining discovered publisher. `_remoteVideoUids` is populated from `onRemoteVideoStateChanged` (starting/decoding = publishing; stopped/failed/`onUserOffline` = gone) — in a PK channel the only two publishers are the watched host and the relayed opponent, so discovered uids reconcile stale config values once both are visible. Audience also emits `addView` + `view` (`requestFullList`) on the watched room and `liveRoomConnect` on the opponent's room (so PK gift/comment events from both sides arrive), and `lessView` on dispose. Incoming `comment` events are filtered to the two PK `liveStreamingId`s — the socket is global.
- **Fake Watch Live**: `lib/screens/live/fake_watch_live_screen.dart` — plays pre-recorded video URL (`link` field) for fake hosts (`isFake: true`). Loops like a live stream, with comments, gifts, share. Route: `AppRoutes.fakeWatchLive` with `{'host': LiveUser}` extra.
- **Recording Replay**: `lib/screens/live/live_summary_screen.dart` — "Watch Replay" button opens `VideoPlayerScreen` (chewie) with recording URL.
- **Room Image Upload**: Host can send room pictures mid-live (VIP-gated). `_pickAndUploadRoomImage()` in `live_room_screen.dart` — image pick → `uploadChatImage` (topic optional) → delete chat entry → socket comment emit.
- **Viewer list semantics**: The `view` socket event carries an **authoritative full snapshot** ONLY when arg0 is a List — `emit('view', [roster], extraMap)` arrives packed as `[[...], {...}]` (socket_io_client: 2+ server args → `data` = args List; single arg → `data` = the arg itself). Both rooms emit `view` with `requestFullList: true` every 5s — send the FULL key set (`liveStreamingId`, `roomId`, `liveRoom`, `liveUserMongoId`, `liveUserId`, `userId`); the backend looks the roster up by `roomId`/`liveRoom` and omits them → empty reply. Non-empty rosters rebuild `_viewers` from non-host, non-invisible entries — **`isAdd` is ignored for snapshots** (presence = in-room; some backends mark snapshot rows `isAdd:false`, which used to zero the whole list). A bare `List` of maps (`data.first is Map`) is treated as a **delta**, not a snapshot — it can also be a per-join `emit('view', joinerMap, effectMap)` broadcast, and treating it as a roster wiped the list to ~1 on every join. **Empty/unparsable rosters NEVER clear `_viewers`** — the video-live roster reply can be empty while viewers are inside; real departures arrive via `lessView`/leave-comments/`viewerKicked`/`isLeave` markers. `_recentlyRemovedViewers` (3-5s suppression, `_markViewerRemoved`/`_isRecentlyRemoved`) stops in-flight stale snapshots from resurrecting users just removed by `lessView`/leave-comment/`viewerKicked`/kick. Host's `onKick` removes locally too (no round-trip wait). Viewer side keeps its local self-entry if the backend omits the requester from the snapshot. `liveRejoin`'s `view` field can only raise the count, never below `_viewers.length`. **Host-id aliasing** (`_hostIds` + `_isHostId`): the backend roster can carry the host under their User `_id` while `widget.liveUser.userId` is the `liveUserId` field — a different id. `_hostIds` is seeded from `liveUser.userId`/`liveUser.id` (+ `session.userId` when host), then grown from `_loadHostUniqueId`'s `getUser` result, `dummy` payload `userId._id`, and any comment where `isHost == true`. All host-exclusion checks must use `_isHostId`. `view` arg1 is now the request-echo/ack map — only feed it to `VipEntryOverlay` when it carries an effect asset (`entrySvga`/`svgaImage`/…), or each 5s poll replays an entrance. Debug: handler logs `'view event raw: $data'` + parsed userIds — check logcat before assuming a backend bug.
- **Multi-arg socket emits**: The backend sometimes emits events with 2 args (e.g. `view` = `[viewerArray, entryEffectMap]` — see native `onView(Object[])`). `socket_io_client` packs these into a single `List` arg, so a `data is Map` check silently drops them. For `view`, arg0 is the authoritative array and arg1 is either a joiner entry-effect map (fed to `VipEntryData` — overlay dedupes vs join comments) or a leave marker `{userId, isLeave:true}` (applied as an instant removal, excluded from the list). `live_room_screen._flattenViewPayload` recursively unwraps nested lists; `_socketMap` extracts the first Map arg for single-object events (addView/lessView/viewerKicked/viewerMuted/gift channels); `GiftQueueController.fromSocketData` does the same. `viewerKicked` may carry `viewerUserId`/`targetUserId` instead of `userId`. Sender/receiver fields in gift payloads may be nested under `user`/`sender`/`receiver`/`toUser` objects — always use the `pick()` fallbacks there, not just top-level `senderImage`.
- **Chat mute (profile card)**: Host/admin profile card (`showProfileRoomCard`) has a "Mute Chat"/"Unmute Chat" toggle (was "Ban Chat"; param `isChatMuted`, callback `onBanChat`). Audio room: `_banChatUser` toggles `_bannedChatUsers` + emits `banChat` socket (`mute: 3` mute / `mute: 0` unmute); `viewerMuted` handler updates the set (3/true → mute, 0/false → unmute); `_sendComment` blocks self when muted. Video live: `_muteViewerFromCard` toggles `_chatMutedUsers` + REST `muteViewerInLive` + `banChat` emit; `viewerMuted` maintains the set; comment handler drops muted senders; `_sendComment`/`_sendPhoto` block self.
- **Video live call invite / co-host remove (profile card)**: `showProfileRoomCard` takes `inviteLabel`/`removeLabel`/`emitSeatSocketOnRemove` (video passes 'Invite Call'/'Remove'/false — the card's built-in `lessParticipants` emit is audio-room-only). Viewer cards get `onInviteToSeat` → `_inviteViewerToCall(userId, name, image)` (emits `invite` + `comment` type `callInvite`, no dedup — every invite renders a new comment). `callInvite` comments render a `_callInviteBubble` in `AudioRoomCommentBubble` (`isCallInvite`/`callInviteForUserId` on `AudioRoomComment`, `onAcceptCallInvite` param): only the invited viewer (`callInviteForUserId == myUserId`) sees the Accept button → `_acceptCallInvite()` joins the call grid (shared with the invite dialog on the `invite` socket event). Co-host cards (`_coHosts.any(userId)`) get `position: 0` so the seated action branch shows `onRemoveFromSeat` → `_removeCoHostFromCall` emits `eventLessParticipatesCallJoin` (removed guest's client self-runs `_stopBroadcast` → drops to audience) + local removal. Video live passes `canMute: false` (seat mic-mute is audio-room-only).
- **Co-host surface churn (video live)**: Guest tiles are `useAndroidSurfaceView` platform views. When one enters/leaves the tree, the main video view (host local Texture or remote host SurfaceView) can freeze/black out on some devices — `_videoSurfaceEpoch` + `_refreshMainVideoSurface()` recreate the main `AgoraVideoView` (and all tiles) under new keys on every co-host add/remove (join, leave, `onUserOffline`, self `_startBroadcast`/`_stopBroadcast`), performing automatically the same recovery a manual camera off/on did. Host additionally re-calls `startPreview()` to rebind the local renderer. `addParticipates` skips re-creating an existing controller to avoid extra churn.
- **Co-host mic + tile name**: `joinChannel` always republishes the mic, so `_startBroadcast` re-applies the muted state after rejoin (`_micEnabled` is NOT reset; self/host-mute survives the audience→broadcaster switch — previously a mute during the join window was silently dropped). `muteCallJoin` emits now carry `liveUserMongoId`/`liveUserId`/`agoraUid`; self-matching in mute/leave/join handlers uses `_isSelfId` (matches session `_id` OR `uniqueId`). Guest tile labels resolve via `_ensureCoHostIdentity` (join-request data → `_coHostProfileCache` → one-time `getGuestProfile` fetch; `_coHostUidToUserId` maps orphan controllers to a userId) and render through `MarqueeText` — long names scroll instead of truncating to 'Guest'/ellipsis.
- **Backend message**: `docs/BACKEND_MESSAGE_VIDEO_LIVE.md` — 12 backend actions needed (gift broadcast, top gifters, recording URL, etc.). Flutter side 100% ready.
- **Lucky Gift win-back (LP)**: Gifts in the "Lucky" category (`_isLuckyCategoryGift` in `gift_bottom_sheet.dart` — categoryName contains "lucky") auto-run a client-side win-back draw on send (`_runLuckyDraw`: 28% win chance, 2x/3x/5x/10x/20x weighted multiplier, ~9% house edge). Runs for `type` live/audio/pk in both `_sendGift` (result dialog) and `_rapidSendGift` streaks (silent toast). Win is credited locally (coin + diamond kept in sync) and broadcast via `winLuckyGift` with `clientDraw: true` + `drawId` — room handlers in `live_room_screen.dart`/`audio_room_screen.dart` skip re-crediting the sender on echo but still show the gold banner/comment + combo re-send. The audio-room floating button is labeled "LP" (Lucky Port) and opens `showLiveLuckyBagSheet`. If the backend later runs authoritative draws, its `winLuckyGift`/`luckyGift` events render the same path.

## Facebook Login Setup (Pending Backend)
- Android placeholders added in `android/app/src/main/res/values/strings.xml`:
  - `facebook_app_id` — replace with real Facebook App ID
  - `facebook_client_token` — replace with real Facebook Client Token
- Dart side: `lib/constants/const.dart` has `facebookAppId` (currently empty; set to real App ID to enable Facebook login in `AccountBindingScreen`).
- Backend/admin should provide real values before enabling Facebook login.

## Bot Follower & Welcome Message System (Backend)
Backend-only feature. No Flutter changes — bots reuse existing follower, chat, chatTopic, and socket flows. Full spec: `BOT_FOLLOWER_SYSTEM_BACKEND_API.md` (repo root).
- **Backend module**: `Unilive-backend/server/bot/` — `bot.model.js` (BotConfig singleton), `bot.controller.js` (admin endpoints + internal auto-follow/welcome/progressive helpers), `bot.admin.route.js` (JWT-protected), `bot.seed.js` (default config seeder), `bot.data.js` (name/bio/avatar/country pools + `buildAvatar` via randomuser.me portraits).
- **User model fields** (`Unilive-backend/server/user/user.model.js`): `isBot` and `botFollowers` are `select: false` + stripped by `toJSON`/`toObject` transforms — **never exposed to the Flutter client**. Admin may query via `.select("+isBot")`.
- **Admin endpoints** (mounted at `/api/v1/admin` in `route.js`, JWT via `AdminMiddleware`): `POST /bots/seed` (create N bots, 500-1000 Beans each), `GET/PUT /bot-config`, `GET /bots/stats`.
- **Auto-follow on registration**: hooked into `user.controller.loginSignup` (lazy require to avoid circular dep). 30 bots for normal users, 100 for "special" (isHost/isVIP/isAgency/isBd flag at signup). Follows spread over 0-5 min via `setTimeout`; 1 bot sends a welcome chat message via `ChatTopic`+`Chat`+ the existing `chat` socket event to `globalRoom:<userId>`.
- **Progressive followers cron**: `runProgressiveFollowers` runs every 30 min (registered in `index.js` under `isPrimaryBackend`). Cumulative target = initial + sum of milestone counts (1h→+10, 1d→+20, 3d→+50, 7d→+100), capped at `maxTotal` (default 500). Per-tick user cap = 250.
- **isBot leak audit**: app-facing aggregations with `from: "users"` either use explicit `$project` or a final `.map()`/`$group` that picks safe fields. Fixed leaky lookups in `post.controller.js`, `video.controller.js` (commented-out `$project` → active), `fakeComment.controller.js` (added `$project`), `audioRoom.controller.js` (`...r.hostUser` spread → safe field pick). Admin-panel endpoints may see `isBot` (allowed).

## Audio Room Task System (Backend)
Admin-defined daily/once tasks for audio room engagement with rewards (exp/beans/diamonds). Full spec: `AUDIO_ROOM_BACKEND_TASK_SYTAM.MD` (repo root).
- **Backend module**: `Unilive-backend/server/audioRoomTask/` — `audioRoomTask.model.js` (title, type, targetCount, rewardType, rewardValue, frequency daily|once, roomIds, audience all|host|viewer, isActive), `audioRoomTaskProgress.model.js` (per-user per-day progress, unique on (userId, taskId, dateKey)), `audioRoomTask.controller.js`, `audioRoomTask.route.js` (app), `audioRoomTask.admin.route.js` (admin).
- **Task types**: `gifting_received`, `gifting_sent`, `time_spent`, `seat_time`, `chat_count`, `view_count`, `audio_room_engagement` (generic alias).
- **Admin endpoints** (mounted at `/api/v1/admin`, JWT via `AdminMiddleware`): `POST /tasks/create`, `GET /tasks`, `GET /tasks/stats`, `PATCH /tasks/:taskId/toggle`, `DELETE /tasks/:taskId`.
- **App endpoints** (mounted at `/api/v1/tasks` and `/tasks`, key-protected): `GET /active?roomId=&userId=`, `POST /claim?taskId=&userId=`.
- **Socket event**: `taskProgressUpdate` — emitted to `globalRoom:<userId>` with `{taskId, currentCount, targetCount, isCompleted}` on progress change.
- **Progress tracking integration** (in `socket.js`): `commentAudio` → `chat_count` (sender); `liveUserGift` → `gifting_sent` (sender) + `gifting_received` (room host); `addView` → `view_count` (host, peak tracking); seat-time ticker (60s interval) → `seat_time` for seated users; `time_spent` computed at read/claim time from `LiveStreamingHistory` duration. Reward credits `user.coin` (diamonds) / `user.rCoin` (beans) / `user.exp` (exp) + a `Wallet` entry (type 19, `text: "audioRoomTask:<type>"`).

## Audio Room Seat Counter (Backend)
Host/Admin can start/stop a per-seat timer; clients run a local 1s timer, server broadcasts periodic snapshots for late-joiner sync. Full spec: `AUDIO_ROOM_SEAT_COUNTER.MD` (repo root).
- **Service**: `Unilive-backend/server/audioRoom/seatCounter.service.js` — in-memory `Map<liveStreamingId, Map<position, {active, startedAt, value}>>`, `toggleSeatCounter()` (validates host/admin via `audioRoom.permissions`), `startSyncBroadcaster()` (5s interval, `unref`'d), `emitSnapshot()` (on join), `clearRoom()` (on room end).
- **Socket events** (in `socket.js`): `seatCounterToggle` (C2S & S2C, payload `{liveStreamingId, position, active}`; value resets on `active:true`), `seatCounterUpdate` (S2C, payload `{liveStreamingId, counters:[{position, value, active}]}`), `seatCounterError` (C2S error ack). On `liveRoomConnect` the server emits a snapshot so late joiners sync. `audioRoom.end` calls `clearRoom()`.

## Audio Room Admin & Moderator Roles (Backend)
Role-based permissions for audio rooms. Full spec: `AUDIO_ROOM_ADMIN_ROLES.md` (repo root).
- **Helper**: `Unilive-backend/server/audioRoom/audioRoom.permissions.js` — `getRole(liveUser, userId)` → `host|admin|vip|member`, `can(role, action)`, `resolveRole(liveStreamingId, userId)`, `shapeAdminList(liveUser)` for the `eventRoomAdminList` payload. Permission matrix: Mute/Lock/Kick/Ban/Seat-Counter = host+admin; Change-Theme/End-Room/Start-PK/Make-Admin = host only.
- **Endpoints** (kebab-case spec paths, mounted at `/api/v1/audio-room` and `/audioRoom`, key-protected): `POST /make-admin`, `POST /remove-admin` (host-only, body `{roomId, userId, hostUserId}`), `GET /admin-list?roomId=`. Existing camelCase `/audioRoom/makeAdmin` (action add/remove) kept for backward compat.
- **Socket events**: `eventRoomAdminList` (S2C, `[{adminUserId:{id,name,image}}]`) emitted on `liveRoomConnect` and on any admin-list change (also still emits `updateRoomAdmins` for old clients).
- **Permission enforcement**: `muteSeat`/`lockSeat`/`kickSeat` accept an optional `callerUserId` body field — when present, the role is checked against the matrix and rejected if unauthorized. Backward compatible: omitted `callerUserId` skips the check (existing Flutter calls keep working).

## Host Dashboard Task System (Backend)
Admin-defined daily/weekly host tasks for the Host Dashboard Tasks tab (Earnings/Level/Achievements/Tasks). Full spec: `HOST_DASHBOARD_TASK_BACKEND_API.md` (repo root). Separate from the room-level Audio Room Task System and the legacy `task` collection.
- **Backend module**: `Unilive-backend/server/hostDashboardTask/` — `hostDashboardTask.model.js` (title, description, frequency daily|weekly, targetType time|coin|viewers|gifts|mixed, target, mixedTargetType, mixedTarget, rewardCoins, isActive), `hostDashboardTask.controller.js` (admin CRUD + stats + internal `getActiveTasksForHost`/`claimDashboardTask`/`computeHostMetrics`/`computeTaskProgress`), `hostDashboardTask.admin.route.js` (JWT-protected), `hostDashboardTask.seed.js` (default tasks).
- **Admin endpoints** (mounted at `/api/v1/admin/host-tasks`, JWT via `AdminMiddleware`): `GET /` (filters: frequency, targetType, isActive), `POST /` (create), `PATCH /:taskId` (edit), `PATCH /:taskId/toggle` (enable/disable), `DELETE /:taskId`, `GET /stats` (claim counts per task in current reset window).
- **App endpoints** (reuse existing, key-protected): `GET /task/getTask?hostId=` — returns legacy tasks + dashboard tasks merged (dashboard tasks have `progress`, `completed`, `claimed`, `resetAt` runtime fields). `PATCH /task/claimTaskReward?hostId=&taskId=` — if taskId is not a legacy Task, falls through to `claimDashboardTask` which credits `user.coin` (diamonds) + Wallet entry (type 19, `text: "hostDashboardTask:..."`).
- **Progress sources**: `time` → `HostLiveHistory` liveDuration (audio+video minutes); `coin` → `Wallet` (type 0+13, isIncome, rCoin sum); `viewers` → `LiveStreamingHistory.user` (peak); `gifts` → `Wallet` gift transaction count. Weekly tasks roll up Mon–Sun (Asia/Kolkata). Daily resets at 00:00 IST.
- **Default seed** (auto-seeded on startup if collection empty): Daily — Stream 1 hour (+50), Get 10 gifts (+100), Reach 20 viewers (+75). Weekly — Stream 10 hours (+500), Get 100 gifts (+1000). Seeded in `index.js` `db.once("open")` via `seedDefaultHostDashboardTasks()`.
- **Master Admin UI**: `UniLive-masterAdmin/public/master-admin.html` + `master-admin.js` — "Host Dashboard Tasks" nav item under Levels section. Full CRUD UI: stat cards (total/active/daily/weekly), create form (with mixed-task support), filterable task table, toggle/edit/delete actions, claim stats table. Calls `/api/v1/admin/host-tasks` with admin JWT token.
- **Flutter integration**: `lib/screens/host/host_dashboard_screen.dart` renders the Tasks tab. `lib/services/host_features_service.dart` `getTasks()` calls `GET /task/getTask`, filters out legacy audio/video room tasks (no `frequency` or `targetType`), and maps dashboard fields (`title`, `description`, `frequency`, `target`, `progress`, `completed`, `claimed`, `rewardCoins`). `claimTaskReward()` calls `PATCH /task/claimTaskReward` with `hostId` and `taskId`.

## Gift / SVGA System
- **SVGA package**: `lib/widgets/svga_player_widget.dart` uses `svgaplayer_3: ^3.0.1` (import `package:svgaplayer_3/svgaplayer_flutter.dart`). This replaces the archived `svgaplayer_flutter` package and fixes transparent-background/alpha rendering issues.
- **URL resolution**: `lib/utils/media_utils.dart` — `VideoUtil.getFullImageUrl()` returns `''` for `.svga`/SVGA paths and must never be used for animation files. Always use `VideoUtil.getFullSvgaUrl()` for SVGA and `getFullImageUrl()` for static images / MP4.
- **Sender-side audio-room fix**: `lib/widgets/gift_bottom_sheet.dart` `_giftAssetUrl()` now routes `svgaImage` through `getFullSvgaUrl()` instead of `getFullImageUrl()`, which was returning an empty `svgaImage` for local audio-room gift callbacks.
- **Full-screen overlay**: `lib/widgets/big_gift_overlay.dart` is now used in video live, audio live, and PK (`lib/screens/live/pk_battle_screen.dart`). Its background is fully transparent, and the SVGA hide timer is driven by the decoded animation length so the full animation plays.
- **High quality**: `SvgaPlayer` passes `FilterQuality.high` to `SVGAImage`; big-gift image fallbacks no longer cap memory cache to low resolutions.
- **Tests**: `test/utils/media_utils_test.dart` validates SVGA vs image vs video URL routing.

## Host Center — Per-Type Live Tracking (audio vs video)
- **Contract**: every live-time heartbeat must carry `liveType`/`roomType` (`'audio'`|`'video'`) so the backend can bucket minutes/earnings under the right live type. Without it the backend double-counted a video live into the audio bucket too. Sent in: `ApiService.updateLiveTime` (query+body+PATCH fallback, param `liveType`), `roomTime`/`liveTimeSync` socket payloads, and stream-end payloads in `live_room_screen.dart` (`'video'`) and `audio_room_screen.dart` (`'audio'`).
- **Local cache**: `HostLiveCache` (`lib/services/host_features_service.dart`) tracks per-type durations (`host_audio_duration_*`/`host_video_duration_*`, seconds) and per-type earnings (`host_audio_earning_*`/`host_video_earning_*`, raw gift diamonds). `addDuration`/`addEarnings` require `liveType`. `getTodayProgress` returns `audioDuration`/`videoDuration` (minutes), `audioEarning`/`videoEarning` (diamonds; convert via `diamondsToBeans`), `todayEarning`/`totalMinutes` (combined).
- **Host Center merge** (`host_center_screen.dart` `_normalizeHostData`): typed history rows only absorb the matching cache bucket and show their own type's minutes — combined totals are never stamped onto a typed row. The today summary exposes `audioEarning`/`videoEarning` (Beans) = max(cache per-type, backend per-type fields, same-type history-row earnings).
- **Tasks tab** (`_taskTile`/`_claimTask`): `type:'audio'|'video'` tasks read only their own type's `*Duration`/`*Earning` fields (strict — no fallback to combined `totalMinutes`/`todayEarning`). Claim sends `liveType`/`taskType`/`type`, per-type `rCoin`/`coin`, `totalEarning` (combined), and the `liveStreamingId` of a matching-type session.
- **Backend dependency**: `/liveUser/updateLiveTime`, `roomTime`/`liveTimeSync` sockets and `PATCH /task/claimTaskReward` must honour `liveType`; `hostLiveHistory` rows carry `type` + `audioDuration`/`videoDuration` + per-type earning. If the backend ignores `liveType` it cannot attribute sessions correctly — client fix only stops the client-side double-counting. Full backend spec: `docs/BACKEND_MESSAGE_HOST_LIVE_TYPE_TRACKING.md`.

## Daily Check-in (added 2026-10)
- Backend module `server/checkin/` — `GET /checkin/status?userId=`, `POST /checkin/claim`.
- Reward table default: days 1-6 beans (rCoin 10/20/30/40/50/75), day 7 = 1 diamond (coin).
- Admin override: `global.settingJSON.checkinRewards` array of `{day,type:'coin'|'rcoin',amount}`.
- Missed a day → streak resets to Day 1; day 7 wraps back to 1.
- Flutter: `lib/widgets/daily_checkin_dialog.dart` — auto-shows once/day on home (`DailyCheckIn.maybeShow`, prefs key `checkin_prompted_date`), manual entry in Settings → "Daily Check-in".
- Model: `lib/models/checkin_root.dart`; API: `ApiService.getCheckInStatus` / `claimCheckIn`.

## Notification pre-prompt (added 2026-10)
- `lib/widgets/notification_prompt_dialog.dart` — "Enable Notifications?" dialog shows BEFORE the OS prompt; "Yes" → `FirebaseMessaging.requestPermission()`; "No" snoozes 7 days (`notif_prompt_snooze_until` pref).
- IMPORTANT: `PushNotificationService.initialize()` and `FcmService.init()` deliberately do NOT call requestPermission anymore — the pre-prompt owns the timing. Do not re-add direct requests at startup.
- Wired from `main_screen` `_showLaunchPopups` (notif prompt → check-in dialog chain).

## Banner placements (added 2026-10)
- Banner model fields: `placement` ('top'|'feed'|'both', default 'top'), `feedEvery` (insert after every N live cards, default 4), `order` (sort asc), `isActive`.
- Admin CRUD: `POST /banner` + `PATCH /banner/:id` accept `placement`, `feedEvery`, `order`, `isActive` (multipart with `image`).
- `GET /banner` returns only active banners sorted by order→createdAt.
- Flutter `BannerItem` exposes `showsInTop`/`showsInFeed`; live list splits into `_topBanners` (header carousel, 'all' tab) and `_feedBanners` (full-width rows injected every `feedEvery` cards in ALL discovery tabs).
- Shared fetch `_fetchBannersOnce()` — one API round-trip for all 4 tabs; pull-to-refresh forces refetch.
- broadcastBanner/luckyBanner items merge into the top carousel only (no placement fields on those models).

## Host video-call pool (added 2026-10)
- `POST /call-rate/opt-in {userId, optIn}` — host self opt-in/out of video+random call pool (was admin-only `videoCallOptIn` before).
- `/call-rate/set` auto opts the host in. `/call-rate/host` returns `videoCallOptIn`.
- `/user/videoCallHosts` — `userId` now optional; `status` param: active|online|live; response `callRate` = effective per-level rate.
- Flutter: Call Rate settings has "Accept video & random calls" toggle (CallRateProvider.setOptIn).
