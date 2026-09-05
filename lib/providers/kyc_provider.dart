import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/kyc_models.dart';
import '../services/api_service.dart';
import '../utils/log.dart';

/// Manages KYC (Know Your Customer) verification state for the current user.
///
/// Loads the active KYC config from the admin panel, the user's rolled-up
/// status, and exposes a [submit] helper that uploads selfie / ID / documents.
/// Also exposes [canWithdraw] which the wallet / redeem screens use to decide
/// whether to allow the user into the withdrawal flow.
class KycProvider extends ChangeNotifier {
  KycProvider();

  static const String _tag = 'KycProvider';

  // ---- State -------------------------------------------------------------
  KycSettings _settings = KycSettings();
  KycSettings get settings => _settings;

  KycUserStatus _status = KycUserStatus();
  KycUserStatus get status => _status;

  /// Public AI config — which anti-fraud features are enabled on the backend.
  KycAiConfig _aiConfig = KycAiConfig.defaultConfig();
  KycAiConfig get aiConfig => _aiConfig;

  final List<KycRequest> _history = [];
  List<KycRequest> get history => List.unmodifiable(_history);

  bool _loading = false;
  bool get loading => _loading;

  bool _submitting = false;
  bool get submitting => _submitting;

  String? _error;
  String? get error => _error;

  /// The `requestStatus` returned by the most recent [submit] call. The UI
  /// uses this to distinguish an instant auto-verification
  /// (`auto_verified` / `approved`) from a pending manual review, so it can
  /// show the right success message without an extra network round-trip.
  String? _lastRequestStatus;
  String? get lastRequestStatus => _lastRequestStatus;

  // ---- Convenience getters ----------------------------------------------
  /// Whether KYC is enabled at all (master switch in admin panel).
  bool get isEnabled => _settings.isEnabled;

  /// Whether withdrawal is blocked until KYC is approved.
  bool get blockWithdrawal => _settings.blockWithdrawal;

  /// Whether liveness is required globally by the admin panel.
  bool get livenessRequired => _settings.livenessRequired;

  /// Whether liveness is required for a given [level].
  /// Combines the global switch with the level-specific flag.
  bool isLivenessRequiredFor(KycLevelConfig? level) =>
      _settings.livenessRequired && (level?.requireLiveness ?? true);

  /// Whether the current user is fully KYC verified.
  bool get isVerified => _status.isVerified;

  /// The user's current approved KYC level (0 = none).
  int get kycLevel => _status.kycLevel;

  /// The user's current KYC status string.
  String get kycStatus => _status.kycStatus;

  /// Active levels sorted ascending (only those the admin has marked active).
  List<KycLevelConfig> get activeLevels =>
      _settings.levels.where((l) => l.isActive).toList()..sort((a, b) => a.level.compareTo(b.level));

  /// The next level the user can apply for, or null if maxed out.
  KycLevelConfig? get nextLevel {
    final active = activeLevels;
    if (active.isEmpty) return null;
    for (final l in active) {
      if (l.level > _status.kycLevel) return l;
    }
    return null;
  }

  /// The level the user is currently verified at (or null if unverified).
  KycLevelConfig? get currentLevel => _settings.level(_status.kycLevel);

  // ---- Loading -----------------------------------------------------------

