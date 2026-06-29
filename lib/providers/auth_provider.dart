import 'dart:math';

import 'package:flutter/material.dart';
import 'package:ride_app_mock/core/errors/app_exception.dart';
import 'package:ride_app_mock/core/network/api_client.dart';
import 'package:ride_app_mock/core/constants/app_constants.dart';

enum AuthStatus { idle, loading, otpSent, error }

class AuthProvider with ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────

  AuthStatus _status = AuthStatus.idle;
  AppException? _exception;
  String _phoneNumber = '';
  String _receivedOtp = '';
  bool _isVerifying = false;
  bool _hasOtpError = false;
  String? _localOtp;

  // ── Getters ────────────────────────────────────────────────────────────────

  AuthStatus get status => _status;
  AppException? get exception => _exception;
  String get phoneNumber => _phoneNumber;
  String get receivedOtp => _receivedOtp;
  bool get isVerifying => _isVerifying;
  bool get hasOtpError => _hasOtpError;

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _makeOtp() => (1000 + Random().nextInt(9000)).toString();

  // ── Send OTP ───────────────────────────────────────────────────────────────

  Future<void> sendOtp(String phone) async {
    _status = AuthStatus.loading;
    _exception = null;
    _phoneNumber = phone;
    notifyListeners();

    try {
      final data = await ApiClient.post(
        '${AppConstants.serverUrl}/api/otp/send',
        body: {'phone': phone},
      );

      if (data['success'] == true) {
        _receivedOtp = data['otp'] as String;
        _localOtp = null;
        _status = AuthStatus.otpSent;
        notifyListeners();
        return;
      }

      // Server returned 200 but success=false — treat as a server error.
      throw ServerException(
        data['message'] as String? ?? 'Failed to send OTP.',
        statusCode: 200,
      );
    } on AppException catch (e) {
      debugPrint('[Auth] sendOtp error: $e');
      // Fall through to local OTP generation on network/timeout issues.
      if (e is NetworkException || e is TimeoutException) {
        _useFallbackOtp();
        return;
      }
      _exception = e;
      _status = AuthStatus.error;
      notifyListeners();
      return;
    }
  }

  void _useFallbackOtp() async {
    await Future.delayed(const Duration(seconds: 2));
    _localOtp = _makeOtp();
    _receivedOtp = _localOtp!;
    debugPrint('[Auth] Fallback OTP: $_receivedOtp');
    _status = AuthStatus.otpSent;
    notifyListeners();
  }

  // ── Verify OTP ─────────────────────────────────────────────────────────────

  Future<bool> verifyOtp(String otp) async {
    _isVerifying = true;
    _hasOtpError = false;
    notifyListeners();

    bool success;

    if (_localOtp != null) {
      await Future.delayed(const Duration(milliseconds: 800));
      success = otp == _localOtp;
    } else {
      try {
        final data = await ApiClient.post(
          '${AppConstants.serverUrl}/api/otp/verify',
          body: {'phone': _phoneNumber, 'otp': otp},
        );
        success = data['success'] == true;
      } on AppException catch (e) {
        debugPrint('[Auth] verifyOtp error: $e');
        success = false;
      }
    }

    _isVerifying = false;
    if (!success) _hasOtpError = true;
    notifyListeners();
    return success;
  }

  void clearOtpError() {
    _hasOtpError = false;
    notifyListeners();
  }

  void reset() {
    _status = AuthStatus.idle;
    _exception = null;
    _phoneNumber = '';
    _receivedOtp = '';
    _localOtp = null;
    _isVerifying = false;
    _hasOtpError = false;
    notifyListeners();
  }
}
