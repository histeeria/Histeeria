import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/widgets/gradient_background.dart';
import '../../../data/providers/profile_provider.dart';
import '../../../data/models/experience.dart';

class AddEditExperienceScreen extends StatefulWidget {
  final Experience? experience;

  const AddEditExperienceScreen({super.key, this.experience});

  @override
  State<AddEditExperienceScreen> createState() =>
      _AddEditExperienceScreenState();
}

class _AddEditExperienceScreenState extends State<AddEditExperienceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String? _employmentType;
  bool _isCurrent = false;
  bool _isPublic = true;
  bool _isLoading = false;

  final List<String> _employmentTypes = [
    'full-time',
    'part-time',
    'contract',
    'internship',
    'freelance',
    'self-employed',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.experience != null) {
      final exp = widget.experience!;
      _companyController.text = exp.companyName;
      _titleController.text = exp.title;
      _descriptionController.text = exp.description ?? '';
      _startDate = exp.startDate;
      _endDate = exp.endDate;
      _employmentType = exp.employmentType;
      _isCurrent = exp.isCurrent;
      _isPublic = exp.isPublic;
    }
  }

  @override
  void dispose() {
    _companyController.dispose();
    _titleController.dispose();
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

  Future<void> _saveExperience() async {
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
        'company_name': _companyController.text.trim(),
        'title': _titleController.text.trim(),
        'start_date': DateFormat('yyyy-MM-dd').format(_startDate!),
        if (!_isCurrent && _endDate != null)
          'end_date': DateFormat('yyyy-MM-dd').format(_endDate!),
        'is_current': _isCurrent,
        'is_public': _isPublic,
        if (_employmentType != null) 'employment_type': _employmentType,
        if (_descriptionController.text.trim().isNotEmpty)
          'description': _descriptionController.text.trim(),
      };

      if (widget.experience != null) {
        await profileProvider.updateExperience(widget.experience!.id, data);
      } else {
        await profileProvider.createExperience(data);
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
            widget.experience != null ? 'Edit Experience' : 'Add Experience',
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
                onPressed: _saveExperience,
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
                // Company Name
                TextFormField(
                  controller: _companyController,
                  decoration: InputDecoration(
                    labelText: 'Company Name *',
                    hintText: 'Enter company name',
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
                      return 'Company name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Job Title
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Job Title *',
                    hintText: 'Enter job title',
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
                      return 'Job title is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Employment Type
                DropdownButtonFormField<String>(
                  value: _employmentType,
                  decoration: InputDecoration(
                    labelText: 'Employment Type',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.glassBorder),
                    ),
                    filled: true,
                    fillColor: AppColors.surface.withOpacity(0.3),
                  ),
                  items: _employmentTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.replaceAll('-', ' ').toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _employmentType = value;
                    });
                  },
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

                // Current Position Toggle
                SwitchListTile(
                  title: Text(
                    'I currently work here',
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
                    hintText: 'Describe your role and achievements...',
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

                // Public Visibility Toggle
                SwitchListTile(
                  title: Text(
                    'Make this experience public',
                    style: AppTextStyles.bodyMedium(),
                  ),
                  value: _isPublic,
                  onChanged: (value) {
                    setState(() {
                      _isPublic = value;
                    });
                  },
                  activeColor: AppColors.accentPrimary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
