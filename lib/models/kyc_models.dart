/// KYC (Know Your Customer) verification models.
///
/// Ported to match the backend spec in `KYC_BACKEND_REQUIREMENTS.md`.
/// Hand-written fromJson (no build_runner) — same convention as other models.
library kyc_models;

import 'json_annotation_helper.dart';

// ---- Status constants ---------------------------------------------------

/// Possible KYC request statuses returned by the backend.
class KycStatus {
  KycStatus._();
  static const String pending = 'pending';
  static const String autoVerified = 'auto_verified';
  static const String autoRejected = 'auto_rejected';
  static const String approved = 'approved';
  static const String rejected = 'rejected';

  /// User-level KYC status (rolled up from the latest request).
  static const String unverified = 'unverified';
  static const String verified = 'verified';

  /// Human-readable label for a request status.
  static String label(String status) {
    switch (status) {
      case pending:
        return 'Pending';
      case autoVerified:
        return 'Auto Verified';
      case autoRejected:
        return 'Auto Rejected';
      case approved:
        return 'Approved';
      case rejected:
        return 'Rejected';
      case unverified:
        return 'Not Verified';
      case verified:
        return 'Verified';
      default:
        return 'Unknown';
    }
  }

  /// Whether the request is in a "waiting" state (not yet finalised).
  static bool isWaiting(String status) =>
      status == pending || status == autoVerified;

  /// Whether the request is a final approved state.
  static bool isApproved(String status) => status == approved;

  /// Whether the request is a final rejected state.
  static bool isRejected(String status) =>
      status == rejected || status == autoRejected;
}

/// Maps a machine-readable `rejectionReason` key (returned by the backend) to
/// a user-friendly message + actionable guidance shown in the KYC status UI.
///
/// See `KYC_BACKEND_REQUIREMENTS.md` §15 for the full list of keys.
class KycRejectionReason {
  KycRejectionReason._();

  /// Returns `(message, guidance)` for a [reasonKey].
  static ({String message, String guidance}) details(String? reasonKey) {
    switch (reasonKey) {
      case 'face_match_failed':
        return (
          message: 'Your selfie did not match your ID photo.',
          guidance: 'Retake the selfie in good lighting, facing the camera directly without glasses or a hat.',
        );
      case 'id_not_readable':
        return (
          message: 'Your ID photo was not clear enough to read.',
          guidance: 'Retake the ID photo on a flat surface with good lighting. Avoid glare and shadows.',
        );
      case 'id_expired':
        return (
          message: 'Your ID document has expired.',
          guidance: 'Use a valid, unexpired government-issued ID (passport, driver\u2019s license, or national ID).',
        );
      case 'id_not_supported':
        return (
          message: 'This type of ID document is not supported.',
          guidance: 'Use a government-issued ID such as a passport, driver\u2019s license, or national ID card.',
        );
      case 'id_already_used':
        return (
          message: 'This ID has already been used for another account.',
          guidance: 'Each ID can only be linked to one account. Contact support if you believe this is an error.',
        );
      case 'liveness_failed':
        return (
          message: 'Liveness check failed \u2014 we could not confirm you are a real person.',
          guidance: 'Hold the phone at eye level in a well-lit room, look directly at the camera, and blink naturally.',
        );
      case 'document_missing':
        return (
          message: 'A required document was not uploaded.',
          guidance: 'Make sure all required documents for your verification level are uploaded before submitting.',
        );
      case 'document_blurry':
        return (
          message: 'An uploaded document was blurry.',
          guidance: 'Retake the photo in good lighting and hold the device steady. Ensure all text is sharp.',
        );
      case 'document_too_large':
        return (
          message: 'An uploaded document exceeded the size limit.',
          guidance: 'Compress the image to under the max size shown on the upload tile, then try again.',
        );
      case 'name_mismatch':
        return (
          message: 'The name on your ID did not match the name you entered.',
          guidance: 'Enter your full name exactly as it appears on your ID document.',
        );
      case 'duplicate_account':
        return (
          message: 'A verified account already exists with your details.',
          guidance: 'Each person can only have one verified account. Contact support if you believe this is an error.',
        );
      case 'suspected_fraud':
        return (
          message: 'Your submission was flagged for review.',
          guidance: 'Please contact support for a manual review of your verification.',
        );
      case 'admin_rejected':
        return (
          message: 'Your submission was rejected by our verification team.',
          guidance: 'Please review the admin note below and re-apply with corrected documents.',
        );
      case 'other':
      default:
        return (
          message: 'Your submission was rejected.',
          guidance: 'Please review the note below or contact support for help.',
        );
    }
  }
}

