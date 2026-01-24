import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/widgets/gradient_background.dart';
import '../../../data/providers/profile_provider.dart';
import '../../../data/models/publication.dart';

class AddEditPublicationScreen extends StatefulWidget {
  final Publication? publication;

  const AddEditPublicationScreen({super.key, this.publication});

  @override
  State<AddEditPublicationScreen> createState() =>
      _AddEditPublicationScreenState();
}

class _AddEditPublicationScreenState extends State<AddEditPublicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _publisherController = TextEditingController();
  final _urlController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _publicationType;
  DateTime? _publicationDate;
  bool _isLoading = false;

  final List<String> _publicationTypes = [
    'article',
    'book',
    'paper',
    'blog',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.publication != null) {
      final pub = widget.publication!;
      _titleController.text = pub.title;
      _publisherController.text = pub.publisher ?? '';
      _urlController.text = pub.publicationUrl ?? '';
      _descriptionController.text = pub.description ?? '';
      _publicationType = pub.publicationType;
      _publicationDate = pub.publicationDate;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _publisherController.dispose();
    _urlController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _publicationDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _publicationDate = picked;
      });
    }
  }

  Future<void> _savePublication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final profileProvider = context.read<ProfileProvider>();
      final data = {
        'title': _titleController.text.trim(),
        if (_publicationType != null) 'publication_type': _publicationType,
        if (_publisherController.text.trim().isNotEmpty)
          'publisher': _publisherController.text.trim(),
        if (_publicationDate != null)
          'publication_date': DateFormat(
            'yyyy-MM-dd',
          ).format(_publicationDate!),
        if (_urlController.text.trim().isNotEmpty)
          'publication_url': _urlController.text.trim(),
        if (_descriptionController.text.trim().isNotEmpty)
          'description': _descriptionController.text.trim(),
      };

      if (widget.publication != null) {
        await profileProvider.updatePublication(widget.publication!.id, data);
      } else {
        await profileProvider.createPublication(data);
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
            widget.publication != null ? 'Edit Publication' : 'Add Publication',
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
                onPressed: _savePublication,
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
                  hint: 'Publication title',
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 24),

                // Publication Type
                _buildDropdown(
                  label: 'Publication Type',
                  value: _publicationType,
                  items: _publicationTypes,
                  onChanged: (value) {
                    setState(() {
                      _publicationType = value;
                    });
                  },
                ),
                const SizedBox(height: 24),

                // Publisher
                _buildTextField(
                  label: 'Publisher',
                  controller: _publisherController,
                  hint: 'e.g., IEEE, ACM, Medium',
                ),
                const SizedBox(height: 24),

                // Publication Date
                _buildDateField(
                  label: 'Publication Date',
                  date: _publicationDate,
                  onTap: () => _selectDate(context),
                ),
                const SizedBox(height: 24),

                // URL
                _buildTextField(
                  label: 'Publication URL',
                  controller: _urlController,
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
