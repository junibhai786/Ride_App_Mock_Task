import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

enum AuthStatus { idle, loading, otpSent, error }

class AuthProvider with ChangeNotifier {
  AuthStatus _status = AuthStatus.idle;
  String? _errorMessage;
  String _phoneNumber = '';
  String _receivedOtp = '';

  bool _isVerifying = false;
  bool _hasOtpError = false;

  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String get phoneNumber => _phoneNumber;
  String get receivedOtp => _receivedOtp;
  bool get isVerifying => _isVerifying;
  bool get hasOtpError => _hasOtpError;

  static const String _baseUrl =
      'https://welcoming-mindfulness-production-539a.up.railway.app';

  // ── Local fallback ──────────────────────────────────────────────────────────
  // Used when the API server is unreachable (local dev / before Heroku deploy).
  String? _localOtp;

  String _makeOtp() =>
      (1000 + Random().nextInt(9000)).toString();

  // ── Send OTP ────────────────────────────────────────────────────────────────
  Future<void> sendOtp(String phone) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    _phoneNumber = phone;
    notifyListeners();

    if (_baseUrl.isNotEmpty) {
      final url = '$_baseUrl/api/otp/send';
      final body = jsonEncode({'phone': phone});
      debugPrint('[OTP] POST $url');
      debugPrint('[OTP] Request body: $body');
      try {
        final response = await http
            .post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(const Duration(seconds: 8));

        debugPrint('[OTP] Response status: ${response.statusCode}');
        debugPrint('[OTP] Response body: ${response.body}');

        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (response.statusCode == 200 && data['success'] == true) {
          _receivedOtp = data['otp'] as String;
          _localOtp = null;
          _status = AuthStatus.otpSent;
          notifyListeners();
          return;
        }
        _errorMessage = data['message'] as String?;
        debugPrint('[OTP] API error: $_errorMessage');
      } catch (e) {
        debugPrint('[OTP] Network error: $e — falling back to local OTP');
      }
    }

    // Local fallback
    await Future.delayed(const Duration(seconds: 2));
    _localOtp = _makeOtp();
    _receivedOtp = _localOtp!;
    debugPrint('[OTP] Local fallback OTP: $_receivedOtp');
    _status = AuthStatus.otpSent;
    notifyListeners();
  }

  // ── Verify OTP ──────────────────────────────────────────────────────────────
  Future<bool> verifyOtp(String otp) async {
    _isVerifying = true;
    _hasOtpError = false;
    notifyListeners();

    bool success = false;

    // If we have a local OTP, verify it locally
    if (_localOtp != null) {
      await Future.delayed(const Duration(milliseconds: 800));
      success = otp == _localOtp;
    } else {
      // Otherwise verify against the API
      final url = '$_baseUrl/api/otp/verify';
      final body = jsonEncode({'phone': _phoneNumber, 'otp': otp});
      debugPrint('[OTP] POST $url');
      debugPrint('[OTP] Request body: $body');
      try {
        final response = await http
            .post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(const Duration(seconds: 8));

        debugPrint('[OTP] Response status: ${response.statusCode}');
        debugPrint('[OTP] Response body: ${response.body}');

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        success = response.statusCode == 200 && data['success'] == true;
      } catch (e) {
        debugPrint('[OTP] Verify error: $e');
        success = false;
      }
    }

    _isVerifying = false;
    if (!success) {
      _hasOtpError = true;
    }
    notifyListeners();
    return success;
  }

  void clearOtpError() {
    _hasOtpError = false;
    notifyListeners();
  }

  void reset() {
    _status = AuthStatus.idle;
    _errorMessage = null;
    _phoneNumber = '';
    _receivedOtp = '';
    _localOtp = null;
    _isVerifying = false;
    _hasOtpError = false;
    notifyListeners();
  }
}
