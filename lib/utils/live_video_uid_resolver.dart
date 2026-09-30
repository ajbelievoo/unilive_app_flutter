enum LiveVideoParticipantRole { host, coHost, pkOpponent }

LiveVideoParticipantRole resolveLiveVideoParticipant({
  required bool isRoomHost,
  required int remoteUid,
  required int expectedHostUid,
  required int? currentHostUid,
  required Set<int> knownCoHostUids,
  int? pkOpponentUid,
}) {
  if (pkOpponentUid != null &&
      pkOpponentUid > 0 &&
      remoteUid == pkOpponentUid) {
    return LiveVideoParticipantRole.pkOpponent;
  }
  if (isRoomHost) return LiveVideoParticipantRole.coHost;
  if (expectedHostUid > 0 && remoteUid == expectedHostUid) {
    return LiveVideoParticipantRole.host;
  }
  if (currentHostUid != null &&
      currentHostUid > 0 &&
      remoteUid == currentHostUid) {
    return LiveVideoParticipantRole.host;
  }
  if (knownCoHostUids.contains(remoteUid)) {
    return LiveVideoParticipantRole.coHost;
  }
  // Unknown broadcaster while the host slot is empty — assume it is the
  // host. The expected uid can be stale (hosts rotate agoraUID on re-live on
  // the same channel) and must not push the real host into the guest strip.
  // If this was actually a guest whose socket event lagged, the real host's
  // arrival corrects it via promotion in the room screen.
  if (currentHostUid == null || currentHostUid <= 0) {
    return LiveVideoParticipantRole.host;
  }
  return LiveVideoParticipantRole.coHost;
}

({int host1, int host2}) resolvePkScores({
  required Map<String, dynamic> payload,
  required int currentHost1,
  required int currentHost2,
  bool? localIsHost1,
}) {
  int? resolve(List<String> keys) {
    for (final key in keys) {
      final value = payload[key];
      final parsed =
          value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
      if (parsed != null && parsed >= 0) return parsed;
    }
    return null;
  }

  // Try global host1/host2 score keys first. These are authoritative because
  // both hosts see the same canonical scores.
  // If both are 0 it is likely a stale opening payload, so fall through and
  // keep any existing local scores.
  final h1v = resolve(const ['host1Score', 'score1', 'host1Rank']);
  final h2v = resolve(const ['host2Score', 'score2', 'host2Rank']);
  if ((h1v ?? 0) > 0 || (h2v ?? 0) > 0) {
    return (host1: h1v ?? currentHost1, host2: h2v ?? currentHost2);
  }

  // Fall back to perspective-specific local/remote keys only when the
  // canonical global keys are missing. This avoids stale localRank/remoteRank
  // in the payload from overwriting the explicit host1Score/host2Score values.
  if (localIsHost1 != null) {
    final local = resolve(const ['localScore', 'localRank']);
    final remote = resolve(const ['remoteScore', 'remoteRank']);
    if (local != null || remote != null) {
      return localIsHost1
          ? (host1: local ?? currentHost1, host2: remote ?? currentHost2)
          : (host1: remote ?? currentHost1, host2: local ?? currentHost2);
    }
  }

  return (host1: currentHost1, host2: currentHost2);
}

({int host1, int host2}) pkScoresFromLocalPerspective({
  required bool localIsHost1,
  required int localScore,
  required int remoteScore,
}) =>
    localIsHost1
        ? (host1: localScore, host2: remoteScore)
        : (host1: remoteScore, host2: localScore);

String resolvePkRelayDestinationToken({
  required bool localIsHost1,
  required String? host1Token,
  required String? host2Token,
  required String? host1RelayDestToken,
  required String? host2RelayDestToken,
}) {
  // Prefer relay-specific destination tokens; fall back to the legacy
  // host1Token / host2Token mapping.
  if (localIsHost1) {
    return host2RelayDestToken?.trim().isNotEmpty == true
        ? host2RelayDestToken!
        : (host2Token ?? '');
  }
  return host1RelayDestToken?.trim().isNotEmpty == true
      ? host1RelayDestToken!
      : (host1Token ?? '');
}

String? resolvePkParticipantChannel({String? authoritative, String? fallback}) {
  final channel = authoritative?.trim();
  if (channel?.isNotEmpty == true) return channel;
  final fallbackChannel = fallback?.trim();
  return fallbackChannel?.isNotEmpty == true ? fallbackChannel : null;
}

int resolvePkParticipantUid({required int authoritative, int fallback = 0}) =>
    authoritative > 0 ? authoritative : fallback;

int pkWinnerFromScores({required int host1Score, required int host2Score}) {
  if (host1Score > host2Score) return 2;
  if (host2Score > host1Score) return 1;
  return 0;
}
