import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/gradient_background.dart';

class ChangeUsernameScreen extends StatefulWidget {
  const ChangeUsernameScreen({super.key});

  @override
  State<ChangeUsernameScreen> createState() => _ChangeUsernameScreenState();
}

class _ChangeUsernameScreenState extends State<ChangeUsernameScreen> {
  final TextEditingController _usernameController = TextEditingController();
  bool _isLoading = false;
  bool _isChecking = false;
  bool? _isAvailable;
  String _currentUsername = '@johndoe';

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _checkAvailability() async {
    final username = _usernameController.text.trim();
    
    if (username.isEmpty) {
      setState(() {
        _isAvailable = null;
      });
      return;
    }

    if (username.length < 3) {
      setState(() {
        _isAvailable = false;
      });
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      setState(() {
        _isAvailable = false;
      });
      _showMessage('Username can only contain letters, numbers, and underscores');
      return;
    }

    if ('@$username' == _currentUsername) {
      setState(() {
        _isAvailable = false;
      });
      _showMessage('This is already your current username');
      return;
    }

    setState(() {
      _isChecking = true;
    });

    // Simulate API call to check availability
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isChecking = false;
      // Simulate: username is available if it doesn't contain "taken"
      _isAvailable = !username.toLowerCase().contains('taken');
    });
  }

  Future<void> _saveUsername() async {
    final username = _usernameController.text.trim();

    if (username.isEmpty) {
      _showMessage('Please enter a username');
      return;
    }

    if (_isAvailable != true) {
      _showMessage('Please choose an available username');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isLoading = false;
    });

    _showMessage('Username changed successfully!');
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) Navigator.pop(context);
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
                      'Change Username',
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
                    // Current Username
                    Text(
                      'Current Username',
                      style: AppTextStyles.bodySmall(
                        color: AppColors.textSecondary,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.alternate_email,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _currentUsername,
                            style: AppTextStyles.bodyMedium(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // New Username
                    Text(
                      'New Username',
                      style: AppTextStyles.bodySmall(
                        color: AppColors.textSecondary,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _usernameController,
                      onChanged: (value) {
                        // Debounce check
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (_usernameController.text == value) {
                            _checkAvailability();
                          }
                        });
                      },
                      style: AppTextStyles.bodyMedium(),
                      decoration: InputDecoration(
                        hintText: 'Enter new username',
                        hintStyle: AppTextStyles.bodyMedium(
                          color: AppColors.textTertiary,
                        ),
                        prefixIcon: Icon(
                          Icons.alternate_email,
                          color: AppColors.textSecondary,
                        ),
                        suffixIcon: _isChecking
                            ? Padding(
                                padding: const EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.accentPrimary,
                                    ),
                                  ),
                                ),
                              )
                            : _isAvailable != null
                                ? Icon(
                                    _isAvailable!
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: _isAvailable!
                                        ? AppColors.success
                                        : AppColors.accentQuaternary,
                                  )
                                : null,
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
                    
                    if (_isAvailable == true) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '@${_usernameController.text} is available',
                            style: AppTextStyles.bodySmall(
                              color: AppColors.success,
                              weight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                    
                    if (_isAvailable == false && _usernameController.text.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.cancel,
                            color: AppColors.accentQuaternary,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Username not available',
                            style: AppTextStyles.bodySmall(
                              color: AppColors.accentQuaternary,
                              weight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    // Username Rules
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
                            'Username Requirements:',
                            style: AppTextStyles.bodySmall(
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _RuleItem(text: 'At least 3 characters'),
                          _RuleItem(text: 'Only letters, numbers, and underscores'),
                          _RuleItem(text: 'No spaces or special characters'),
                          _RuleItem(text: 'Must be unique'),
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
                              'Changing your username will update your profile URL. Your old username may become available to others.',
                              style: AppTextStyles.bodySmall(
                                color: AppColors.accentPrimary,
                              ).copyWith(height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isLoading || _isAvailable != true)
                            ? null
                            : _saveUsername,
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
                                'Save Changes',
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

class _RuleItem extends StatelessWidget {
  final String text;

  const _RuleItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: AppColors.accentPrimary,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: AppTextStyles.bodySmall(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

