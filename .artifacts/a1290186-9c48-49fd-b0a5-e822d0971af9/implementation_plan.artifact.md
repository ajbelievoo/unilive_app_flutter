# Audio Room Enhancements: UI, Viewer Sync, and Seat Logic

This plan addresses several UI and functional issues in the audio room, matching it closer to the "UnilivePro" reference.

## User Review Required

> [!IMPORTANT]
> - **Seat Joining**: When "Free Talk" mode is ON, users can sit on any empty, unlocked seat immediately without host approval. When OFF, they must request to join.
> - **Mic Wave**: I will replace the current SVGA-based wave with a circular pulse animation around the seat avatar to match the "waves from all sides" requirement.

## Proposed Changes

### [Audio Room Screen]

#### [MODIFY] [audio_room_screen.dart](file:///E:/uni/belive/lib/screens/live/audio_room_screen.dart)
- **Viewer Sync**:
    - Add host to `_viewers` list in `initState`.
    - Add periodic timer (20s) to emit `view` event to keep viewer list updated.
    - Add socket listener for `wheatMode` to sync "Free Talk" state across all users.
- **Seat Logic**:
    - Implement `_directJoinSeat(int position)` to allow joining without request when `_wheatMode` is active.
    - Update `onTap` in `_buildFanSeats` to use `_wheatMode` logic.
- **UI & Animations**:
    - **_SeatWidget redesign**:
        - Remove the thick grey ring background.
        - Simplified transparent background for empty seats.
        - Circular pulse animation around the avatar when `isSpeaking` is true.
        - Reposition reaction overlay to be centered on top.
        - Ensure `Stack` has `clipBehavior: Clip.none` and sufficient spacing in parent `Column/Row`.
- **Top Bar**:
    - Ensure `_wheatMode` toggle in top bar is visible to the host.

### [Widgets]

#### [MODIFY] [mic_wave_widget.dart](file:///E:/uni/belive/lib/widgets/mic_wave_widget.dart) (Optional)
- Add a circular pulse mode if reusable, or just implement it directly in `_SeatWidget`.

## Verification Plan

### Automated Tests
- None available for socket/live features.

### Manual Verification
1.  **Viewer List**: Join room with 2 devices. Verify both show in the viewers list and the count is 2.
2.  **Seat UI**: Verify seats look cleaner (no grey ring).
3.  **Mic Wave**: Speak and verify circular pulse appears around the avatar.
4.  **Free Talk**:
    - Turn "Free Talk" ON as host. On viewer device, tap a seat and verify immediate join.
    - Turn OFF. Verify viewer must send request.
5.  **Reactions**: Send reaction on a bottom seat and verify it's fully visible.
