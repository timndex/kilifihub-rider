import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';
import 'otp_verification_screen.dart';

/// Login screen - rider enters phone number to receive OTP
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: AppConfig.ANIM_SLOW),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();

    // Load saved phone number
    _loadSavedPhone();
  }

  Future<void> _loadSavedPhone() async {
    // If rider previously logged in, pre-fill phone
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.rider?.phone != null) {
      _phoneController.text = auth.rider!.phone;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();

    final auth = Provider.of<AuthService>(context, listen: false);
    final success = await auth.sendOtp(phone);

    if (!mounted) return;

    if (success) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              OtpVerificationScreen(phone: phone),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: AppConfig.ANIM_NORMAL),
        ),
      );
    } else {
      _showErrorSnackBar(auth.error ?? 'Failed to send OTP');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(AppConfig.ERROR_COLOR),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConfig.SPACING_LG),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),

                // Logo & App Name
                _buildHeader(),

                const SizedBox(height: 48),

                // Welcome Text
                Text(
                  'Welcome Back, Rider!',
                  style: TextStyle(
                    fontSize: AppConfig.FONT_SIZE_XXLARGE,
                    fontWeight: FontWeight.bold,
                    color: const Color(AppConfig.TEXT_PRIMARY),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your phone number to receive a verification code',
                  style: TextStyle(
                    fontSize: AppConfig.FONT_SIZE_MEDIUM,
                    color: const Color(AppConfig.TEXT_SECONDARY),
                  ),
                ),

                const SizedBox(height: 32),

                // Phone Input Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Phone field
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        autofocus: true,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          hintText: '0712345678',
                          prefixIcon: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            child: Text(
                              '+254',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(AppConfig.TEXT_PRIMARY),
                              ),
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 60),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
                            borderSide: const BorderSide(
                              color: Color(AppConfig.DIVIDER_COLOR),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
                            borderSide: const BorderSide(
                              color: Color(AppConfig.DIVIDER_COLOR),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
                            borderSide: const BorderSide(
                              color: Color(AppConfig.PRIMARY_COLOR),
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: const Color(AppConfig.BACKGROUND_COLOR),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your phone number';
                          }
                          final phone = value.trim();
                          if (phone.length < 9 || phone.length > 13) {
                            return 'Please enter a valid phone number';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Send OTP Button
                Consumer<AuthService>(
                  builder: (context, auth, child) {
                    return SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : _sendOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(AppConfig.PRIMARY_COLOR),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
                          ),
                          elevation: 2,
                        ),
                        child: auth.isLoading
                            ? const SpinKitThreeBounce(
                                color: Colors.white,
                                size: 20,
                              )
                            : const Text(
                                'Send Verification Code',
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

                // Error message
                Consumer<AuthService>(
                  builder: (context, auth, child) {
                    if (auth.error != null) {
                      return Container(
                        padding: const EdgeInsets.all(AppConfig.SPACING_MD),
                        decoration: BoxDecoration(
                          color: const Color(AppConfig.ERROR_COLOR).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Color(AppConfig.ERROR_COLOR),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                auth.error!,
                                style: const TextStyle(
                                  color: Color(AppConfig.ERROR_COLOR),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                const SizedBox(height: 32),

                // Help text
                Text(
                  'By continuing, you agree to our Terms of Service and Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppConfig.FONT_SIZE_SMALL,
                    color: const Color(AppConfig.TEXT_HINT),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // App Icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(AppConfig.PRIMARY_COLOR).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.delivery_dining,
            size: 44,
            color: Color(AppConfig.PRIMARY_COLOR),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          AppConfig.APP_NAME,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(AppConfig.PRIMARY_COLOR),
          ),
        ),
      ],
    );
  }
}