// ---- Global settings ----------------------------------------------------

/// Top-level KYC configuration returned by `/kyc/settings`.
///
/// Provider keys / secrets are intentionally NOT included — the backend
/// never ships them to the app.
class KycSettings {
  KycSettings({
    this.isEnabled = false,
    this.blockWithdrawal = true,
    this.autoVerifyEnabled = false,
    this.livenessRequired = true,
    this.reapplyCooldownHours = 24,
    this.levels = const [],
  });

  final bool isEnabled;
  final bool blockWithdrawal;
  final bool autoVerifyEnabled;
  final bool livenessRequired;
  final int reapplyCooldownHours;
  final List<KycLevelConfig> levels;

  factory KycSettings.fromJson(Map<String, dynamic> json) => KycSettings(
        isEnabled: parseBool(json['isEnabled']),
        blockWithdrawal: parseBool(json['blockWithdrawal'], true),
        autoVerifyEnabled: parseBool(json['autoVerifyEnabled']),
        livenessRequired: parseBool(json['livenessRequired'], true),
        reapplyCooldownHours: parseInt(json['reapplyCooldownHours'], 24),
        levels: parseList(json['levels'], KycLevelConfig.fromJson),
      );

  /// The highest active level number, or 0 if none active.
  int get maxActiveLevel =>
      levels.where((l) => l.isActive).fold(0, (m, l) => l.level > m ? l.level : m);

  /// Find a level config by [level] number.
  KycLevelConfig? level(int level) {
    for (final l in levels) {
      if (l.level == level) return l;
    }
    return null;
  }
}

// ---- Level config -------------------------------------------------------

/// Configuration for a single KYC level (embedded in [KycSettings.levels]).
class KycLevelConfig {
  KycLevelConfig({
    this.level = 0,
    this.name = '',
    this.isActive = false,
    this.requireSelfie = false,
    this.requireIdFront = false,
    this.requireIdBack = false,
    this.requireLiveness = false,
    this.extraDocuments = const [],
    this.dailyWithdrawLimit = 0,
    this.monthlyWithdrawLimit = 0,
    this.autoVerifyEnabled = false,
    this.description,
  });

  final int level;
  final String name;
  final bool isActive;
  final bool requireSelfie;
  final bool requireIdFront;
  final bool requireIdBack;
  final bool requireLiveness;
  final List<ExtraDocumentType> extraDocuments;
  final int dailyWithdrawLimit;
  final int monthlyWithdrawLimit;
  final bool autoVerifyEnabled;
  final String? description;

  factory KycLevelConfig.fromJson(Map<String, dynamic> json) => KycLevelConfig(
        level: parseInt(json['level']),
        name: parseString(json['name'], '') ?? '',
        isActive: parseBool(json['isActive']),
        requireSelfie: parseBool(json['requireSelfie']),
        requireIdFront: parseBool(json['requireIdFront']),
        requireIdBack: parseBool(json['requireIdBack']),
        requireLiveness: parseBool(json['requireLiveness']),
        extraDocuments: parseList(json['extraDocuments'], ExtraDocumentType.fromJson),
        dailyWithdrawLimit: parseInt(json['dailyWithdrawLimit']),
        monthlyWithdrawLimit: parseInt(json['monthlyWithdrawLimit']),
        autoVerifyEnabled: parseBool(json['autoVerifyEnabled']),
        description: parseString(json['description']),
      );

