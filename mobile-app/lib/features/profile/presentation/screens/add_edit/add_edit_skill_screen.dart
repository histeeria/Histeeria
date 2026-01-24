import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/widgets/gradient_background.dart';
import '../../../data/providers/profile_provider.dart';
import '../../../data/models/skill.dart';

class AddEditSkillScreen extends StatefulWidget {
  final Skill? skill;

  const AddEditSkillScreen({super.key, this.skill});

  @override
  State<AddEditSkillScreen> createState() => _AddEditSkillScreenState();
}

class _AddEditSkillScreenState extends State<AddEditSkillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _skillNameController = TextEditingController();
  String? _selectedProficiency;
  String? _selectedCategory;
  bool _isLoading = false;

  final List<String> _proficiencyLevels = [
    'beginner',
    'intermediate',
    'advanced',
    'expert',
  ];

  final List<String> _categories = ['technical', 'soft', 'language', 'other'];

  @override
  void initState() {
    super.initState();
    if (widget.skill != null) {
      _skillNameController.text = widget.skill!.skillName;
      _selectedProficiency = widget.skill!.proficiencyLevel;
      _selectedCategory = widget.skill!.category;
    }
  }

  @override
  void dispose() {
    _skillNameController.dispose();
    super.dispose();
  }

  Future<void> _saveSkill() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final profileProvider = context.read<ProfileProvider>();
      final data = {
        'skill_name': _skillNameController.text.trim(),
        if (_selectedProficiency != null)
          'proficiency_level': _selectedProficiency,
        if (_selectedCategory != null) 'category': _selectedCategory,
      };

      if (widget.skill != null) {
        await profileProvider.updateSkill(widget.skill!.id, data);
      } else {
        await profileProvider.createSkill(data);
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
            widget.skill != null ? 'Edit Skill' : 'Add Skill',
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
                onPressed: _saveSkill,
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
                // Skill Name
                Text(
                  'Skill Name',
                  style: AppTextStyles.bodySmall(
                    color: AppColors.textSecondary,
                    weight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _skillNameController,
                  style: AppTextStyles.bodyMedium(),
                  decoration: InputDecoration(
                    hintText: 'e.g., JavaScript, Leadership, Spanish',
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
                      return 'Skill name is required';
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
                const SizedBox(height: 24),

                // Category
                Text(
                  'Category',
                  style: AppTextStyles.bodySmall(
                    color: AppColors.textSecondary,
                    weight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    hintText: 'Select category',
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
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(
                        category[0].toUpperCase() + category.substring(1),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
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

