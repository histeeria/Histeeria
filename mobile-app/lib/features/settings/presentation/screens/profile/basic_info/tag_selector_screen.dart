import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/widgets/gradient_background.dart';

class TagSelectorScreen extends StatefulWidget {
  const TagSelectorScreen({super.key});

  @override
  State<TagSelectorScreen> createState() => _TagSelectorScreenState();
}

class _TagSelectorScreenState extends State<TagSelectorScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedTag = 'Founder';
  String _searchQuery = '';
  
  final List<String> _tags = [
    'Founder',
    'CEO',
    'CTO',
    'Developer',
    'Designer',
    'Student',
    'Entrepreneur',
    'Engineer',
    'Product Manager',
    'Marketing',
    'Sales',
    'Freelancer',
    'Consultant',
    'Investor',
    'Mentor',
    'Artist',
    'Writer',
    'Content Creator',
    'Influencer',
    'Photographer',
    'Videographer',
    'Musician',
    'Teacher',
    'Professor',
    'Researcher',
    'Scientist',
    'Doctor',
    'Lawyer',
    'Accountant',
    'Architect',
    'Chef',
    'Athlete',
    'Coach',
    'Trainer',
    'Analyst',
    'Strategist',
    'Director',
    'Manager',
    'Coordinator',
    'Specialist',
    'Expert',
    'Professional',
    'Enthusiast',
    'Learner',
    'Explorer',
    'Innovator',
    'Visionary',
    'Leader',
    'Builder',
    'Creator',
  ];

  List<String> get _filteredTags {
    if (_searchQuery.isEmpty) return _tags;
    return _tags
        .where((tag) => tag.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: AppColors.backgroundSecondary.withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _saveTag() async {
    _showMessage('Tag updated to: $_selectedTag');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      colors: AppColors.gradientWarm,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(
                        Icons.arrow_back,
                        color: AppColors.textPrimary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Select Tag',
                      style: AppTextStyles.headlineMedium(
                        weight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Search Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  style: AppTextStyles.bodyMedium(),
                  decoration: InputDecoration(
                    hintText: 'Search tags...',
                    hintStyle: AppTextStyles.bodyMedium(
                      color: AppColors.textTertiary,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppColors.textSecondary,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.backgroundSecondary.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.glassBorder.withOpacity(0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.glassBorder.withOpacity(0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.accentPrimary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              // Selected Tag Preview
              if (_selectedTag.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accentPrimary.withOpacity(0.2),
                        AppColors.accentSecondary.withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accentPrimary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.badge_outlined,
                        color: AppColors.accentPrimary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Selected: ',
                        style: AppTextStyles.bodyMedium(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        _selectedTag,
                        style: AppTextStyles.bodyMedium(
                          color: AppColors.accentPrimary,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              // Tags Grid
              Expanded(
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _filteredTags.length,
                  itemBuilder: (context, index) {
                    final tag = _filteredTags[index];
                    final isSelected = tag == _selectedTag;
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTag = tag;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accentPrimary.withOpacity(0.2)
                              : AppColors.backgroundSecondary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.accentPrimary
                                : AppColors.glassBorder.withOpacity(0.2),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            tag,
                            style: AppTextStyles.bodyMedium(
                              color: isSelected
                                  ? AppColors.accentPrimary
                                  : AppColors.textPrimary,
                              weight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Save Button
              Container(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveTag,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    child: Text(
                      'Save Tag',
                      style: AppTextStyles.bodyLarge(
                        color: Colors.white,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

