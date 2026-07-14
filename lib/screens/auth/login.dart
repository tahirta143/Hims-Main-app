import 'package:flutter/material.dart';
import 'package:hims_app/core/providers/permission_provider.dart';
import 'package:hims_app/core/services/api_service.dart';
import 'package:hims_app/core/services/auth_storage_service.dart';
import 'package:hims_app/screens/auth/sign_up.dart';
import 'package:hims_app/screens/auth/mobile_login_screen.dart';
import 'package:hims_app/core/services/connectivity_service.dart';
import 'package:provider/provider.dart';
import '../main_shell.dart';
import '../../custum widgets/custom_loader.dart';


class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  final _apiService     = ApiService();
  final _storageService = AuthStorageService();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Sign In ──────────────────────────────────────────────────────────────
  Future<void> _signIn() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showSnackBar('Please enter username and password', isError: true);
      return;
    }

    if (!ConnectivityService().isOnline.value) {
      _showSnackBar('No internet connection. Please connect to continue.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Step 1: Login — get JWT token
      final loginResult = await _apiService.login(username, password);

      if (!loginResult.success) {
        _showSnackBar(loginResult.message ?? 'Login failed', isError: true);
        return;
      }

      // Step 2: Persist login data to secure storage
      await _storageService.saveLoginData(
        token:    loginResult.token!,
        userId:   loginResult.userId!,
        username: loginResult.username!,
        fullName: loginResult.fullName ?? '',
        role:     loginResult.role ?? 'staff',
        groups:   loginResult.groups,
      );

      // Step 3: Fetch & cache permissions
      if (!mounted) return;
      final permProvider = context.read<PermissionProvider>();
      await permProvider.syncFromServer();

      // Step 4: Navigate to Main Shell
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 14)),
        backgroundColor: isError ? Colors.red.shade600 : const Color(0xFF00B5AD),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
      ),
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B5AD)),
        ),
      ),
    );
  }

  Future<void> _handleForgotPassword() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      _showSnackBar('Please enter your username or email in the field below first.', isError: true);
      return;
    }

    _showLoadingDialog();

    try {
      final result = await _apiService.forgotPassword(username);
      if (!mounted) return;
      Navigator.of(context).pop(); // Dismiss loading dialog

      if (!result.success) {
        _showSnackBar(result.message, isError: true);
        return;
      }

      _showSnackBar(result.message);
      
      String maskedEmail = 'your email';
      final parts = result.message.split('email ');
      if (parts.length > 1) {
        maskedEmail = parts[1];
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _ForgotPasswordDialog(
          loginIdentifier: username,
          maskedEmail: maskedEmail,
          apiService: _apiService,
        ),
      );
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // Dismiss loading dialog
      _showSnackBar('An unexpected error occurred.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq        = MediaQuery.of(context);
    final screenW   = mq.size.width;
    final screenH   = mq.size.height;
    final hPad      = screenW * 0.07;
    final headerH   = screenH * 0.30;
    final logoSize  = screenW * 0.18;
    final titleFontSize  = screenW * 0.062;
    final inputFontSize  = screenW * 0.038;
    final btnFontSize    = screenW * 0.042;

    return Scaffold(
      backgroundColor: const Color(0xFF00B5AD),
      body: Column(
        children: [
          // ── Teal Header ─────────────────────────────────────────────────
          SizedBox(
            height: headerH,
            child: SafeArea(
              bottom: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: logoSize,
                      height: logoSize,
                      decoration: BoxDecoration(
                        // shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.20)
                      ),
                      child: Center(
                        child: Image.asset("assets/images/logo.png")
                      ),
                    ),
                    // SizedBox(height: screenH * 0.01),
                    Text(
                      'HIMS',
                      style: TextStyle(
                        fontSize: screenW * 0.055,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── White Body ───────────────────────────────────────────────────
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                    horizontal: hPad, vertical: screenH * 0.035),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: ConnectivityService().isOnline,
                      builder: (context, isOnline, _) {
                        if (isOnline) return const SizedBox.shrink();
                        return Container(
                          margin: EdgeInsets.only(bottom: screenH * 0.02),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.wifi_off_rounded, color: Colors.red.shade700, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'No internet connection',
                                  style: TextStyle(
                                    color: Colors.red.shade900,
                                    fontSize: inputFontSize * 0.9,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    // Title
                    Text(
                      'Sign in',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF00B5AD),
                      ),
                    ),
                    SizedBox(height: screenH * 0.025),

                    // Username Field
                    _InputField(
                      controller: _usernameController,
                      hint: 'Username',
                      prefixIcon: Icons.person_outline,
                      keyboardType: TextInputType.text,
                      fontSize: inputFontSize,
                    ),
                    SizedBox(height: screenH * 0.016),

                    // Password Field
                    _InputField(
                      controller: _passwordController,
                      hint: 'Password',
                      prefixIcon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      fontSize: inputFontSize,
                      suffixIcon: GestureDetector(
                        onTap: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                        child: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.grey,
                          size: screenW * 0.045,
                        ),
                      ),
                    ),
                    SizedBox(height: screenH * 0.010),

                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: _isLoading ? null : _handleForgotPassword,
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            fontSize: inputFontSize,
                            color: const Color(0xFF00B5AD),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: screenH * 0.028),

                    // Sign In Button
                    SizedBox(
                      height: screenH * 0.062,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00B5AD),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              const Color(0xFF00B5AD).withOpacity(0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const CustomLoader(size: 22, color: Colors.white)
                            : Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: btnFontSize,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    // SizedBox(height: screenH * 0.022),

                    // Don't have account
                    // Row(
                    //   mainAxisAlignment: MainAxisAlignment.center,
                    //   children: [
                    //     Text(
                    //       "Don't have account? ",
                    //       style: TextStyle(
                    //         fontSize: inputFontSize,
                    //         color: Colors.grey,
                    //       ),
                    //     ),
                    //     GestureDetector(
                    //       onTap: _handleSignUpNavigation,
                    //       child: Text(
                    //         'Sign up',
                    //         style: TextStyle(
                    //           fontSize: inputFontSize,
                    //           color: const Color(0xFF00B5AD),
                    //           fontWeight: FontWeight.w700,
                    //         ),
                    //       ),
                    //     ),
                    //   ],
                    // ),
                    SizedBox(height: screenH * 0.02),
                    
                    // Added: Mobile Login Entry Point
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const MobileLoginScreen()),
                          );
                        },
                        child: Text(
                          'Login as Patient or Doctor',
                          style: TextStyle(
                            fontSize: inputFontSize,
                            color: const Color(0xFF00B5AD),
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    // Bottom padding for iOS Home Indicator
                    SizedBox(height: mq.padding.bottom > 0 ? mq.padding.bottom : screenH * 0.02),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Forgot Password Dialog ─────────────────────────────────────────────────────
class _ForgotPasswordDialog extends StatefulWidget {
  final String loginIdentifier;
  final String maskedEmail;
  final ApiService apiService;

  const _ForgotPasswordDialog({
    required this.loginIdentifier,
    required this.maskedEmail,
    required this.apiService,
  });

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isForgotLoading = false;

  @override
  void dispose() {
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final otp = _otpController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (otp.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      _showError('All fields are required');
      return;
    }

    if (otp.length != 6) {
      _showError('Please enter a 6-digit OTP');
      return;
    }

    if (newPassword != confirmPassword) {
      _showError('Passwords do not match');
      return;
    }

    setState(() => _isForgotLoading = true);

    try {
      final result = await widget.apiService.resetPassword(
        loginIdentifier: widget.loginIdentifier,
        otp: otp,
        newPassword: newPassword,
      );

      if (!result.success) {
        _showError(result.message);
        return;
      }

      if (!mounted) return;
      
      // Success snackbar on top screen
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message, style: const TextStyle(fontSize: 14)),
          backgroundColor: const Color(0xFF00B5AD),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      
      Navigator.of(context).pop(); // Close dialog
    } finally {
      if (mounted) setState(() => _isForgotLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 14)),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFF00B5AD);
    final mq = MediaQuery.of(context);
    final screenW = mq.size.width;
    final inputFontSize = screenW * 0.038;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 16,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Reset Password',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: themeColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'An OTP has been sent to ${widget.maskedEmail}. Please enter it below.',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              
              // OTP field
              TextField(
                controller: _otpController,
                maxLength: 6,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18, 
                  letterSpacing: 8,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '000000',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    letterSpacing: 8,
                  ),
                  prefixIcon: const Icon(Icons.key, color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: themeColor, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // New Password Field
              _InputField(
                controller: _newPasswordController,
                hint: 'New Password',
                prefixIcon: Icons.lock_outline,
                obscureText: _obscureNewPassword,
                fontSize: inputFontSize,
                suffixIcon: GestureDetector(
                  onTap: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                  child: Icon(
                    _obscureNewPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey,
                    size: screenW * 0.045,
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // Confirm Password Field
              _InputField(
                controller: _confirmPasswordController,
                hint: 'Confirm Password',
                prefixIcon: Icons.lock_outline,
                obscureText: _obscureConfirmPassword,
                fontSize: inputFontSize,
                suffixIcon: GestureDetector(
                  onTap: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  child: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey,
                    size: screenW * 0.045,
                  ),
                ),
              ),
              const SizedBox(height: 25),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isForgotLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isForgotLoading ? null : _resetPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isForgotLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Reset Password'),
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

// ── Reusable Input Field ───────────────────────────────────────────────────────
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final double fontSize;
  final Widget? suffixIcon;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    required this.fontSize,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: fontSize),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: fontSize),
        prefixIcon:
            Icon(prefixIcon, color: Colors.grey.shade400, size: fontSize * 1.3),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF00B5AD), width: 1.5),
        ),
      ),
    );
  }
}

// ── Bandage Icon Painter ───────────────────────────────────────────────────────
class _BandagePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final dotPaint = Paint()
      ..color = const Color(0xFF1ABC9C)
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(45 * 3.14159265 / 180);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset.zero,
            width: size.width * 0.32,
            height: size.height * 0.82),
        Radius.circular(size.width * 0.16),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset.zero,
            width: size.width * 0.82,
            height: size.height * 0.32),
        Radius.circular(size.height * 0.16),
      ),
      paint,
    );
    canvas.restore();

    final r = size.width * 0.04;
    final o = size.width * 0.22;
    for (final pt in [
      Offset(cx - o, cy - o * 0.5),
      Offset(cx - o * 0.5, cy - o),
      Offset(cx + o, cy - o * 0.5),
      Offset(cx + o * 0.5, cy - o),
      Offset(cx - o, cy + o * 0.5),
      Offset(cx - o * 0.5, cy + o),
      Offset(cx + o, cy + o * 0.5),
      Offset(cx + o * 0.5, cy + o),
    ]) {
      canvas.drawCircle(pt, r, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}