  /// Load KYC settings + the user's status in one go. Call after login and
  /// whenever the user opens the KYC / wallet screens.
  Future<void> load(String userId) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        ApiService.getKycSettings(userId: userId),
        ApiService.getKycStatus(userId: userId),
        ApiService.getKycAiConfig(),
      ]);
      _settings = results[0] as KycSettings;
      _status = results[1] as KycUserStatus;
      _aiConfig = results[2] as KycAiConfig;
      Log.d(_tag, 'KYC settings loaded: isEnabled=$isEnabled, '
          'blockWithdrawal=$blockWithdrawal, livenessRequired=$livenessRequired, '
          'levels=${_settings.levels.length}');
    } catch (e, s) {
      Log.e(_tag, 'load failed', e, s);
      _error = 'Failed to load KYC info';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Refresh only the user's status (lighter than [load]).
  Future<void> refreshStatus(String userId) async {
    try {
      _status = await ApiService.getKycStatus(userId: userId);
      notifyListeners();
    } catch (e, s) {
      Log.e(_tag, 'refreshStatus failed', e, s);
    }
  }

  /// Load the user's KYC submission history.
  Future<void> loadHistory(String userId) async {
    try {
      final res = await ApiService.getKycHistory(userId: userId, limit: 50);
      _history
        ..clear()
        ..addAll(res.history);
      notifyListeners();
    } catch (e, s) {
      Log.e(_tag, 'loadHistory failed', e, s);
    }
  }

  // ---- Withdrawal pre-check ---------------------------------------------

  /// Returns `true` if the user is allowed to withdraw right now.
  ///
  /// When KYC is disabled or `blockWithdrawal` is off, this is always `true`.
  /// Otherwise it asks the backend for the authoritative answer (which also
  /// enforces daily/monthly limits per KYC level).
  Future<KycWithdrawalCheck> canWithdraw(String userId) async {
    if (!isEnabled || !blockWithdrawal) {
      Log.d(_tag, 'canWithdraw allowed client-side: isEnabled=$isEnabled, blockWithdrawal=$blockWithdrawal');
      return KycWithdrawalCheck(status: true, canWithdraw: true);
    }
    try {
      return await ApiService.getKycWithdrawalCheck(userId: userId);
    } catch (e, s) {
      Log.e(_tag, 'canWithdraw failed', e, s);
      // On network error, fall back to local status check so the user is not
      // hard-blocked by a transient failure. The backend will re-check anyway.
      return KycWithdrawalCheck(
        status: true,
        canWithdraw: isVerified,
        reason: isVerified ? null : KycWithdrawalCheck.reasonKycRequired,
        message: isVerified ? null : 'Complete KYC verification to withdraw.',
        kycLevel: kycLevel,
      );
    }
  }

  // ---- Submit ------------------------------------------------------------

  /// Submit a KYC request for [level]. Returns `true` on success.
  ///
  /// [selfieFile] / [idFrontFile] / [idBackFile] are captured camera images.
  /// [extraDocuments] is a list of (key, file) pairs for level-required docs.
  /// [formFields] carries extra text fields (fullName, dob, idNumber, ...).
  /// [idCardType] is the selected government ID type (aadhaar, pan, dl, etc.).
  Future<bool> submit({
    required String userId,
    required int level,
    File? selfieFile,
    File? idFrontFile,
    File? idBackFile,
    List<KycDocumentUpload> extraDocuments = const [],
    Map<String, String> formFields = const {},
    String? idCardType,
  }) async {
    _submitting = true;
    _error = null;
    _lastRequestStatus = null;
    notifyListeners();
    try {
      // Log what we're submitting for debugging.
      Log.d(_tag, 'submit: userId=$userId, level=$level, '
          'selfie=${selfieFile?.path}, idFront=${idFrontFile?.path}, '
          'idBack=${idBackFile?.path}, extraDocs=${extraDocuments.length}, '
          'formFields=$formFields');
      // Verify files exist before uploading.
      if (selfieFile != null && !selfieFile.existsSync()) {
        _error = 'Selfie file not found. Please re-capture.';
        Log.e(_tag, 'submit: selfie file missing: ${selfieFile.path}');
        return false;
      }
      if (idFrontFile != null && !idFrontFile.existsSync()) {
        _error = 'ID front photo not found. Please re-capture.';
        Log.e(_tag, 'submit: idFront file missing: ${idFrontFile.path}');
        return false;
      }
      if (idBackFile != null && !idBackFile.existsSync()) {
        _error = 'ID back photo not found. Please re-capture.';
        Log.e(_tag, 'submit: idBack file missing: ${idBackFile.path}');
        return false;
      }

      final res = await ApiService.submitKyc(
        userId: userId,
        level: level,
        selfieFile: selfieFile,
        idFrontFile: idFrontFile,
        idBackFile: idBackFile,
        extraDocuments: extraDocuments,
        formFields: formFields,
        idCardType: idCardType,
      );
      Log.d(_tag, 'submit response: status=${res.status}, message=${res.message}, '
          'requestStatus=${res.requestStatus}, '
          'rejectionReason=${res.rejectionReason}');
      // Cache the request status so the UI can show an instant auto-verify
      // success vs. a "under review" pending state.
      _lastRequestStatus = res.requestStatus;
      if (res.status) {
        // Refresh status so the UI reflects the new (possibly auto-verified)
        // request state.
        await refreshStatus(userId);
        return true;
      }
      // Use the detailed rejection message if available (face_mismatch,
      // duplicate_id, duplicate_face, etc.).
      _error = res.rejectionMessage;
      return false;
    } on DioException catch (e, s) {
      Log.e(_tag, 'submit DioException: type=${e.type}, '
          'statusCode=${e.response?.statusCode}, '
          'response=${e.response?.data}', e, s);
      final code = e.response?.statusCode;
      // Try to extract the backend error message for more context.
      String? serverError;
      try {
        final data = e.response?.data;
        if (data is Map) {
          serverError = data['error']?.toString() ?? data['message']?.toString();
        }
      } catch (_) {}
      if (code == 404) {
        _error = 'KYC submission endpoint not found. Backend may not be ready.';
      } else if (code == 401 || code == 403) {
        _error = 'Authentication failed. Please login again.';
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        _error = 'Request timed out. Check your internet and try again.';
      } else if (e.type == DioExceptionType.connectionError) {
        _error = 'Network error. Check your internet connection.';
      } else if (code == 500) {
        _error = serverError != null
            ? 'Server error: $serverError. Please contact support if this persists.'
            : 'Server error (500). Please try again later.';
      } else {
        _error = serverError ?? 'Server error ($code). Please try again later.';
      }
      return false;
    } catch (e, s) {
      Log.e(_tag, 'submit failed', e, s);
      _error = 'Failed to submit KYC: $e';
      return false;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  /// Clear any cached error message.
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
