import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/gradient_background.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  
  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isOtpSent = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    // Validate current password
    if (_currentPasswordController.text.isEmpty) {
      _showMessage('Please enter your current password');
      return;
    }

    // Validate new password
    if (_newPasswordController.text.isEmpty) {
      _showMessage('Please enter a new password');
      return;
    }

    if (_newPasswordController.text.length < 8) {
      _showMessage('Password must be at least 8 characters');
      return;
    }

    if (!_isStrongPassword(_newPasswordController.text)) {
      _showMessage('Password must contain uppercase, lowercase, number, and special character');
      return;
    }

    // Validate confirm password
    if (_confirmPasswordController.text != _newPasswordController.text) {
      _showMessage('Passwords do not match');
      return;
    }

    if (_currentPasswordController.text == _newPasswordController.text) {
      _showMessage('New password must be different from current password');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulate API call to verify current password and send OTP
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isLoading = false;
      _isOtpSent = true;
    });

    _showMessage('OTP sent to your email');
  }

  Future<void> _verifyAndChange() async {
    if (_otpController.text.isEmpty) {
      _showMessage('Please enter the OTP');
      return;
    }

    if (_otpController.text.length != 6) {
      _showMessage('OTP must be 6 digits');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isLoading = false;
    });

    _showMessage('Password changed successfully!');
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) Navigator.pop(context);
  }

  bool _isStrongPassword(String password) {
    // Check for uppercase, lowercase, number, and special character
    return password.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password) &&
        RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: AppColors.backgroundSecondary.withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      colors: AppColors.gradientWarm,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(
                        Icons.arrow_back,
                        color: AppColors.textPrimary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Change Password',
                      style: AppTextStyles.headlineMedium(
                        weight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Current Password
                    Text(
                      'Current Password',
                      style: AppTextStyles.bodySmall(
                        color: AppColors.textSecondary,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _currentPasswordController,
                      obscureText: !_isCurrentPasswordVisible,
                      enabled: !_isOtpSent,
                      style: AppTextStyles.bodyMedium(),
                      decoration: InputDecoration(
                        hintText: 'Enter current password',
                        hintStyle: AppTextStyles.bodyMedium(
                          color: AppColors.textTertiary,
                        ),
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: AppColors.textSecondary,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isCurrentPasswordVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              _isCurrentPasswordVisible = !_isCurrentPasswordVisible;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: AppColors.backgroundSecondary.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.glassBorder.withOpacity(0.2),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.glassBorder.withOpacity(0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.accentPrimary,
                            width: 1.5,
                          ),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.glassBorder.withOpacity(0.1),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // New Password
                    Text(
                      'New Password',
                      style: AppTextStyles.bodySmall(
                        color: AppColors.textSecondary,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: !_isNewPasswordVisible,
                      enabled: !_isOtpSent,
                      style: AppTextStyles.bodyMedium(),
                      decoration: InputDecoration(
                        hintText: 'Enter new password',
                        hintStyle: AppTextStyles.bodyMedium(
                          color: AppColors.textTertiary,
                        ),
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: AppColors.textSecondary,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isNewPasswordVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              _isNewPasswordVisible = !_isNewPasswordVisible;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: AppColors.backgroundSecondary.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.glassBorder.withOpacity(0.2),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.glassBorder.withOpacity(0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.accentPrimary,
                            width: 1.5,
                          ),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.glassBorder.withOpacity(0.1),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Confirm Password
                    Text(
                      'Confirm New Password',
                      style: AppTextStyles.bodySmall(
                        color: AppColors.textSecondary,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: !_isConfirmPasswordVisible,
                      enabled: !_isOtpSent,
                      style: AppTextStyles.bodyMedium(),
                      decoration: InputDecoration(
                        hintText: 'Confirm new password',
                        hintStyle: AppTextStyles.bodyMedium(
                          color: AppColors.textTertiary,
                        ),
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: AppColors.textSecondary,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isConfirmPasswordVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: AppColors.backgroundSecondary.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.glassBorder.withOpacity(0.2),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.glassBorder.withOpacity(0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.accentPrimary,
                            width: 1.5,
                          ),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.glassBorder.withOpacity(0.1),
                          ),
                        ),
                      ),
                    ),
                    
                    if (_isOtpSent) ...[
                      const SizedBox(height: 24),
                      // OTP Field
                      Text(
                        'Verification Code',
                        style: AppTextStyles.bodySmall(
                          color: AppColors.textSecondary,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: AppTextStyles.bodyLarge(
                          weight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '000000',
                          hintStyle: AppTextStyles.bodyLarge(
                            color: AppColors.textTertiary,
                          ),
                          counterText: '',
                          filled: true,
                          fillColor: AppColors.backgroundSecondary.withOpacity(0.3),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.glassBorder.withOpacity(0.2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.glassBorder.withOpacity(0.2),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.accentPrimary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: _isLoading ? null : _sendOtp,
                          child: Text(
                            'Resend Code',
                            style: AppTextStyles.bodyMedium(
                              color: AppColors.accentPrimary,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    // Password Requirements
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Password Requirements:',
                            style: AppTextStyles.bodySmall(
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _PasswordRequirement(
                            text: 'At least 8 characters',
                            isMet: _newPasswordController.text.length >= 8,
                          ),
                          _PasswordRequirement(
                            text: 'Contains uppercase letter',
                            isMet: RegExp(r'[A-Z]').hasMatch(_newPasswordController.text),
                          ),
                          _PasswordRequirement(
                            text: 'Contains lowercase letter',
                            isMet: RegExp(r'[a-z]').hasMatch(_newPasswordController.text),
                          ),
                          _PasswordRequirement(
                            text: 'Contains number',
                            isMet: RegExp(r'[0-9]').hasMatch(_newPasswordController.text),
                          ),
                          _PasswordRequirement(
                            text: 'Contains special character',
                            isMet: RegExp(r'[!@#$%^&*(),.?":{}|<>]')
                                .hasMatch(_newPasswordController.text),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Info Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.accentPrimary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.accentPrimary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _isOtpSent
                                  ? 'Enter the 6-digit code sent to your email to confirm the password change.'
                                  : 'For security, we\'ll send a verification code to your email before changing your password.',
                              style: AppTextStyles.bodySmall(
                                color: AppColors.accentPrimary,
                              ).copyWith(height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : (_isOtpSent ? _verifyAndChange : _sendOtp),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentPrimary,
                          disabledBackgroundColor:
                              AppColors.textTertiary.withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                _isOtpSent ? 'Verify & Change Password' : 'Send Verification Code',
                                style: AppTextStyles.bodyLarge(
                                  color: Colors.white,
                                  weight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordRequirement extends StatelessWidget {
  final String text;
  final bool isMet;

  const _PasswordRequirement({
    required this.text,
    required this.isMet,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            color: isMet ? AppColors.success : AppColors.textTertiary,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: AppTextStyles.bodySmall(
              color: isMet ? AppColors.success : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

