import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/widgets/gradient_background.dart';
import '../../../data/providers/profile_provider.dart';
import '../../../data/models/interest.dart';

class AddEditInterestScreen extends StatefulWidget {
  final Interest? interest;

  const AddEditInterestScreen({super.key, this.interest});

  @override
  State<AddEditInterestScreen> createState() => _AddEditInterestScreenState();
}

class _AddEditInterestScreenState extends State<AddEditInterestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _interestNameController = TextEditingController();
  String? _selectedCategory;
  bool _isLoading = false;

  final List<String> _categories = [
    'hobby',
    'professional',
    'academic',
    'sports',
    'arts',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.interest != null) {
      _interestNameController.text = widget.interest!.interestName;
      _selectedCategory = widget.interest!.category;
    }
  }

  @override
  void dispose() {
    _interestNameController.dispose();
    super.dispose();
  }

  Future<void> _saveInterest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final profileProvider = context.read<ProfileProvider>();
      final data = {
        'interest_name': _interestNameController.text.trim(),
        if (_selectedCategory != null) 'category': _selectedCategory,
      };

      if (widget.interest != null) {
        await profileProvider.updateInterest(widget.interest!.id, data);
      } else {
        await profileProvider.createInterest(data);
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
            widget.interest != null ? 'Edit Interest' : 'Add Interest',
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
                onPressed: _saveInterest,
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
                // Interest Name
                Text(
                  'Interest Name',
                  style: AppTextStyles.bodySmall(
                    color: AppColors.textSecondary,
                    weight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _interestNameController,
                  style: AppTextStyles.bodyMedium(),
                  decoration: InputDecoration(
                    hintText: 'e.g., Photography, Reading, Traveling',
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
                      return 'Interest name is required';
                    }
                    return null;
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

