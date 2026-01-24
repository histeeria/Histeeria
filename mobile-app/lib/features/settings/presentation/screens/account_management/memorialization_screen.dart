import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/gradient_background.dart';

class MemorializationScreen extends StatefulWidget {
  const MemorializationScreen({super.key});

  @override
  State<MemorializationScreen> createState() => _MemorializationScreenState();
}

class _MemorializationScreenState extends State<MemorializationScreen> {
  final TextEditingController _contactEmailController = TextEditingController();
  final TextEditingController _contactNameController = TextEditingController();
  bool _hasLegacyContact = false;
  bool _isLoading = false;
  String? _currentLegacyContact;

  @override
  void dispose() {
    _contactEmailController.dispose();
    _contactNameController.dispose();
    super.dispose();
  }

  Future<void> _saveLegacyContact() async {
    if (_contactNameController.text.isEmpty) {
      _showMessage('Please enter contact name');
      return;
    }

    if (_contactEmailController.text.isEmpty) {
      _showMessage('Please enter contact email');
      return;
    }

    if (!_isValidEmail(_contactEmailController.text)) {
      _showMessage('Please enter a valid email address');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isLoading = false;
      _hasLegacyContact = true;
      _currentLegacyContact = _contactNameController.text;
    });

    _showMessage('Legacy contact saved successfully');
  }

  Future<void> _removeLegacyContact() async {
    final confirm = await _showRemoveDialog();
    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isLoading = false;
      _hasLegacyContact = false;
      _currentLegacyContact = null;
      _contactNameController.clear();
      _contactEmailController.clear();
    });

    _showMessage('Legacy contact removed');
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Future<bool?> _showRemoveDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Remove Legacy Contact?',
          style: AppTextStyles.headlineSmall(weight: FontWeight.bold),
        ),
        content: Text(
          'Your legacy contact will no longer be able to manage your account if something happens to you.',
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium(color: AppColors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Remove',
              style: AppTextStyles.bodyMedium(
                color: AppColors.accentQuaternary,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
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
                    Expanded(
                      child: Text(
                        'Account Memorialization',
                        style: AppTextStyles.headlineMedium(
                          weight: FontWeight.bold,
                        ),
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
                            Icons.favorite_outline,
                            color: AppColors.accentPrimary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Choose someone to manage your account if something happens to you. They can memorialize or delete your account.',
                              style: AppTextStyles.bodySmall(
                                color: AppColors.accentPrimary,
                              ).copyWith(height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    if (_hasLegacyContact) ...[
                      // Current Legacy Contact
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.success.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: AppColors.success,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Legacy Contact Set',
                                  style: AppTextStyles.bodyMedium(
                                    color: AppColors.success,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _currentLegacyContact ?? 'Contact name',
                              style: AppTextStyles.bodyLarge(
                                weight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _contactEmailController.text,
                              style: AppTextStyles.bodySmall(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _removeLegacyContact,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  side: BorderSide(
                                    color: AppColors.accentQuaternary,
                                    width: 1,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Remove Legacy Contact',
                                  style: AppTextStyles.bodySmall(
                                    color: AppColors.accentQuaternary,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Add Legacy Contact Form
                      Text(
                        'Legacy Contact Name',
                        style: AppTextStyles.bodySmall(
                          color: AppColors.textSecondary,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _contactNameController,
                        style: AppTextStyles.bodyMedium(),
                        decoration: InputDecoration(
                          hintText: 'Enter contact name',
                          hintStyle: AppTextStyles.bodyMedium(
                            color: AppColors.textTertiary,
                          ),
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color: AppColors.textSecondary,
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
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      Text(
                        'Legacy Contact Email',
                        style: AppTextStyles.bodySmall(
                          color: AppColors.textSecondary,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _contactEmailController,
                        keyboardType: TextInputType.emailAddress,
                        style: AppTextStyles.bodyMedium(),
                        decoration: InputDecoration(
                          hintText: 'Enter contact email',
                          hintStyle: AppTextStyles.bodyMedium(
                            color: AppColors.textTertiary,
                          ),
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: AppColors.textSecondary,
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
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // What They Can Do
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
                              'What your legacy contact can do:',
                              style: AppTextStyles.bodySmall(
                                weight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _PermissionItem(text: 'Memorialize your account'),
                            _PermissionItem(text: 'Download your data'),
                            _PermissionItem(text: 'Change profile picture'),
                            _PermissionItem(text: 'Write a pinned post'),
                            const SizedBox(height: 12),
                            Text(
                              'What they cannot do:',
                              style: AppTextStyles.bodySmall(
                                weight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _PermissionItem(text: 'Login to your account', isRestricted: true),
                            _PermissionItem(text: 'Read your messages', isRestricted: true),
                            _PermissionItem(text: 'Remove friends', isRestricted: true),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveLegacyContact,
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
                                  'Save Legacy Contact',
                                  style: AppTextStyles.bodyLarge(
                                    color: Colors.white,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
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

class _PermissionItem extends StatelessWidget {
  final String text;
  final bool isRestricted;

  const _PermissionItem({
    required this.text,
    this.isRestricted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isRestricted ? Icons.cancel_outlined : Icons.check_circle_outline,
            color: isRestricted ? AppColors.accentQuaternary : AppColors.success,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

