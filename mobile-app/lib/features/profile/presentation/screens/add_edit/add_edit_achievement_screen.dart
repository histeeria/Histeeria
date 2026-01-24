import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/widgets/gradient_background.dart';
import '../../../data/providers/profile_provider.dart';
import '../../../data/models/achievement.dart';

class AddEditAchievementScreen extends StatefulWidget {
  final Achievement? achievement;

  const AddEditAchievementScreen({super.key, this.achievement});

  @override
  State<AddEditAchievementScreen> createState() =>
      _AddEditAchievementScreenState();
}

class _AddEditAchievementScreenState extends State<AddEditAchievementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _orgController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _achievementType;
  DateTime? _achievementDate;
  bool _isLoading = false;

  final List<String> _achievementTypes = [
    'award',
    'recognition',
    'milestone',
    'certification',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.achievement != null) {
      final achievement = widget.achievement!;
      _titleController.text = achievement.title;
      _orgController.text = achievement.issuingOrganization ?? '';
      _descriptionController.text = achievement.description ?? '';
      _achievementType = achievement.achievementType;
      _achievementDate = achievement.achievementDate;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _orgController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _achievementDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _achievementDate = picked;
      });
    }
  }

  Future<void> _saveAchievement() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final profileProvider = context.read<ProfileProvider>();
      final data = {
        'title': _titleController.text.trim(),
        if (_achievementType != null) 'achievement_type': _achievementType,
        if (_orgController.text.trim().isNotEmpty)
          'issuing_organization': _orgController.text.trim(),
        if (_achievementDate != null)
          'achievement_date': DateFormat(
            'yyyy-MM-dd',
          ).format(_achievementDate!),
        if (_descriptionController.text.trim().isNotEmpty)
          'description': _descriptionController.text.trim(),
      };

      if (widget.achievement != null) {
        await profileProvider.updateAchievement(widget.achievement!.id, data);
      } else {
        await profileProvider.createAchievement(data);
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
            widget.achievement != null ? 'Edit Achievement' : 'Add Achievement',
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
                onPressed: _saveAchievement,
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
                // Title
                _buildTextField(
                  label: 'Title *',
                  controller: _titleController,
                  hint: 'e.g., Employee of the Year, Best Paper Award',
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 24),

                // Achievement Type
                _buildDropdown(
                  label: 'Achievement Type',
                  value: _achievementType,
                  items: _achievementTypes,
                  onChanged: (value) {
                    setState(() {
                      _achievementType = value;
                    });
                  },
                ),
                const SizedBox(height: 24),

                // Issuing Organization
                _buildTextField(
                  label: 'Issuing Organization',
                  controller: _orgController,
                  hint: 'e.g., Company Name, University',
                ),
                const SizedBox(height: 24),

                // Achievement Date
                _buildDateField(
                  label: 'Achievement Date',
                  date: _achievementDate,
                  onTap: () => _selectDate(context),
                ),
                const SizedBox(height: 24),

                // Description
                _buildTextField(
                  label: 'Description',
                  controller: _descriptionController,
                  hint: 'Brief description (max 200 characters)',
                  maxLines: 3,
                  maxLength: 200,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall(
            color: AppColors.textSecondary,
            weight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          style: AppTextStyles.bodyMedium(),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodyMedium(color: AppColors.textTertiary),
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
              borderSide: BorderSide(color: AppColors.accentPrimary, width: 2),
            ),
            filled: true,
            fillColor: AppColors.surface.withOpacity(0.3),
            contentPadding: const EdgeInsets.all(16),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall(
            color: AppColors.textSecondary,
            weight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            hintText: 'Select type',
            hintStyle: AppTextStyles.bodyMedium(color: AppColors.textTertiary),
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
              borderSide: BorderSide(color: AppColors.accentPrimary, width: 2),
            ),
            filled: true,
            fillColor: AppColors.surface.withOpacity(0.3),
            contentPadding: const EdgeInsets.all(16),
          ),
          dropdownColor: AppColors.surface,
          style: AppTextStyles.bodyMedium(),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item[0].toUpperCase() + item.substring(1)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall(
            color: AppColors.textSecondary,
            weight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    date != null
                        ? DateFormat('yyyy-MM-dd').format(date)
                        : 'Select date',
                    style: AppTextStyles.bodyMedium(
                      color: date != null
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