  /// Whether this level requires any documents beyond selfie/ID.
  bool get hasExtraDocuments => extraDocuments.isNotEmpty;
}

/// Extra document type required by a level (e.g. address proof).
class ExtraDocumentType {
  ExtraDocumentType({
    this.key = '',
    this.label = '',
    this.description,
    this.acceptedFormats = const [],
    this.maxSizeMB = 10,
    this.isRequired = true,
  });

  final String key;
  final String label;
  final String? description;
  final List<String> acceptedFormats;
  final int maxSizeMB;
  final bool isRequired;

  factory ExtraDocumentType.fromJson(Map<String, dynamic> json) => ExtraDocumentType(
        key: parseString(json['key'], '') ?? '',
        label: parseString(json['label'], '') ?? '',
        description: parseString(json['description']),
        acceptedFormats: (json['acceptedFormats'] as List?)
                ?.map((e) => parseString(e, '') ?? '')
                .where((s) => s.isNotEmpty)
                .toList() ??
            const [],
        maxSizeMB: parseInt(json['maxSizeMB'], 10),
        isRequired: parseBool(json['isRequired'], true),
      );
}

// ---- User KYC status ----------------------------------------------------

/// Rolled-up KYC status for the current user, returned by `/kyc/status`.
class KycUserStatus {
  KycUserStatus({
    this.status = false,
    this.kycStatus = KycStatus.unverified,
    this.kycLevel = 0,
    this.kycVerifiedAt,
    this.currentLevelName,
    this.currentLevelLimit = 0,
    this.nextLevel,
    this.canReapply = true,
    this.reapplyAt,
    this.latestRequest,
  });

  final bool status;
  final String kycStatus;
  final int kycLevel;
  final String? kycVerifiedAt;
  final String? currentLevelName;
  final int currentLevelLimit;
  final KycLevelSummary? nextLevel;
  final bool canReapply;
  final String? reapplyAt;
  final KycRequest? latestRequest;

  factory KycUserStatus.fromJson(Map<String, dynamic> json) => KycUserStatus(
        status: parseBool(json['status'], true),
        kycStatus: parseString(json['kycStatus'], KycStatus.unverified) ?? KycStatus.unverified,
        kycLevel: parseInt(json['kycLevel']),
        kycVerifiedAt: parseString(json['kycVerifiedAt']),
        currentLevelName: parseString(json['currentLevelName']),
        currentLevelLimit: parseInt(json['currentLevelLimit']),
        nextLevel: json['nextLevel'] == null
            ? null
            : KycLevelSummary.fromJson(json['nextLevel'] as Map<String, dynamic>),
        canReapply: parseBool(json['canReapply'], true),
        reapplyAt: parseString(json['reapplyAt']),
        latestRequest: json['latestRequest'] == null
            ? null
            : KycRequest.fromJson(json['latestRequest'] as Map<String, dynamic>),
      );

  bool get isVerified => kycStatus == KycStatus.verified || kycLevel > 0;
  bool get isPending => kycStatus == KycStatus.pending;
  bool get isRejected => kycStatus == KycStatus.rejected;
}

/// Lightweight level summary used in `nextLevel` of [KycUserStatus].
class KycLevelSummary {
  KycLevelSummary({this.level = 0, this.name = '', this.description});

  final int level;
  final String name;
  final String? description;

  factory KycLevelSummary.fromJson(Map<String, dynamic> json) => KycLevelSummary(
        level: parseInt(json['level']),
        name: parseString(json['name'], '') ?? '',
        description: parseString(json['description']),
      );
}

// ---- KYC request --------------------------------------------------------

