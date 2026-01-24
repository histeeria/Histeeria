import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/widgets/gradient_background.dart';

class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  List<String> _selectedSkills = [
    'Flutter',
    'React',
    'Node.js',
    'Python',
    'UI/UX Design',
    'Project Management',
  ];
  
  final List<String> _availableSkills = [
    'Flutter',
    'React',
    'Node.js',
    'Python',
    'Java',
    'Swift',
    'Kotlin',
    'TypeScript',
    'Go',
    'Rust',
    'C++',
    'C#',
    'PHP',
    'Ruby',
    'UI/UX Design',
    'Graphic Design',
    'Product Design',
    'Web Design',
    'Mobile Design',
    'Project Management',
    'Agile',
    'Scrum',
    'DevOps',
    'AWS',
    'Azure',
    'Docker',
    'Kubernetes',
    'CI/CD',
    'Machine Learning',
    'Data Science',
    'AI',
    'Blockchain',
    'Cybersecurity',
    'Cloud Computing',
    'Database Design',
    'SQL',
    'MongoDB',
    'Firebase',
    'Git',
    'Testing',
    'API Development',
    'Microservices',
    'System Design',
    'Leadership',
    'Communication',
    'Problem Solving',
    'Critical Thinking',
    'Teamwork',
  ];

  List<String> get _filteredSkills {
    if (_searchQuery.isEmpty) {
      return _availableSkills.where((skill) => !_selectedSkills.contains(skill)).toList();
    }
    return _availableSkills
        .where((skill) => 
            !_selectedSkills.contains(skill) &&
            skill.toLowerCase().contains(_searchQuery.toLowerCase()))
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

  Future<void> _saveSkills() async {
    _showMessage('Skills updated successfully');
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
                      'Skills',
                      style: AppTextStyles.headlineMedium(
                        weight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Selected Skills
                    if (_selectedSkills.isNotEmpty) ...[
                      Text(
                        'Your Skills (${_selectedSkills.length})',
                        style: AppTextStyles.bodyMedium(
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedSkills.map((skill) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.accentPrimary.withOpacity(0.2),
                                  AppColors.accentSecondary.withOpacity(0.2),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.accentPrimary.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  skill,
                                  style: AppTextStyles.bodySmall(
                                    color: AppColors.accentPrimary,
                                    weight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedSkills.remove(skill);
                                    });
                                  },
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: AppColors.accentPrimary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // Search Bar
                    Text(
                      'Add Skills',
                      style: AppTextStyles.bodyMedium(
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      style: AppTextStyles.bodyMedium(),
                      decoration: InputDecoration(
                        hintText: 'Search skills...',
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
                    const SizedBox(height: 16),
                    
                    // Available Skills
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _filteredSkills.map((skill) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedSkills.add(skill);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundSecondary.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.glassBorder.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  skill,
                                  style: AppTextStyles.bodySmall(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveSkills,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        child: Text(
                          'Save Skills',
                          style: AppTextStyles.bodyLarge(
                            color: Colors.white,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

