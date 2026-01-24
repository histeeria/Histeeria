import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/widgets/gradient_background.dart';
import '../../../data/providers/profile_provider.dart';
import '../../../data/models/certification.dart';

class AddEditCertificationScreen extends StatefulWidget {
  final Certification? certification;

  const AddEditCertificationScreen({super.key, this.certification});

  @override
  State<AddEditCertificationScreen> createState() =>
      _AddEditCertificationScreenState();
}

class _AddEditCertificationScreenState
    extends State<AddEditCertificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _issuingOrgController = TextEditingController();
  final _credentialIdController = TextEditingController();
  final _credentialUrlController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _issueDate;
  DateTime? _expirationDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.certification != null) {
      final cert = widget.certification!;
      _nameController.text = cert.name;
      _issuingOrgController.text = cert.issuingOrganization ?? '';
      _credentialIdController.text = cert.credentialId ?? '';
      _credentialUrlController.text = cert.credentialUrl ?? '';
      _descriptionController.text = cert.description ?? '';
      _issueDate = cert.issueDate;
      _expirationDate = cert.expirationDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _issuingOrgController.dispose();
    _credentialIdController.dispose();
    _credentialUrlController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isIssueDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isIssueDate
          ? (_issueDate ?? DateTime.now())
          : (_expirationDate ?? DateTime.now()),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isIssueDate) {
          _issueDate = picked;
        } else {
          _expirationDate = picked;
        }
      });
    }
  }

  Future<void> _saveCertification() async {
    if (!_formKey.currentState!.validate()) return;
    if (_issueDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Issue date is required')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final profileProvider = context.read<ProfileProvider>();
      final data = {
        'name': _nameController.text.trim(),
        'issue_date': DateFormat('yyyy-MM-dd').format(_issueDate!),
        if (_issuingOrgController.text.trim().isNotEmpty)
          'issuing_organization': _issuingOrgController.text.trim(),
        if (_expirationDate != null)
          'expiration_date': DateFormat('yyyy-MM-dd').format(_expirationDate!),
        if (_credentialIdController.text.trim().isNotEmpty)
          'credential_id': _credentialIdController.text.trim(),
        if (_credentialUrlController.text.trim().isNotEmpty)
          'credential_url': _credentialUrlController.text.trim(),
        if (_descriptionController.text.trim().isNotEmpty)
          'description': _descriptionController.text.trim(),
      };

      if (widget.certification != null) {
        await profileProvider.updateCertification(
          widget.certification!.id,
          data,
        );
      } else {
        await profileProvider.createCertification(data);
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
            widget.certification != null
                ? 'Edit Certification'
                : 'Add Certification',
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
                onPressed: _saveCertification,
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
                // Name
                _buildTextField(
                  label: 'Certification Name *',
                  controller: _nameController,
                  hint: 'e.g., AWS Certified Solutions Architect',
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 24),

                // Issuing Organization
                _buildTextField(
                  label: 'Issuing Organization',
                  controller: _issuingOrgController,
                  hint: 'e.g., Amazon Web Services',
                ),
                const SizedBox(height: 24),

                // Issue Date
                _buildDateField(
                  label: 'Issue Date *',
                  date: _issueDate,
                  onTap: () => _selectDate(context, true),
                  validator: () => _issueDate == null ? 'Required' : null,
                ),
                const SizedBox(height: 24),

                // Expiration Date
                _buildDateField(
                  label: 'Expiration Date',
                  date: _expirationDate,
                  onTap: () => _selectDate(context, false),
                ),
                const SizedBox(height: 24),

                // Credential ID
                _buildTextField(
                  label: 'Credential ID',
                  controller: _credentialIdController,
                  hint: 'e.g., ABC123456',
                ),
                const SizedBox(height: 24),

                // Credential URL
                _buildTextField(
                  label: 'Credential URL',
                  controller: _credentialUrlController,
                  hint: 'https://...',
                  keyboardType: TextInputType.url,
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
    TextInputType? keyboardType,
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
          keyboardType: keyboardType,
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
