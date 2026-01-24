import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/widgets/gradient_background.dart';
import '../../../data/providers/profile_provider.dart';
import '../../../data/models/language.dart';

class AddEditLanguageScreen extends StatefulWidget {
  final Language? language;

  const AddEditLanguageScreen({super.key, this.language});

  @override
  State<AddEditLanguageScreen> createState() => _AddEditLanguageScreenState();
}

class _AddEditLanguageScreenState extends State<AddEditLanguageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _languageNameController = TextEditingController();
  String? _selectedProficiency;
  bool _isLoading = false;

  final List<String> _proficiencyLevels = [
    'basic',
    'conversational',
    'fluent',
    'native',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.language != null) {
      _languageNameController.text = widget.language!.languageName;
      _selectedProficiency = widget.language!.proficiencyLevel;
    }
  }

  @override
  void dispose() {
    _languageNameController.dispose();
    super.dispose();
  }

  Future<void> _saveLanguage() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final profileProvider = context.read<ProfileProvider>();
      final data = {
        'language_name': _languageNameController.text.trim(),
        if (_selectedProficiency != null)
          'proficiency_level': _selectedProficiency,
      };

      if (widget.language != null) {
        await profileProvider.updateLanguage(widget.language!.id, data);
      } else {
        await profileProvider.createLanguage(data);
      }

      if (mounted) {
        context.pop();
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
            widget.language != null ? 'Edit Language' : 'Add Language',
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
                onPressed: _saveLanguage,
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
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Language Name
                Text(
                  'Language Name',
                  style: AppTextStyles.bodySmall(
                    color: AppColors.textSecondary,
                    weight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _languageNameController,
                  style: AppTextStyles.bodyMedium(),
                  decoration: InputDecoration(
                    hintText: 'e.g., English, Spanish, French',
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
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Language name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Proficiency Level
                Text(
                  'Proficiency Level',
                  style: AppTextStyles.bodySmall(
                    color: AppColors.textSecondary,
                    weight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedProficiency,
                  decoration: InputDecoration(
                    hintText: 'Select proficiency level',
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
                  ),
                  dropdownColor: AppColors.surface,
                  style: AppTextStyles.bodyMedium(),
                  items: _proficiencyLevels.map((level) {
                    return DropdownMenuItem(
                      value: level,
                      child: Text(level[0].toUpperCase() + level.substring(1)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedProficiency = value;
                    });
                  },
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

