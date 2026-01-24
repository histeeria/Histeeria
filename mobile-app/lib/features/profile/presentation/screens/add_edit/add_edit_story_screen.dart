import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/widgets/gradient_background.dart';
import '../../../../../../core/api/api_client.dart';
import '../../../../../../core/config/api_config.dart';
import '../../../../../../core/services/token_storage_service.dart';
import 'package:dio/dio.dart';
import '../../../../../../features/auth/data/providers/auth_provider.dart';

class AddEditStoryScreen extends StatefulWidget {
  final String? initialStory;

  const AddEditStoryScreen({super.key, this.initialStory});

  @override
  State<AddEditStoryScreen> createState() => _AddEditStoryScreenState();
}

class _AddEditStoryScreenState extends State<AddEditStoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storyController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _storyController.text = widget.initialStory ?? '';
  }

  @override
  void dispose() {
    _storyController.dispose();
    super.dispose();
  }

  Future<void> _saveStory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser;
      if (user == null) return;

      final story = _storyController.text.trim();

      // Get token manually and add to headers
      final tokenStorage = TokenStorageService();
      final token = await tokenStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please log in again. Your session has expired.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Call API with authorization header
      final apiClient = ApiClient();
      final response = await apiClient.patch<Map<String, dynamic>>(
        '/account/profile/story',
        data: {'story': story.isEmpty ? null : story},
        options: Options(
          headers: {
            ApiConfig.authorizationHeader: '${ApiConfig.bearerPrefix}$token',
          },
        ),
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response['success'] == true) {
        // Refresh user data immediately
        await authProvider.refreshUser();

        if (mounted) {
          context.pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['message']?.toString() ?? 'Failed to update story',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Your Story',
            style: AppTextStyles.headlineMedium(weight: FontWeight.bold),
          ),
          actions: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              TextButton(
                onPressed: _saveStory,
                child: Text(
                  'Save',
                  style: AppTextStyles.bodyMedium(
                    color: AppColors.accentPrimary,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tell your story (up to 1000 characters)',
                    style: AppTextStyles.bodySmall(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _storyController,
                      maxLines: null,
                      expands: true,
                      maxLength: 1000,
                      style: AppTextStyles.bodyMedium(),
                      decoration: InputDecoration(
                        hintText:
                            'Share your story, background, or anything you\'d like others to know...',
                        hintStyle: AppTextStyles.bodyMedium(
                          color: AppColors.textTertiary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.glassBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.glassBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.accentPrimary,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: AppColors.surface.withOpacity(0.3),
                        contentPadding: const EdgeInsets.all(16),
                        counterStyle: AppTextStyles.bodySmall(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      validator: (value) {
                        if (value != null && value.length > 1000) {
                          return 'Story must be 1000 characters or less';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${_storyController.text.length}/1000',
                    style: AppTextStyles.bodySmall(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
