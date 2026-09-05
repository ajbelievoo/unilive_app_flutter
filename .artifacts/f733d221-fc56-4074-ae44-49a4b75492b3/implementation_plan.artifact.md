# Fix Gift Animations and Socket Event Visibility in Live Rooms

The user reported that gift animations are not playing and reactions/comments are not visible during live streams. This plan addresses potential socket room subscription issues, strict filtering of room IDs, and robust gift type detection.

## User Review Required

> [!IMPORTANT]
> The fix assumes that the backend event `liveRoomConnect` is required for room subscription, which is a common pattern in the native app this was ported from.

## Proposed Changes

### Live Room & Sockets

#### [MODIFY] [live_room_screen.dart](file:///E:/uni/belive/lib/screens/live/live_room_screen.dart)
- Add `SocketService.instance.emit(Const.eventLiveRoomConnect, ...)` in `initState` to ensure the user is subscribed to room events.
- Relax `liveStreamingId` filtering in socket listeners (reaction, cheer, etc.) to only filter if the ID is present and non-empty. This prevents blocking events when the backend omits the ID in some payloads.
- Ensure `onGiftSent` correctly passes all parameters to the local animation controller.

#### [MODIFY] [audio_room_screen.dart](file:///E:/uni/belive/lib/screens/live/audio_room_screen.dart)
- Similar relaxation of `liveStreamingId` filtering in socket listeners.
- Add `liveRoomConnect` emit if missing.

### Gift Animations

#### [MODIFY] [gift_overlay.dart](file:///E:/uni/belive/lib/widgets/gift_overlay.dart)
- Update `GiftEvent` parsing and `GiftOverlay` rendering to automatically detect SVGA and Video gifts based on file extensions (`.svga`, `.mp4`, etc.) even if the `giftType` field is 0 or missing.
- Improve `GiftQueueController.fromSocketData` to handle more variations of backend gift payloads.

#### [MODIFY] [gift_bottom_sheet.dart](file:///E:/uni/belive/lib/widgets/gift_bottom_sheet.dart)
- Ensure `giftType` is correctly identified before emitting the socket event and calling `onGiftSent`.

## Verification Plan

### Automated Tests
- N/A (UI and Socket dependent)

### Manual Verification
1. Join a live room as a viewer and send a comment/reaction; verify they appear in the chat list.
2. Send a gift (both normal and SVGA/Big gift) and verify the animation plays correctly on both sender and receiver sides.
3. Observe if other users' comments and reactions are visible.
