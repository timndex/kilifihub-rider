import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

/// OTP Verification Screen - rider enters the 4-digit code sent to their phone
class OtpVerificationScreen extends StatefulWidget {
  final String phone;

  const OtpVerificationScreen({super.key, required this.phone});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _otpControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  int _resendTimer = 60;
  Timer? _timer;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();

    // Auto-focus first digit
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    _resendTimer = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _resendTimer--;
        if (_resendTimer <= 0) {
          timer.cancel();
        }
      });
    });
  }

  String get _otpCode {
    return _otpControllers.map((c) => c.text).join();
  }

  void _onOtpChanged(int index, String value) {
    if (value.length == 1 && index < 3) {
      // Move to next field
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      // Move to previous field on delete
      _focusNodes[index - 1].requestFocus();
    }

    // Auto-verify when all digits entered
    if (_otpCode.length == 4) {
      _verifyOtp();
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpCode.length != 4) return;

    final auth = Provider.of<AuthService>(context, listen: false);
    final success = await auth.verifyOtp(widget.phone, _otpCode);

    if (!mounted) return;

    if (success) {
      // Navigate to home screen, clear all previous routes
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
        (route) => false,
      );
    } else {
      _showErrorSnackBar(auth.error ?? 'Invalid OTP. Please try again.');
      // Clear OTP fields
      for (var controller in _otpControllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    }
  }

  Future<void> _resendOtp() async {
    if (_resendTimer > 0) return;

    setState(() => _isResending = true);

    final auth = Provider.of<AuthService>(context, listen: false);
    final success = await auth.sendOtp(widget.phone);

    if (!mounted) return;

    setState(() => _isResending = false);

    if (success) {
      _startResendTimer();
      _showSuccessSnackBar('New verification code sent!');
      // Clear OTP fields
      for (var controller in _otpControllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    } else {
      _showErrorSnackBar(auth.error ?? 'Failed to resend code');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(AppConfig.ERROR_COLOR),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(AppConfig.SUCCESS_COLOR),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(AppConfig.TEXT_PRIMARY)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConfig.SPACING_LG),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // Title
              const Text(
                'Verify Your Number',
                style: TextStyle(
                  fontSize: AppConfig.FONT_SIZE_XXLARGE,
                  fontWeight: FontWeight.bold,
                  color: Color(AppConfig.TEXT_PRIMARY),
                ),
              ),
              const SizedBox(height: 12),

              // Subtitle with phone number
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: AppConfig.FONT_SIZE_MEDIUM,
                    color: const Color(AppConfig.TEXT_SECONDARY),
                  ),
                  children: [
                    const TextSpan(text: 'Enter the 4-digit code sent to '),
                    TextSpan(
                      text: '+254 ${widget.phone}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(AppConfig.TEXT_PRIMARY),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // OTP Input Fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, (index) {
                  return SizedBox(
                    width: 64,
                    height: 64,
                    child: TextField(
                      controller: _otpControllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
                          borderSide: const BorderSide(
                            color: Color(AppConfig.DIVIDER_COLOR),
                            width: 2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
                          borderSide: const BorderSide(
                            color: Color(AppConfig.PRIMARY_COLOR),
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
                          borderSide: const BorderSide(
                            color: Color(AppConfig.ERROR_COLOR),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(AppConfig.BACKGROUND_COLOR),
                      ),
                      onChanged: (value) => _onOtpChanged(index, value),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 32),

              // Verify Button
              Consumer<AuthService>(
                builder: (context, auth, child) {
                  return SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : _verifyOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(AppConfig.PRIMARY_COLOR),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
                        ),
                      ),
                      child: auth.isLoading
                          ? const SpinKitThreeBounce(color: Colors.white, size: 20)
                          : const Text(
                              'Verify',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Resend OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive the code? ",
                    style: TextStyle(
                      fontSize: AppConfig.FONT_SIZE_MEDIUM,
                      color: const Color(AppConfig.TEXT_SECONDARY),
                    ),
                  ),
                  _isResending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _resendTimer > 0
                          ? Text(
                              'Resend in ${_resendTimer}s',
                              style: TextStyle(
                                fontSize: AppConfig.FONT_SIZE_MEDIUM,
                                color: const Color(AppConfig.TEXT_HINT),
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : GestureDetector(
                              onTap: _resendOtp,
                              child: const Text(
                                'Resend Code',
                                style: TextStyle(
                                  fontSize: AppConfig.FONT_SIZE_MEDIUM,
                                  color: Color(AppConfig.PRIMARY_COLOR),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
