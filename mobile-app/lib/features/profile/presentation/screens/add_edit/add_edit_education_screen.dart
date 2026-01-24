import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/widgets/gradient_background.dart';
import '../../../data/providers/profile_provider.dart';
import '../../../data/models/education.dart';

class AddEditEducationScreen extends StatefulWidget {
  final Education? education;

  const AddEditEducationScreen({super.key, this.education});

  @override
  State<AddEditEducationScreen> createState() =>
      _AddEditEducationScreenState();
}

class _AddEditEducationScreenState extends State<AddEditEducationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _schoolController = TextEditingController();
  final _degreeController = TextEditingController();
  final _fieldOfStudyController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isCurrent = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.education != null) {
      final edu = widget.education!;
      _schoolController.text = edu.schoolName;
      _degreeController.text = edu.degree ?? '';
      _fieldOfStudyController.text = edu.fieldOfStudy ?? '';
      _descriptionController.text = edu.description ?? '';
      _startDate = edu.startDate;
      _endDate = edu.endDate;
      _isCurrent = edu.isCurrent;
    }
  }

  @override
  void dispose() {
    _schoolController.dispose();
    _degreeController.dispose();
    _fieldOfStudyController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now()),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _saveEducation() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start date is required')),
      );
      return;
    }
    if (!_isCurrent && _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date is required if not current')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final profileProvider = context.read<ProfileProvider>();
      final data = {
        'school_name': _schoolController.text.trim(),
        'start_date': DateFormat('yyyy-MM-dd').format(_startDate!),
        if (!_isCurrent && _endDate != null)
          'end_date': DateFormat('yyyy-MM-dd').format(_endDate!),
        'is_current': _isCurrent,
        if (_degreeController.text.trim().isNotEmpty)
          'degree': _degreeController.text.trim(),
        if (_fieldOfStudyController.text.trim().isNotEmpty)
          'field_of_study': _fieldOfStudyController.text.trim(),
        if (_descriptionController.text.trim().isNotEmpty)
          'description': _descriptionController.text.trim(),
      };

      if (widget.education != null) {
        await profileProvider.updateEducation(widget.education!.id, data);
      } else {
        await profileProvider.createEducation(data);
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
            widget.education != null ? 'Edit Education' : 'Add Education',
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
                onPressed: _saveEducation,
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
                // School Name
                TextFormField(
                  controller: _schoolController,
                  decoration: InputDecoration(
                    labelText: 'School Name *',
                    hintText: 'Enter school or university name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.glassBorder),
                    ),
                    filled: true,
                    fillColor: AppColors.surface.withOpacity(0.3),
                  ),
                  style: AppTextStyles.bodyMedium(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'School name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Degree
                TextFormField(
                  controller: _degreeController,
                  decoration: InputDecoration(
                    labelText: 'Degree',
                    hintText: 'e.g., Bachelor of Science, Master of Arts',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.glassBorder),
                    ),
                    filled: true,
                    fillColor: AppColors.surface.withOpacity(0.3),
                  ),
                  style: AppTextStyles.bodyMedium(),
                ),
                const SizedBox(height: 16),

                // Field of Study
                TextFormField(
                  controller: _fieldOfStudyController,
                  decoration: InputDecoration(
                    labelText: 'Field of Study',
                    hintText: 'e.g., Computer Science, Business Administration',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.glassBorder),
                    ),
                    filled: true,
                    fillColor: AppColors.surface.withOpacity(0.3),
                  ),
                  style: AppTextStyles.bodyMedium(),
                ),
                const SizedBox(height: 16),

                // Start Date
                InkWell(
                  onTap: () => _selectDate(context, true),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Start Date *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.glassBorder),
                      ),
                      filled: true,
                      fillColor: AppColors.surface.withOpacity(0.3),
                      suffixIcon: Icon(Icons.calendar_today, color: AppColors.textSecondary),
                    ),
                    child: Text(
                      _startDate != null
                          ? DateFormat('MMM yyyy').format(_startDate!)
                          : 'Select start date',
                      style: AppTextStyles.bodyMedium(
                        color: _startDate != null
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Current Education Toggle
                SwitchListTile(
                  title: Text(
                    'I am currently studying here',
                    style: AppTextStyles.bodyMedium(),
                  ),
                  value: _isCurrent,
                  onChanged: (value) {
                    setState(() {
                      _isCurrent = value;
                      if (value) {
                        _endDate = null;
                      }
                    });
                  },
                  activeColor: AppColors.accentPrimary,
                ),

                // End Date (only if not current)
                if (!_isCurrent) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _selectDate(context, false),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'End Date *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.glassBorder),
                        ),
                        filled: true,
                        fillColor: AppColors.surface.withOpacity(0.3),
                        suffixIcon: Icon(Icons.calendar_today, color: AppColors.textSecondary),
                      ),
                      child: Text(
                        _endDate != null
                            ? DateFormat('MMM yyyy').format(_endDate!)
                            : 'Select end date',
                        style: AppTextStyles.bodyMedium(
                          color: _endDate != null
                              ? AppColors.textPrimary
                              : AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  maxLength: 200,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText: 'Describe your achievements, activities, or coursework...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.glassBorder),
                    ),
                    filled: true,
                    fillColor: AppColors.surface.withOpacity(0.3),
                  ),
                  style: AppTextStyles.bodyMedium(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
