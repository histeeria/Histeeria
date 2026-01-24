import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/widgets/gradient_background.dart';
import '../../../data/providers/profile_provider.dart';
import '../../../data/models/volunteering.dart';

class AddEditVolunteeringScreen extends StatefulWidget {
  final Volunteering? volunteering;

  const AddEditVolunteeringScreen({super.key, this.volunteering});

  @override
  State<AddEditVolunteeringScreen> createState() =>
      _AddEditVolunteeringScreenState();
}

class _AddEditVolunteeringScreenState extends State<AddEditVolunteeringScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orgNameController = TextEditingController();
  final _roleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isCurrent = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.volunteering != null) {
      final vol = widget.volunteering!;
      _orgNameController.text = vol.organizationName;
      _roleController.text = vol.role;
      _descriptionController.text = vol.description ?? '';
      _startDate = vol.startDate;
      _endDate = vol.endDate;
      _isCurrent = vol.isCurrent;
    }
  }

  @override
  void dispose() {
    _orgNameController.dispose();
    _roleController.dispose();
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
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _saveVolunteering() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Start date is required')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final profileProvider = context.read<ProfileProvider>();
      final data = {
        'organization_name': _orgNameController.text.trim(),
        'role': _roleController.text.trim(),
        'start_date': DateFormat('yyyy-MM-dd').format(_startDate!),
        'is_current': _isCurrent,
        if (!_isCurrent && _endDate != null)
          'end_date': DateFormat('yyyy-MM-dd').format(_endDate!),
        if (_descriptionController.text.trim().isNotEmpty)
          'description': _descriptionController.text.trim(),
      };

      if (widget.volunteering != null) {
        await profileProvider.updateVolunteering(widget.volunteering!.id, data);
      } else {
        await profileProvider.createVolunteering(data);
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
            widget.volunteering != null
                ? 'Edit Volunteering'
                : 'Add Volunteering',
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
                onPressed: _saveVolunteering,
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
                // Organization Name
                _buildTextField(
                  label: 'Organization Name *',
                  controller: _orgNameController,
                  hint: 'e.g., Red Cross, Local Food Bank',
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 24),

                // Role
                _buildTextField(
                  label: 'Role *',
                  controller: _roleController,
                  hint: 'e.g., Volunteer Coordinator, Tutor',
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 24),

                // Start Date
                _buildDateField(
                  label: 'Start Date *',
                  date: _startDate,
                  onTap: () => _selectDate(context, true),
                  validator: () => _startDate == null ? 'Required' : null,
                ),
                const SizedBox(height: 24),

                // Is Current
                SwitchListTile(
                  title: Text(
                    'Currently volunteering here',
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
                const SizedBox(height: 24),

                // End Date (only if not current)
                if (!_isCurrent)
                  _buildDateField(
                    label: 'End Date',
                    date: _endDate,
                    onTap: () => _selectDate(context, false),
                  ),
                if (!_isCurrent) const SizedBox(height: 24),

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

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    String? Function()? validator,
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
        if (validator != null && validator() != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: Text(
              validator()!,
              style: AppTextStyles.bodySmall(color: AppColors.error),
            ),
          ),
      ],
    );
  }
}