/// A single KYC submission, returned by `/kyc/history`, `/kyc/request`, and
/// embedded as `latestRequest` in [KycUserStatus].
class KycRequest {
  KycRequest({
    this.id,
    this.userId,
    this.level = 0,
    this.status = KycStatus.pending,
    this.selfieUrl,
    this.idFrontUrl,
    this.idBackUrl,
    this.documents = const [],
    this.formFields,
    this.autoCheckResult,
    this.adminNote,
    this.rejectionReason,
    this.submittedAt,
    this.reviewedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String? userId;
  final int level;
  final String status;
  final String? selfieUrl;
  final String? idFrontUrl;
  final String? idBackUrl;
  final List<KycDocument> documents;
  final Map<String, dynamic>? formFields;
  final AutoCheckResult? autoCheckResult;
  final String? adminNote;
  final String? rejectionReason;
  final String? submittedAt;
  final String? reviewedAt;
  final String? createdAt;
  final String? updatedAt;

  factory KycRequest.fromJson(Map<String, dynamic> json) => KycRequest(
        id: parseString(json['_id'] ?? json['id']),
        userId: parseString(json['userId']),
        level: parseInt(json['level']),
        status: parseString(json['status'], KycStatus.pending) ?? KycStatus.pending,
        selfieUrl: parseString(json['selfieUrl']),
        idFrontUrl: parseString(json['idFrontUrl']),
        idBackUrl: parseString(json['idBackUrl']),
        documents: parseList(json['documents'], KycDocument.fromJson),
        formFields: json['formFields'] is Map
            ? Map<String, dynamic>.from(json['formFields'] as Map)
            : null,
        autoCheckResult: json['autoCheckResult'] == null
            ? null
            : AutoCheckResult.fromJson(json['autoCheckResult'] as Map<String, dynamic>),
        adminNote: parseString(json['adminNote']),
        rejectionReason: parseString(json['rejectionReason']),
        submittedAt: parseString(json['submittedAt']),
        reviewedAt: parseString(json['reviewedAt']),
        createdAt: parseString(json['createdAt']),
        updatedAt: parseString(json['updatedAt']),
      );
}

/// An extra uploaded document embedded in a [KycRequest].
class KycDocument {
  KycDocument({
    this.docKey = '',
    this.docLabel = '',
    this.fileUrl,
    this.fileName,
    this.fileType,
    this.fileSize = 0,
  });

  final String docKey;
  final String docLabel;
  final String? fileUrl;
  final String? fileName;
  final String? fileType;
  final int fileSize;

  factory KycDocument.fromJson(Map<String, dynamic> json) => KycDocument(
        docKey: parseString(json['docKey'], '') ?? '',
        docLabel: parseString(json['docLabel'], '') ?? '',
        fileUrl: parseString(json['fileUrl']),
        fileName: parseString(json['fileName']),
        fileType: parseString(json['fileType']),
        fileSize: parseInt(json['fileSize']),
      );
}

/// Result of the automatic provider face-match / ID validation check.
class AutoCheckResult {
  AutoCheckResult({
    this.provider,
    this.faceMatch = false,
    this.faceMatchScore = 0,
    this.idValid = false,
    this.idValidScore = 0,
    this.livenessPassed = false,
    this.livenessScore = 0,
    this.overallPassed = false,
    this.checkedAt,
    this.error,
  });

  final String? provider;
  final bool faceMatch;
  final int faceMatchScore;
  final bool idValid;
  final int idValidScore;
  final bool livenessPassed;
  final int livenessScore;
  final bool overallPassed;
  final String? checkedAt;
  final String? error;

  factory AutoCheckResult.fromJson(Map<String, dynamic> json) => AutoCheckResult(
        provider: parseString(json['provider']),
        faceMatch: parseBool(json['faceMatch']),
        faceMatchScore: parseInt(json['faceMatchScore']),
        idValid: parseBool(json['idValid']),
        idValidScore: parseInt(json['idValidScore']),
        livenessPassed: parseBool(json['livenessPassed']),
        livenessScore: parseInt(json['livenessScore']),
        overallPassed: parseBool(json['overallPassed']),
        checkedAt: parseString(json['checkedAt']),
        error: parseString(json['error']),
      );
}

// ---- Withdrawal pre-check ----------------------------------------------

/// Result of `/kyc/withdrawal-check`, used by the app to decide whether to
/// allow the user into the redeem screen.
class KycWithdrawalCheck {
  KycWithdrawalCheck({
    this.status = false,
    this.canWithdraw = false,
    this.reason,
    this.message,
    this.kycLevel = 0,
    this.dailyLimitRemaining = 0,
    this.monthlyLimitRemaining = 0,
  });

  final bool status;
  final bool canWithdraw;
  final String? reason;
  final String? message;
  final int kycLevel;
  final int dailyLimitRemaining;
  final int monthlyLimitRemaining;

  /// Reason codes returned by the backend.
  static const String reasonKycRequired = 'kyc_required';
  static const String reasonLimitExceeded = 'limit_exceeded';

  factory KycWithdrawalCheck.fromJson(Map<String, dynamic> json) => KycWithdrawalCheck(
        status: parseBool(json['status'], true),
        canWithdraw: parseBool(json['canWithdraw']),
        reason: parseString(json['reason']),
        message: parseString(json['message']),
        kycLevel: parseInt(json['kycLevel']),
        dailyLimitRemaining: parseInt(json['dailyLimitRemaining']),
        monthlyLimitRemaining: parseInt(json['monthlyLimitRemaining']),
      );
}

// ---- Submit response ----------------------------------------------------

/// Response from `POST /kyc/submit`.
class KycSubmitResponse {
  KycSubmitResponse({
    this.status = false,
    this.message,
    this.requestId,
    this.requestStatus = KycStatus.pending,
    this.rejectionReason,
    this.rejectionDetails,
  });

  final bool status;
  final String? message;
  final String? requestId;
  final String requestStatus;
  final String? rejectionReason;
  final Map<String, dynamic>? rejectionDetails;

  factory KycSubmitResponse.fromJson(Map<String, dynamic> json) => KycSubmitResponse(
        status: parseBool(json['status']),
        message: parseString(json['message']),
        requestId: parseString(json['requestId']),
        requestStatus: parseString(json['requestStatus'], KycStatus.pending) ?? KycStatus.pending,
        rejectionReason: parseString(json['rejectionReason']),
        rejectionDetails: json['rejectionDetails'] is Map<String, dynamic>
            ? json['rejectionDetails'] as Map<String, dynamic>
            : null,
      );

  /// Human-readable rejection reason for the user.
  String get rejectionMessage {
    switch (rejectionReason) {
      case 'duplicate_id':
        return 'This government ID has already been used for verification by another account.';
      case 'face_mismatch':
        final sim = rejectionDetails?['faceSimilarity'];
        return 'Your KYC selfie does not match your host profile photo'
            '${sim != null ? ' (similarity: ${sim.toStringAsFixed(1)}%)' : ''}. '
            'Please ensure you use the same face as your host photo.';
      case 'duplicate_face':
        return 'This face has already been verified under another account. '
            'Using multiple accounts is not allowed.';
      case 'fake_id':
        return 'Your ID document could not be verified. Please ensure it is a valid government ID.';
      case 'auto_check_failed':
        return 'AI verification failed. Please try again or use clearer documents.';
      default:
        return message ?? 'Submission failed. Please try again.';
    }
  }
}

// ---- Live check --------------------------------------------------------

/// Response from `GET /kyc/live-check`.
/// Determines whether the user is allowed to start a live stream.
class KycLiveCheck {
  KycLiveCheck({
    this.status = false,
    this.canGoLive = false,
    this.reason,
    this.message,
    this.kycStatus = KycStatus.unverified,
    this.kycLevel = 0,
    this.hostStatus = 'none',
  });

  final bool status;
  final bool canGoLive;
  final String? reason;
  final String? message;
  final String kycStatus;
  final int kycLevel;
  final String hostStatus;

  /// Reason codes.
  static const String reasonKycRequired = 'kyc_required';
  static const String reasonKycPending = 'kyc_pending';
  static const String reasonKycRejected = 'kyc_rejected';
  static const String reasonHostNotApproved = 'host_not_approved';
  static const String reasonHostNoRequest = 'host_no_request';

  factory KycLiveCheck.fromJson(Map<String, dynamic> json) => KycLiveCheck(
        status: parseBool(json['status'], true),
        canGoLive: parseBool(json['canGoLive']),
        reason: parseString(json['reason']),
        message: parseString(json['message']),
        kycStatus: parseString(json['kycStatus'], KycStatus.unverified) ?? KycStatus.unverified,
        kycLevel: parseInt(json['kycLevel']),
        hostStatus: parseString(json['hostStatus'], 'none') ?? 'none',
      );
}

// ---- History root -------------------------------------------------------

/// Root response for `/kyc/history`.
class KycHistoryRoot {
  KycHistoryRoot({this.status = false, this.history = const []});

  final bool status;
  final List<KycRequest> history;

  factory KycHistoryRoot.fromJson(Map<String, dynamic> json) => KycHistoryRoot(
        status: parseBool(json['status'], true),
        history: parseList(json['history'], KycRequest.fromJson),
      );
}

// ---- AI config (public) ------------------------------------------------

/// Public AI configuration returned by `GET /kyc/ai-config`.
///
/// The app uses this to know which anti-fraud features are enabled on the
/// backend so it can show appropriate UI hints (e.g. "Your selfie will be
/// matched with your host photo" only when `faceMatch` is enabled).
///
/// No credentials are exposed — only the provider name, feature flags, and
/// thresholds.
class KycAiConfig {
  KycAiConfig({
    this.status = false,
    this.provider = 'aws_rekognition',
    this.faceMatch = true,
    this.duplicateId = true,
    this.duplicateFace = true,
    this.idValidation = false,
    this.liveness = false,
    this.faceMatchThreshold = 80,
    this.duplicateFaceThreshold = 90,
  });

  final bool status;
  final String provider;

  /// Feature flags — which anti-fraud checks the backend will run.
  final bool faceMatch;
  final bool duplicateId;
  final bool duplicateFace;
  final bool idValidation;
  final bool liveness;

  /// Thresholds (0-100).
  final int faceMatchThreshold;
  final int duplicateFaceThreshold;

  /// Provider display name for UI.
  static const Map<String, String> providerNames = {
    'aws_rekognition': 'AWS Rekognition',
    'azure_face': 'Azure Face API',
    'faceplusplus': 'Face++ (Megvii)',
    'kairos': 'Kairos',
    'onfido': 'Onfido (Entrust)',
  };

  String get providerDisplayName => providerNames[provider] ?? provider;

  /// Whether any anti-fraud check is enabled.
  bool get hasAnyCheck =>
      faceMatch || duplicateId || duplicateFace || idValidation || liveness;

  factory KycAiConfig.fromJson(Map<String, dynamic> json) {
    final config = json['config'] is Map<String, dynamic>
        ? json['config'] as Map<String, dynamic>
        : <String, dynamic>{};
    final features = config['features'] is Map<String, dynamic>
        ? config['features'] as Map<String, dynamic>
        : <String, dynamic>{};
    final thresholds = config['thresholds'] is Map<String, dynamic>
        ? config['thresholds'] as Map<String, dynamic>
        : <String, dynamic>{};
    return KycAiConfig(
      status: parseBool(json['status'], true),
      provider: parseString(config['provider'], 'aws_rekognition') ?? 'aws_rekognition',
      faceMatch: parseBool(features['faceMatch'], true),
      duplicateId: parseBool(features['duplicateId'], true),
      duplicateFace: parseBool(features['duplicateFace'], true),
      idValidation: parseBool(features['idValidation']),
      liveness: parseBool(features['liveness']),
      faceMatchThreshold: parseInt(thresholds['faceMatch'], 80),
      duplicateFaceThreshold: parseInt(thresholds['duplicateFace'], 90),
    );
  }

  /// Default config (used when the endpoint is not yet available on backend).
  factory KycAiConfig.defaultConfig() => KycAiConfig(status: true);
}
