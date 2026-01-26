import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../data/providers/signup_state_provider.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _bioController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _profileImage;

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  void _handleNext() {
    // Store bio and profile picture in signup state
    final signupProvider = context.read<SignupStateProvider>();
    if (_bioController.text.isNotEmpty) {
      signupProvider.setBio(_bioController.text.trim());
    }
    if (_profileImage != null) {
      signupProvider.setProfilePicture(_profileImage);
    }
    context.push('/password-setup');
  }

  void _handleSkip() {
    // Bio and picture are optional, skip is fine
    context.push('/password-setup');
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      colors: AppColors.gradientWarm,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => context.pop(),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text(
                  'Complete your profile',
                  style: AppTextStyles.displayMedium(),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add a profile picture and tell us a bit about yourself. (Optional)',
                  style: AppTextStyles.bodyLarge(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 40),
                // Profile picture
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.glassBorder.withOpacity(0.3),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(60),
                      ),
                      child: _profileImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(58),
                              child: Image.file(
                                _profileImage!,
                                fit: BoxFit.cover,
                                width: 120,
                                height: 120,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo,
                                  size: 40,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add photo',
                                  style: AppTextStyles.bodySmall(),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // Bio
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bio', style: AppTextStyles.labelLarge()),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _bioController,
                      maxLines: 4,
                      maxLength: 200,
                      style: AppTextStyles.bodyLarge(),
                      decoration: InputDecoration(
                        hintText: 'Tell us about yourself...',
                        hintStyle: AppTextStyles.bodyMedium(),
                        filled: true,
                        fillColor: Colors.transparent,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.glassBorder.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.accentPrimary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Navigation buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.pop(),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.glassBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text('Back', style: AppTextStyles.labelLarge()),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextButton(
                        onPressed: _handleSkip,
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          'Skip',
                          style: AppTextStyles.labelLarge(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _handleNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        child: Text(
                          'Next',
                          style: AppTextStyles.labelLarge(
                            color: AppColors.textPrimary,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
