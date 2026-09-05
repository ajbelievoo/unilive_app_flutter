/// KYC status & history screen.
///
/// Shows the user's current verification status, the latest request detail
/// (including the auto-check result from the KYC provider), and the full
/// submission history with status badges.
library kyc_status;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/kyc_models.dart';
import '../../providers/kyc_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import 'kyc_verified_dashboard.dart';
import 'package:belive/widgets/preloader.dart';

class KycStatusScreen extends StatefulWidget {
  const KycStatusScreen({super.key});

  @override
  State<KycStatusScreen> createState() => _KycStatusScreenState();
}

class _KycStatusScreenState extends State<KycStatusScreen> {
  static const Color _rejectedRed = Color(0xFFFF5A5A);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = context.read<SessionManager>();
      final provider = context.read<KycProvider>();
      provider.load(session.userId);
      provider.loadHistory(session.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<KycProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('KYC Status'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: provider.loading
          ? const Center(child: Preloader())
          : provider.isVerified
              ? KycVerifiedDashboard(
                  provider: provider,
                  onNeedHelp: () => context.pushNamed(AppRoutes.feedback),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    final session = context.read<SessionManager>();
                    await provider.load(session.userId);
                    await provider.loadHistory(session.userId);
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                    children: [
                      _statusCard(provider),
                      const SizedBox(height: 20),
                      if (provider.status.isRejected) ...[
                        _rejectionReasonCard(provider),
                        const SizedBox(height: 20),
                      ],
                      if (provider.status.latestRequest != null) ...[
                        _latestRequestCard(provider.status.latestRequest!),
                        const SizedBox(height: 20),
                      ],
                      _historySection(provider, isDark),
                      const SizedBox(height: 24),
                      _supportTile(context),
                    ],
                  ),
                ),
      floatingActionButton: provider.isVerified || !provider.isEnabled
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.pushNamed(AppRoutes.kyc),
              icon: const Icon(Icons.add, size: 22),
              label: const Text('New Verification', style: TextStyle(fontWeight: FontWeight.w700)),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              elevation: 4,
            ),
    );
  }

  Widget _statusCard(KycProvider provider) {
    final status = provider.status;
    final Color color;
    final IconData icon;
    final String title;
    final String subtitle;

    if (!provider.isEnabled) {
      color = AppTheme.textTertiary;
      icon = Icons.shield_outlined;
      title = 'KYC Disabled';
      subtitle = 'KYC verification is not required right now. You can use withdrawals and other features without verification.';
    } else if (status.isVerified) {
      color = AppTheme.green;
      icon = Icons.verified_user;
      title = 'Verified';
      subtitle = 'You are verified at Level ${status.kycLevel}'
          '${status.currentLevelName != null ? " (${status.currentLevelName})" : ""}.'
          '${status.currentLevelLimit > 0 ? "\nDaily withdrawal limit: ${status.currentLevelLimit} Beans" : "\nUnlimited withdrawals."}';
    } else if (status.isPending) {
      color = AppTheme.yellow;
      icon = Icons.hourglass_top;
      title = 'Verification in Progress';
      subtitle = 'Your KYC submission is under review. This usually takes 24-48 hours.';
    } else if (status.isRejected) {
      color = _rejectedRed;
      icon = Icons.cancel;
      title = 'Verification Rejected';
      final reason = KycRejectionReason.details(status.latestRequest?.rejectionReason);
      subtitle = reason.message;
    } else {
      color = AppTheme.primary;
      icon = Icons.info_outline;
      title = 'Not Verified';
      subtitle = 'Complete KYC verification to unlock withdrawals.';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  )),
            ),
          ]),
          const SizedBox(height: 12),
          Text(subtitle,
              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5)),
          if (status.kycVerifiedAt != null) ...[
            const SizedBox(height: 10),
            Text('Verified on: ${_formatDate(status.kycVerifiedAt)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  /// Detailed rejection reason card with actionable guidance + re-apply CTA.
  Widget _rejectionReasonCard(KycProvider provider) {
    final status = provider.status;
    final reason = KycRejectionReason.details(status.latestRequest?.rejectionReason);
    final canReapply = status.canReapply;
    final reapplyAt = status.reapplyAt;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _rejectedRed.withValues(alpha: 0.25), width: 1.5),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.error_outline, color: _rejectedRed, size: 22),
            SizedBox(width: 10),
            Text('Why was it rejected?',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _rejectedRed.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reason.message,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _rejectedRed)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 18, color: AppTheme.yellow),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(reason.guidance,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (status.latestRequest?.adminNote != null &&
              status.latestRequest!.adminNote!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.note_alt_outlined, size: 18, color: AppTheme.textTertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Admin note',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textTertiary)),
                      const SizedBox(height: 2),
                      Text(status.latestRequest!.adminNote!,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          if (canReapply && provider.isEnabled)
            FilledButton.icon(
              onPressed: () => context.pushNamed(AppRoutes.kyc),
              icon: const Icon(Icons.refresh),
              label: const Text('Re-apply Now'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                const Icon(Icons.lock_clock, size: 20, color: AppTheme.textTertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    reapplyAt != null
                        ? 'You can re-apply after ${_formatDate(reapplyAt)}'
                        : 'Please wait before re-applying.',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _latestRequestCard(KycRequest req) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Latest Submission',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const Spacer(),
            _statusBadge(req.status),
          ]),
          const SizedBox(height: 12),
          _row('Level', '${req.level}'),
          _row('Submitted', _formatDate(req.submittedAt)),
          if (req.reviewedAt != null) _row('Reviewed', _formatDate(req.reviewedAt)),
          _row('Admin note', req.adminNote?.trim().isNotEmpty == true ? req.adminNote! : ''),
          if (req.autoCheckResult != null) ...[
            const SizedBox(height: 12),
            const Text('Auto verification',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            _autoCheckRow('Face match', req.autoCheckResult!.faceMatch, req.autoCheckResult!.faceMatchScore),
            _autoCheckRow('ID valid', req.autoCheckResult!.idValid, req.autoCheckResult!.idValidScore),
            _autoCheckRow('Liveness', req.autoCheckResult!.livenessPassed, req.autoCheckResult!.livenessScore),
          ],
          const SizedBox(height: 12),
          // Image previews
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (req.selfieUrl != null) _imageThumb(req.selfieUrl!, 'Selfie'),
              if (req.idFrontUrl != null) _imageThumb(req.idFrontUrl!, 'ID Front'),
              if (req.idBackUrl != null) _imageThumb(req.idBackUrl!, 'ID Back'),
              ...req.documents.map((d) => _imageThumb(d.fileUrl, d.docLabel)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _autoCheckRow(String label, bool passed, int score) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(passed ? Icons.check_circle : Icons.cancel,
            color: passed ? AppTheme.green : _rejectedRed, size: 16),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
        const Spacer(),
        Text('$score%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: passed ? AppTheme.green : _rejectedRed,
            )),
      ]),
    );
  }

  Widget _imageThumb(String? url, String label) {
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CachedNetworkImage(
            imageUrl: url,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: 80,
              height: 80,
              color: AppTheme.surfaceLight,
              child: const Icon(Icons.image, color: AppTheme.textTertiary),
            ),
            errorWidget: (_, __, ___) => Container(
              width: 80,
              height: 80,
              color: AppTheme.surfaceLight,
              child: const Icon(Icons.broken_image, color: AppTheme.textTertiary),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _statusBadge(String status) {
    final Color color;
    switch (status) {
      case KycStatus.approved:
        color = AppTheme.green;
        break;
      case KycStatus.pending:
      case KycStatus.autoVerified:
        color = AppTheme.yellow;
        break;
      case KycStatus.rejected:
      case KycStatus.autoRejected:
        color = _rejectedRed;
        break;
      default:
        color = AppTheme.textTertiary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        KycStatus.label(status),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _historySection(KycProvider provider, bool isDark) {
    final history = provider.history;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text('History',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        ),
        if (history.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('No submissions yet',
                  style: TextStyle(color: isDark ? AppTheme.textSecondary : AppTheme.textTertiary)),
            ),
          )
        else
          ...history.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: AppTheme.purpleGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text('${r.level}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Level ${r.level} verification',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                          const SizedBox(height: 2),
                          Text(_formatDate(r.submittedAt),
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          if (r.adminNote != null && r.adminNote!.trim().isNotEmpty)
                            Text(r.adminNote!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
                        ],
                      ),
                    ),
                    _statusBadge(r.status),
                  ]),
                ),
              )),
      ],
    );
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  /// Support / complaint tile shown at the bottom of the non-verified status screen.
  Widget _supportTile(BuildContext context) {
    return GestureDetector(
      onTap: () => context.pushNamed(AppRoutes.feedback),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.surfaceVariant, width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.headset_mic_outlined, color: AppTheme.primary, size: 28),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Need help with KYC?',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Ask why it was rejected or report a problem.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: () => context.pushNamed(AppRoutes.feedback),
              child: const Text('Help', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
