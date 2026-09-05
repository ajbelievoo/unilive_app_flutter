import 'dart:async';

import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' as fba;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

/// Ported from native `BindPhoneActivity.java`.
///
/// Binds a phone number to an existing logged-in account via Firebase OTP and
/// the `/user/bindAccount` endpoint.
class BindPhoneScreen extends StatefulWidget {
  const BindPhoneScreen({super.key});

  @override
  State<BindPhoneScreen> createState() => _BindPhoneScreenState();
}

class _BindPhoneScreenState extends State<BindPhoneScreen> {
  static const String _tag = 'BindPhone';

  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _auth = fba.FirebaseAuth.instance;

  Country _country = Country(
    phoneCode: '91',
    countryCode: 'IN',
    e164Sc: 0,
    geographic: true,
    level: 1,
    name: 'India',
    example: '9123456789',
    displayName: 'India (IN) [+91]',
    displayNameNoCountryCode: 'India',
    e164Key: '91-IN-0',
  );

  _Stage _stage = _Stage.phone;
  bool _loading = false;
  String _verificationId = '';
  String _fullPhone = '';
  int _resendSeconds = 0;
  int? _resendToken;
  Timer? _timer;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendSeconds = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _resendSeconds--);
      if (_resendSeconds <= 0) t.cancel();
    });
  }

  Future<bool> _isFirebaseReady() async {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      Fluttertoast.showToast(msg: 'Enter phone number');
      return;
    }
    if (!await _isFirebaseReady()) {
      Fluttertoast.showToast(msg: 'Firebase not configured. Add google-services.json to use mobile login.');
      return;
    }
    if (kDebugMode) {
      await _auth.setSettings(appVerificationDisabledForTesting: true);
    }
    _fullPhone = '+${_country.phoneCode}$phone';
    setState(() => _loading = true);

    await _auth.verifyPhoneNumber(
      phoneNumber: _fullPhone,
      timeout: const Duration(seconds: 60),
      forceResendingToken: _resendToken,
      verificationCompleted: (credential) async {
        await _verifyWithCredential(credential);
      },
      verificationFailed: (e) {
        if (!mounted) return;
        setState(() => _loading = false);
        Log.e(_tag, 'verifyPhoneNumber failed', e);
        Fluttertoast.showToast(msg: 'Verification failed: ${e.message}');
      },
      codeSent: (verificationId, resendToken) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _verificationId = verificationId;
          _resendToken = resendToken;
          _stage = _Stage.otp;
        });
        _startResendTimer();
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _verifyOtp() async {
    final code = _otpCtrl.text.trim();
    if (code.length < 6) {
      Fluttertoast.showToast(msg: 'Enter 6-digit OTP');
      return;
    }
    setState(() => _loading = true);
    try {
      final credential = fba.PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: code,
      );
      await _verifyWithCredential(credential);
    } on fba.FirebaseAuthException catch (e) {
      Log.e(_tag, 'OTP verify failed', e);
      Fluttertoast.showToast(msg: 'Invalid OTP: ${e.message}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyWithCredential(fba.PhoneAuthCredential credential) async {
    try {
      await _auth.signInWithCredential(credential);
      if (!mounted) return;
      final session = context.read<SessionManager>();
      final user = session.getUser();
      if (user == null) {
        Fluttertoast.showToast(msg: 'User not found');
        return;
      }
      final res = await ApiService.bindAccount({
        'userId': user.id,
        'mobileNumber': _fullPhone,
        'type': 'mobile',
      });
      if (res.status && res.user != null) {
        final updated = res.user!.copyWith(
          mobileNumber: _fullPhone,
          isPhoneBound: true,
        );
        if (!mounted) return;
        context.read<AuthProvider>().setUser(updated);
        Fluttertoast.showToast(msg: 'Phone number linked successfully');
        Navigator.pop(context);
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Failed to link phone');
      }
    } on fba.FirebaseAuthException catch (e) {
      Log.e(_tag, 'signInWithCredential failed', e);
      Fluttertoast.showToast(msg: 'Sign-in failed: ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bind Phone Number')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _stage == _Stage.phone ? _buildPhoneStep() : _buildOtpStep(),
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Enter your phone number', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 24),
        InkWell(
          onTap: () {
            showCountryPicker(
              context: context,
              showPhoneCode: true,
              onSelect: (c) => setState(() => _country = c),
            );
          },
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Country', border: OutlineInputBorder()),
            child: Text('${_country.flagEmoji}  ${_country.name} (+${_country.phoneCode})'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _loading ? null : _sendOtp,
          child: _loading
              ? const SizedBox(width: 22, height: 22, child: Preloader(strokeWidth: 2, color: Colors.white))
              : const Text('Get OTP'),
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Enter OTP sent to $_fullPhone', style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 24),
        Pinput(
          controller: _otpCtrl,
          length: 6,
          keyboardType: TextInputType.number,
          defaultPinTheme: const PinTheme(
            width: 48,
            height: 56,
            textStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            decoration: BoxDecoration(
              border: Border.fromBorderSide(BorderSide(color: Colors.grey)),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_resendSeconds > 0)
          Text('Resend in $_resendSeconds s', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey))
        else
          TextButton(onPressed: _sendOtp, child: const Text('Resend OTP')),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _loading ? null : _verifyOtp,
          child: _loading
              ? const SizedBox(width: 22, height: 22, child: Preloader(strokeWidth: 2, color: Colors.white))
              : const Text('Verify & Link'),
        ),
      ],
    );
  }
}

enum _Stage { phone, otp }
