/// KYC verification submission screen.
///
/// Renders the active KYC levels configured by the admin panel, lets the user
/// pick the level to apply for, then captures a live selfie, live ID card
/// images, and uploads any extra documents required by that level. Submits
/// via [ApiService.submitKyc].
///
/// See `KYC_BACKEND_REQUIREMENTS.md` for the full backend spec.
library kyc_screen;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/kyc_models.dart';
import '../../providers/kyc_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import 'kyc_verified_dashboard.dart';
import 'kyc_camera_screen.dart';
import 'package:belive/widgets/preloader.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  static const String _tag = 'KycScreen';

  // ---- Card type options (spec §13.1) ------------------------------------
  // Sent to the backend as `idCardType` so anti-fraud/AI can use the
  // appropriate extraction model for the document.
  static const Map<String, String> _idCardTypes = {
    'aadhaar': 'Aadhaar',
    'pan': 'PAN',
    'voterId': 'Voter ID',
    'passport': 'Passport',
    'drivingLicense': 'Driving License',
    'other': 'Other',
  };

  // Selected level + captured files.
  KycLevelConfig? _selectedLevel;
  String? _selfiePath;
  String? _idFrontPath;
  String? _idBackPath;
  // Extra (level-required) documents — docKey -> file path.
  // Built from `GET /kyc/settings` `levels[].extraDocuments` — never hardcoded.
  final Map<String, String> _extraDocPaths = {};

  // Optional form fields.
  final _fullNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _idNumberCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  // Required card type (spec §13.1).
  String? _selectedIdCardType;

  bool _submitting = false;

  // Host request photo — shown before selfie capture so the user knows
  // their KYC selfie will be matched against this photo.
  String? _hostPhotoUrl;

  @override
  void initState() {
    super.initState();
    // Defer to after first frame so context.read works.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _dobCtrl.dispose();
    _idNumberCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final session = context.read<SessionManager>();
    final provider = context.read<KycProvider>();
    await provider.load(session.userId);
    // Fetch host request photo (for face match reference).
    try {
      final photoRes = await ApiService.getHostRequestPhoto(userId: session.userId);
      if (mounted) {
        setState(() {
          _hostPhotoUrl = photoRes['photoUrl'] as String?;
        });
      }
    } catch (e) {
      Log.w(_tag, 'Failed to load host photo: $e');
    }
    // Pre-select the next level the user can apply for.
    if (!mounted) return;
    final next = provider.nextLevel;
    if (next != null) {
      setState(() => _selectedLevel = next);
    } else if (provider.activeLevels.isNotEmpty) {
      setState(() => _selectedLevel = provider.activeLevels.first);
    }
  }

  // ---- Capture helpers ---------------------------------------------------

  Future<void> _captureSelfie() async {
    final provider = context.read<KycProvider>();
    final requireLiveness = provider.isLivenessRequiredFor(_selectedLevel);
    final path = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => KycCameraScreen(
          mode: KycCaptureMode.selfie,
          requireLiveness: requireLiveness,
        ),
      ),
    );
    if (path != null && path['path'] != null) {
      setState(() => _selfiePath = path['path'] as String);
    }
  }

  Future<void> _captureIdFront() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => KycCameraScreen(
          mode: KycCaptureMode.idCard,
          instruction: 'Place the FRONT of your ID card inside the frame.',
          cardType: _selectedIdCardType,
        ),
      ),
    );
    if (result != null && result['path'] != null) {
      setState(() => _idFrontPath = result['path'] as String);
      // Auto-fill form fields from OCR if available.
      final ocr = result['ocr'] as Map<String, dynamic>?;
      if (ocr != null) {
        _applyOcrData(ocr);
      }
    }
  }

  Future<void> _captureIdBack() async {
    final path = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => KycCameraScreen(
          mode: KycCaptureMode.idCard,
          instruction: 'Place the BACK of your ID card inside the frame.',
          cardType: _selectedIdCardType,
        ),
      ),
    );
    if (path != null && path['path'] != null) {
      setState(() => _idBackPath = path['path'] as String);
    }
  }

  /// Auto-fill form fields from OCR-extracted ID card data.
  /// Only fills empty fields — doesn't overwrite user edits.
  void _applyOcrData(Map<String, dynamic> ocr) {
    final fullName = ocr['fullName'] as String? ?? '';
    final dob = ocr['dob'] as String? ?? '';
    final idNumber = ocr['idNumber'] as String? ?? '';
    final address = ocr['address'] as String? ?? '';

    int filled = 0;
    if (fullName.isNotEmpty && _fullNameCtrl.text.isEmpty) {
      _fullNameCtrl.text = fullName;
      filled++;
    }
    if (dob.isNotEmpty && _dobCtrl.text.isEmpty) {
      _dobCtrl.text = dob;
      filled++;
    }
    if (idNumber.isNotEmpty && _idNumberCtrl.text.isEmpty) {
      _idNumberCtrl.text = idNumber;
      filled++;
    }
    if (address.isNotEmpty && _addressCtrl.text.isEmpty) {
      _addressCtrl.text = address;
      filled++;
    }

    if (filled > 0) {
      Fluttertoast.showToast(
        msg: 'Auto-filled $filled field(s) from ID card. Please verify.',
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  // ---- Extra document picker (auto-attach) -------------------------------

  /// Opens the file picker for an extra (level-required) document.
  ///
  /// Auto-attach: the picked file is immediately stored in [_extraDocPaths]
  /// and shown as a thumbnail with a "Replace" button — no separate "Upload"
  /// step. Validates `acceptedFormats` and `maxSizeMB` from the backend.
  Future<void> _pickExtraDoc(ExtraDocumentType doc) async {
    final allowed = doc.acceptedFormats.isNotEmpty
        ? doc.acceptedFormats.map((e) => e.toLowerCase()).toList()
        : null;

    FileType fileType;
    List<String>? extensions;

    if (allowed == null || allowed.isEmpty) {
      fileType = FileType.any;
    } else {
      final hasPdf = allowed.contains('pdf');
      final hasImages = allowed.any((a) => a == 'jpg' || a == 'png' || a == 'jpeg');
      if (hasPdf && !hasImages) {
        fileType = FileType.custom;
        extensions = ['pdf'];
      } else if (!hasPdf && hasImages) {
        fileType = FileType.image;
      } else {
        fileType = FileType.custom;
        extensions = allowed.map((e) => e == 'jpeg' ? 'jpg' : e).toList();
      }
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowMultiple: false,
        allowedExtensions: extensions,
      );
      if (result == null || result.files.single.path == null) return;
      final file = File(result.files.single.path!);

      // Validation (spec §14.2).
      final sizeMB = file.lengthSync() / (1024 * 1024);
      if (sizeMB > doc.maxSizeMB) {
        Fluttertoast.showToast(
          msg: 'File too large. Max ${doc.maxSizeMB}MB allowed for ${doc.label}.',
          toastLength: Toast.LENGTH_LONG,
        );
        return;
      }
      if (allowed != null && allowed.isNotEmpty) {
        final ext = result.files.single.extension?.toLowerCase() ?? '';
        if (!allowed.contains(ext) && !(ext == 'jpg' && allowed.contains('jpeg'))) {
          Fluttertoast.showToast(
            msg: 'Unsupported format .$ext. Allowed: ${allowed.join(", ")}.',
            toastLength: Toast.LENGTH_LONG,
          );
          return;
        }
      }

      setState(() => _extraDocPaths[doc.key] = file.path);
      Fluttertoast.showToast(msg: '${doc.label} attached');
    } catch (e, s) {
      Log.e(_tag, 'pickExtraDoc failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to pick file. Please try again.');
    }
  }

  // ---- Submit ------------------------------------------------------------

  /// Validates all required fields and returns a list of human-readable
  /// missing items (spec §15). Used both to disable the submit button and
  /// to show the summary toast on tap.
  List<String> _missingItems() {
    final level = _selectedLevel;
    if (level == null) return ['Select a verification level'];

    final missing = <String>[];
    if (_selectedIdCardType == null || _selectedIdCardType!.isEmpty) {
      missing.add('ID Card Type');
    }
    if (level.requireSelfie && _selfiePath == null) {
      missing.add('Selfie');
    }
    if (level.requireIdFront && _idFrontPath == null) {
      missing.add('ID Front');
    }
    if (level.requireIdBack && _idBackPath == null) {
      missing.add('ID Back');
    }
    for (final doc in level.extraDocuments) {
      if (doc.isRequired && _extraDocPaths[doc.key] == null) {
        missing.add(doc.label);
      }
    }
    if (_fullNameCtrl.text.trim().isEmpty) {
      missing.add('Full Name');
    }
    if (_dobCtrl.text.trim().isEmpty) {
      missing.add('Date of Birth');
    }
    if (_idNumberCtrl.text.trim().isEmpty) {
      missing.add('ID Number');
    }
    if (_addressCtrl.text.trim().isEmpty) {
      missing.add('Address');
    }
    return missing;
  }

  /// True when every required capture, document and form field is present.
  bool get _canSubmit {
    final level = _selectedLevel;
    if (level == null) return false;
    if (_submitting) return false;
    if (_selectedIdCardType == null || _selectedIdCardType!.isEmpty) return false;
    if (level.requireSelfie && _selfiePath == null) return false;
    if (level.requireIdFront && _idFrontPath == null) return false;
    if (level.requireIdBack && _idBackPath == null) return false;
    if (_fullNameCtrl.text.trim().isEmpty) return false;
    if (_dobCtrl.text.trim().isEmpty) return false;
    if (_idNumberCtrl.text.trim().isEmpty) return false;
    if (_addressCtrl.text.trim().isEmpty) return false;
    for (final doc in level.extraDocuments) {
      if (doc.isRequired && _extraDocPaths[doc.key] == null) return false;
    }
    return true;
  }

  Future<void> _submit() async {
    final level = _selectedLevel;
    if (level == null) {
      Fluttertoast.showToast(msg: 'Select a verification level');
      return;
    }
    // Validate required captures.
    if (level.requireSelfie && (_selfiePath == null)) {
      Fluttertoast.showToast(msg: 'Capture a live selfie');
      return;
    }
    if (level.requireIdFront && (_idFrontPath == null)) {
      Fluttertoast.showToast(msg: 'Capture the front of your ID card');
      return;
    }
    if (level.requireIdBack && (_idBackPath == null)) {
      Fluttertoast.showToast(msg: 'Capture the back of your ID card');
      return;
    }

    // Pre-submit validation (spec §15): show a single summary toast listing
    // everything that is still missing.
    final missing = _missingItems();
    if (missing.isNotEmpty) {
      Fluttertoast.showToast(
        msg: 'Please complete: ${missing.join(", ")}',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final session = context.read<SessionManager>();
      final provider = context.read<KycProvider>();

      final extraUploads = <KycDocumentUpload>[];
      for (final doc in level.extraDocuments) {
        final p = _extraDocPaths[doc.key];
        if (p != null) {
          extraUploads.add(KycDocumentUpload(key: doc.key, file: File(p)));
        }
      }

      final formFields = <String, String>{};
      if (_fullNameCtrl.text.trim().isNotEmpty) formFields['fullName'] = _fullNameCtrl.text.trim();
      if (_dobCtrl.text.trim().isNotEmpty) formFields['dob'] = _dobCtrl.text.trim();
      if (_idNumberCtrl.text.trim().isNotEmpty) formFields['idNumber'] = _idNumberCtrl.text.trim();
      if (_addressCtrl.text.trim().isNotEmpty) formFields['address'] = _addressCtrl.text.trim();

      final ok = await provider.submit(
        userId: session.userId,
        level: level.level,
        selfieFile: _selfiePath != null ? File(_selfiePath!) : null,
        idFrontFile: _idFrontPath != null ? File(_idFrontPath!) : null,
        idBackFile: _idBackPath != null ? File(_idBackPath!) : null,
        extraDocuments: extraUploads,
        formFields: formFields,
        idCardType: _selectedIdCardType,
      );

      if (!mounted) return;
      if (ok) {
        // Reflect the actual backend decision: an instant auto-verification
        // (auto_verified / approved) shows a success toast, otherwise the
        // request is pending manual review.
        final reqStatus = provider.lastRequestStatus;
        final msg = (reqStatus == KycStatus.autoVerified ||
                reqStatus == KycStatus.approved)
            ? 'Verified! Your KYC is complete.'
            : 'KYC submitted. Under review.';
        Fluttertoast.showToast(
          msg: msg,
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.CENTER,
        );
        context.pushNamed(AppRoutes.kycStatus);
      } else {
        final errMsg = provider.error ?? 'Submission failed';
        Log.e(_tag, 'submit returned false: $errMsg');
        Fluttertoast.showToast(
          msg: errMsg,
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.CENTER,
        );
      }
    } catch (e, s) {
      Log.e(_tag, 'submit failed', e, s);
      Fluttertoast.showToast(
        msg: 'Failed to submit: $e',
        toastLength: Toast.LENGTH_LONG,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ---- UI ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<KycProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Identity Verification'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'KYC History',
            onPressed: () => context.pushNamed(AppRoutes.kycStatus),
          ),
        ],
      ),
      body: provider.loading
          ? const Center(child: Preloader(color: AppTheme.primary))
          : !provider.isEnabled
              ? _disabledState()
              : provider.isVerified && provider.nextLevel == null
                  ? Container(
                      color: isDark ? const Color(0xFF121212) : AppTheme.background,
                      child: KycVerifiedDashboard(
                        provider: provider,
                        statusCardTopPadding: MediaQuery.of(context).padding.top + 32,
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: isDark
                            ? AppTheme.darkGradient
                            : LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppTheme.primary.withValues(alpha: 0.08),
                                  AppTheme.background,
                                ],
                                stops: const [0, 0.3],
                              ),
                      ),
                      child: RefreshIndicator(
                        onRefresh: () => _load(),
                        color: AppTheme.primary,
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 70, 16, 40),
                          children: [
                            _heroBanner(provider),
                            const SizedBox(height: 24),
                            if (_selectedLevel != null) ...[
                              _progressTracker(_selectedLevel!),
                              const SizedBox(height: 24),
                              _captureSection(_selectedLevel!),
                              const SizedBox(height: 24),
                              _formSection(_selectedLevel!),
                              const SizedBox(height: 24),
                              _extraDocsSection(_selectedLevel!),
                              const SizedBox(height: 32),
                              _submitButton(),
                              const SizedBox(height: 16),
                              _securityNote(),
                            ] else ...[
                              _levelSelector(provider),
                            ],
                          ],
                        ),
                      ),
                    ),
      backgroundColor: isDark ? const Color(0xFF121212) : AppTheme.background,
    );
  }

  Widget _disabledState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppTheme.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_outlined, size: 40, color: AppTheme.textTertiary),
            ),
            const SizedBox(height: 20),
            const Text('Verification Unavailable',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            const Text('KYC verification is not available right now. Please check back later.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  /// Premium hero banner with shield icon, status, and gradient background.
  Widget _heroBanner(KycProvider provider) {
    final status = provider.status;
    final IconData badgeIcon;
    final String badgeText;
    final String badgeSubtext;
    final LinearGradient gradient;

    if (status.isVerified) {
      badgeIcon = Icons.verified_user_rounded;
      badgeText = 'Verified';
      badgeSubtext = 'Level ${status.kycLevel} · You can withdraw earnings';
      gradient = AppTheme.greenGradient;
    } else if (status.isPending) {
      badgeIcon = Icons.hourglass_top_rounded;
      badgeText = 'Under Review';
      badgeSubtext = 'Your verification is being processed';
      gradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppTheme.yellow, Colors.orange],
      );
    } else if (status.isRejected) {
      badgeIcon = Icons.cancel_rounded;
      badgeText = 'Rejected';
      badgeSubtext = 'Please re-submit with correct documents';
      gradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.red, Colors.redAccent],
      );
    } else {
      badgeIcon = Icons.shield_rounded;
      badgeText = 'Get Verified';
      badgeSubtext = 'Complete KYC to unlock withdrawals';
      gradient = AppTheme.primaryGradient;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(badgeIcon, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 14),
          Text(badgeText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 4),
          Text(badgeSubtext,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
          if (status.isVerified && status.currentLevelLimit > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text('Daily limit: ${status.currentLevelLimit} RCoins',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Visual progress tracker showing capture steps with checkmarks.
  Widget _progressTracker(KycLevelConfig level) {
    final steps = <_ProgressStep>[];
    if (level.requireSelfie) {
      steps.add(_ProgressStep('Selfie', Icons.face, _selfiePath != null));
    }
    if (level.requireIdFront) {
      steps.add(_ProgressStep('ID Front', Icons.badge, _idFrontPath != null));
    }
    if (level.requireIdBack) {
      steps.add(_ProgressStep('ID Back', Icons.badge_outlined, _idBackPath != null));
    }
    if (level.requireIdFront || level.requireIdBack) {
      final formFilled = _fullNameCtrl.text.isNotEmpty || _idNumberCtrl.text.isNotEmpty;
      steps.add(_ProgressStep('Details', Icons.edit_note, formFilled));
    }
    steps.add(const _ProgressStep('Submit', Icons.send, false));

    final doneCount = steps.where((s) => s.done).length;
    final progress = doneCount / steps.length;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Progress',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              Text('$doneCount / ${steps.length}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primary)),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppTheme.surfaceVariant,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
          const SizedBox(height: 14),
          // Step chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < steps.length; i++) ...[
                  _stepChip(steps[i]),
                  if (i < steps.length - 1) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 16, color: AppTheme.textTertiary),
                    const SizedBox(width: 4),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepChip(_ProgressStep step) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: step.done
            ? AppTheme.green.withValues(alpha: 0.12)
            : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: step.done ? AppTheme.green.withValues(alpha: 0.3) : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            step.done ? Icons.check_circle : step.icon,
            size: 14,
            color: step.done ? AppTheme.green : AppTheme.textTertiary,
          ),
          const SizedBox(width: 5),
          Text(step.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: step.done ? AppTheme.green : AppTheme.textSecondary,
              )),
        ],
      ),
    );
  }

  Widget _levelSelector(KycProvider provider) {
    final levels = provider.activeLevels;
    if (levels.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No verification levels configured.',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Choose Verification Level',
            subtitle: 'Higher levels unlock higher withdrawal limits'),
        ...levels.map((l) => _levelCard(l, provider)),
      ],
    );
  }

  Widget _levelCard(KycLevelConfig level, KycProvider provider) {
    final selected = _selectedLevel?.level == level.level;
    final isCurrent = provider.kycLevel >= level.level && provider.isVerified;
    final isLocked = provider.isVerified && provider.kycLevel < level.level - 1;
    final gradient = level.level == 1
        ? AppTheme.blueGradient
        : level.level == 2
            ? AppTheme.purpleGradient
            : AppTheme.goldGradient;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: isLocked
              ? () => Fluttertoast.showToast(msg: 'Complete the previous level first')
              : () => setState(() => _selectedLevel = level),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? AppTheme.primary : Colors.transparent,
                width: 2,
              ),
              boxShadow: selected
                  ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 4))]
                  : AppTheme.cardShadow,
            ),
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.colors.first.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.shield_rounded, color: Colors.white, size: 26),
                    Positioned(
                      bottom: 6,
                      child: Text(
                        'L${level.level}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(level.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          )),
                      const SizedBox(width: 8),
                      if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check, size: 10, color: AppTheme.green),
                              SizedBox(width: 3),
                              Text('Active',
                                  style: TextStyle(fontSize: 10, color: AppTheme.green, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      if (isLocked)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.lock_rounded, size: 14, color: AppTheme.textTertiary),
                        ),
                    ]),
                    const SizedBox(height: 4),
                    if (level.description != null)
                      Text(level.description!,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: level.dailyWithdrawLimit > 0
                            ? AppTheme.surfaceLight
                            : AppTheme.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            level.dailyWithdrawLimit > 0 ? Icons.savings_outlined : Icons.all_inclusive,
                            size: 14,
                            color: level.dailyWithdrawLimit > 0 ? AppTheme.textTertiary : AppTheme.green,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            level.dailyWithdrawLimit > 0
                                ? '${level.dailyWithdrawLimit} Beans / day'
                                : 'Unlimited',
                            style: TextStyle(
                              fontSize: 11,
                              color: level.dailyWithdrawLimit > 0 ? AppTheme.textTertiary : AppTheme.green,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppTheme.primary : AppTheme.textTertiary,
                size: 24,
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          ]),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ),
        ],
      ),
    );
  }

  Widget _captureSection(KycLevelConfig level) {
    final tiles = <Widget>[];
    int stepNum = 1;
    if (level.requireSelfie) {
      final provider = context.read<KycProvider>();
      final aiConfig = provider.aiConfig;
      // Show host photo reference only when the backend has face-match
      // enabled AND the user has an approved host photo on file.
      final showHostRef = aiConfig.faceMatch &&
          _hostPhotoUrl != null &&
          _hostPhotoUrl!.isNotEmpty;
      if (showHostRef) {
        tiles.add(_hostPhotoReference());
        tiles.add(const SizedBox(height: 12));
      }
      final livenessRequired = provider.isLivenessRequiredFor(_selectedLevel);
      tiles.add(_captureTile(
        title: 'Live Selfie',
        subtitle: showHostRef
            ? 'Will be matched with your host photo'
            : livenessRequired
                ? 'Front camera · Liveness check'
                : 'Front camera',
        icon: Icons.face,
        path: _selfiePath,
        onTap: _captureSelfie,
        required: true,
        stepNum: stepNum++,
      ));
    }
    if (level.requireIdFront) {
      tiles.add(const SizedBox(height: 12));
      tiles.add(_captureTile(
        title: 'ID Card — Front',
        subtitle: 'Camera capture · Auto-extract details',
        icon: Icons.badge,
        path: _idFrontPath,
        onTap: _captureIdFront,
        required: true,
        stepNum: stepNum++,
      ));
    }
    if (level.requireIdBack) {
      tiles.add(const SizedBox(height: 12));
      tiles.add(_captureTile(
        title: 'ID Card — Back',
        subtitle: 'Camera capture',
        icon: Icons.badge_outlined,
        path: _idBackPath,
        onTap: _captureIdBack,
        required: true,
        stepNum: stepNum++,
      ));
    }
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Required Captures',
            subtitle: 'Live camera only — gallery uploads not accepted'),
        ...tiles,
      ],
    );
  }

  /// Shows the user's host request photo as a reference before KYC selfie
  /// capture. This sets the expectation that the selfie will be matched
  /// against this photo for fraud prevention.
  Widget _hostPhotoReference() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 56,
            height: 56,
            child: _hostPhotoUrl != null && _hostPhotoUrl!.isNotEmpty
                ? Image.network(_hostPhotoUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppTheme.surfaceLight,
                      child: const Icon(Icons.person, color: AppTheme.primary),
                    ))
                : Container(
                    color: AppTheme.surfaceLight,
                    child: const Icon(Icons.person, color: AppTheme.primary),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.face_retouching_natural, size: 16, color: AppTheme.primary),
                SizedBox(width: 5),
                Text('Host Profile Photo',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              ]),
              SizedBox(height: 3),
              Text(
                'Your KYC selfie will be matched with this photo for verification.',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.3),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _captureTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required String? path,
    required VoidCallback onTap,
    bool required = false,
    int stepNum = 0,
  }) {
    final hasFile = path != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasFile ? AppTheme.green.withValues(alpha: 0.4) : AppTheme.surfaceVariant,
              width: hasFile ? 2 : 1,
            ),
            boxShadow: hasFile
                ? [BoxShadow(color: AppTheme.green.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))]
                : AppTheme.cardShadow,
          ),
          child: Row(children: [
            // Step number badge
            if (stepNum > 0)
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: hasFile ? AppTheme.green : AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: hasFile
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : Text('$stepNum',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                ),
              ),
            // Preview image or placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 72,
                height: 72,
                child: hasFile
                    ? Image.file(File(path), fit: BoxFit.cover)
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: AppTheme.primaryGradient.colors.map((c) => c.withValues(alpha: 0.1)).toList(),
                          ),
                        ),
                        child: Icon(icon, size: 32, color: AppTheme.primary),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    if (required) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Required',
                            style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(hasFile ? Icons.check_circle : Icons.camera_alt_rounded,
                        size: 14, color: hasFile ? AppTheme.green : AppTheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      hasFile ? 'Captured — tap to retake' : 'Tap to capture',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: hasFile ? AppTheme.green : AppTheme.primary,
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _formSection(KycLevelConfig level) {
    if (!level.requireIdFront && !level.requireIdBack) {
      return const SizedBox.shrink();
    }
    final hasOcr = _fullNameCtrl.text.isNotEmpty || _idNumberCtrl.text.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('ID Details',
            subtitle: hasOcr ? 'Auto-filled from ID card — verify & edit' : 'As they appear on your ID document'),
        if (hasOcr)
          Container(
            margin: const EdgeInsets.only(bottom: 12, left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 14, color: AppTheme.green),
                SizedBox(width: 5),
                Text('Auto-extracted from ID card',
                    style: TextStyle(fontSize: 11, color: AppTheme.green, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        _idCardTypeDropdown(),
        const SizedBox(height: 12),
        _styledTextField(_fullNameCtrl, 'Full Name', Icons.person_outline_rounded,
            onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        _styledTextField(_dobCtrl, 'Date of Birth', Icons.calendar_today_outlined,
            readOnly: true, onTap: _pickDob),
        const SizedBox(height: 12),
        _styledTextField(_idNumberCtrl, 'ID / Document Number', Icons.badge_rounded,
            onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        _styledTextField(_addressCtrl, 'Address', Icons.location_on_outlined,
            maxLines: 2, onChanged: (_) => setState(() {})),
      ],
    );
  }

  /// Card type selector (spec §13.1). Required; the value is sent to the
  /// backend as `idCardType` and also tunes the on-device OCR heuristics.
  Widget _idCardTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(
          color: _selectedIdCardType == null
              ? AppTheme.yellow.withValues(alpha: 0.5)
              : AppTheme.surfaceVariant,
          width: _selectedIdCardType == null ? 1.5 : 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedIdCardType,
          hint: const Row(children: [
            Icon(Icons.credit_card_rounded, color: AppTheme.primary, size: 22),
            SizedBox(width: 12),
            Text('Select ID card type *',
                style: TextStyle(fontSize: 14, color: AppTheme.textTertiary)),
          ]),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primary),
          items: _idCardTypes.entries.map((e) {
            return DropdownMenuItem<String>(
              value: e.key,
              child: Row(children: [
                const Icon(Icons.badge_outlined, color: AppTheme.primary, size: 20),
                const SizedBox(width: 12),
                Text(e.value,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              ]),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() => _selectedIdCardType = v);
            }
          },
          dropdownColor: Colors.white,
        ),
      ),
    );
  }

  Widget _styledTextField(TextEditingController ctrl, String label, IconData icon,
      {bool readOnly = false, VoidCallback? onTap, int maxLines = 1, void Function(String)? onChanged}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      child: TextField(
        controller: ctrl,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: onChanged,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppTheme.textTertiary, fontSize: 13),
          prefixIcon: Icon(icon, color: AppTheme.primary, size: 22),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.surfaceVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.surfaceVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.primary, width: 2),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year - 16),
    );
    if (picked != null) {
      _dobCtrl.text = '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Widget _submitButton() {
    final enabled = _canSubmit && !_submitting;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: FilledButton.icon(
        onPressed: enabled ? _submit : null,
        icon: _submitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: Preloader(strokeWidth: 2.5, color: Colors.white))
            : const Icon(Icons.verified_rounded, size: 22),
        label: Text(
          _submitting ? 'Submitting…' : 'Submit for Verification',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: enabled ? AppTheme.primary : AppTheme.surfaceVariant,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }

  /// Additional Documents section (spec §14).
  ///
  /// Built dynamically from the backend's `level.extraDocuments` — never
  /// hardcoded. Tapping a card auto-attaches the picked file.
  Widget _extraDocsSection(KycLevelConfig level) {
    if (!level.hasExtraDocuments) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Additional Documents',
            subtitle: 'Attach documents required for this level'),
        ...level.extraDocuments.map((doc) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _extraDocTile(doc),
            )),
      ],
    );
  }

  /// Returns a user-friendly description for an extra document. We override
  /// the backend description for Address Proof so it lists accepted IDs.
  String _extraDocDescription(ExtraDocumentType doc) {
    final lower = doc.label.toLowerCase();
    if (lower.contains('address')) {
      return 'Upload Aadhaar, PAN, Voter ID, Passport, Driving License or utility/bank document.';
    }
    return doc.description!;
  }

  Widget _extraDocTile(ExtraDocumentType doc) {
    final path = _extraDocPaths[doc.key];
    final hasFile = path != null;
    final isPdf = hasFile && path.toLowerCase().endsWith('.pdf');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasFile ? AppTheme.green.withValues(alpha: 0.4) : AppTheme.surfaceVariant,
          width: hasFile ? 2 : 1,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: hasFile ? AppTheme.greenGradient : AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(hasFile ? Icons.task_alt_rounded : Icons.upload_file_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(doc.label,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    ),
                    if (doc.isRequired) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Required',
                            style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ]),
                  if (doc.description != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      _extraDocDescription(doc),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          if (hasFile)
            const Row(children: [
              Icon(Icons.check_circle, size: 14, color: AppTheme.green),
              SizedBox(width: 4),
              Text('Attached',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.green)),
            ])
          else
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _pickExtraDoc(doc),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2), width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_photo_alternate_outlined, size: 18, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Text('Tap to attach ${doc.label}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                  ],
                ),
              ),
            ),
          if (hasFile) ...[
            const SizedBox(height: 10),
            Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: isPdf
                      ? Container(
                          color: Colors.red.withValues(alpha: 0.1),
                          child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 28),
                        )
                      : Image.file(File(path), fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${doc.acceptedFormats.join(", ")} · Max ${doc.maxSizeMB}MB',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickExtraDoc(doc),
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: const Text('Replace', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _securityNote() {
    final provider = context.read<KycProvider>();
    final aiConfig = provider.aiConfig;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lock_rounded, color: AppTheme.primary, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your data is encrypted and securely stored. '
                  'We only use it for verification purposes.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                ),
              ),
            ],
          ),
          if (aiConfig.hasAnyCheck) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.shield_rounded, color: AppTheme.primary.withValues(alpha: 0.7), size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Anti-fraud protection by ${aiConfig.providerDisplayName}'
                    '${aiConfig.faceMatch ? ' · Face match' : ''}'
                    '${aiConfig.duplicateId ? ' · Duplicate ID check' : ''}'
                    '${aiConfig.duplicateFace ? ' · Duplicate face search' : ''}'
                    '${aiConfig.liveness && provider.livenessRequired ? ' · Liveness' : ''}',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.primary.withValues(alpha: 0.7),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Data class for progress tracker steps.
class _ProgressStep {
  const _ProgressStep(this.label, this.icon, this.done);
  final String label;
  final IconData icon;
  final bool done;
}
