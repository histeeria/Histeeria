import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/gradient_background.dart';

class ProjectPortfolioScreen extends StatefulWidget {
  const ProjectPortfolioScreen({super.key});

  @override
  State<ProjectPortfolioScreen> createState() => _ProjectPortfolioScreenState();
}

class _ProjectPortfolioScreenState extends State<ProjectPortfolioScreen> {
  final List<Map<String, dynamic>> _projects = [
    {
      'title': 'E-Commerce Mobile App',
      'description': 'Full-featured shopping app with payment integration',
      'tech': ['Flutter', 'Firebase', 'Stripe'],
      'status': 'Completed',
      'date': 'Nov 2024',
      'collaborators': 3,
      'earnings': '\$2,500',
      'icon': Icons.shopping_cart,
    },
    {
      'title': 'Social Media Dashboard',
      'description': 'Analytics dashboard for social media management',
      'tech': ['React', 'Node.js', 'MongoDB'],
      'status': 'In Progress',
      'date': 'Oct 2024',
      'collaborators': 2,
      'earnings': '\$1,800',
      'icon': Icons.dashboard,
    },
    {
      'title': 'Healthcare Management System',
      'description': 'Patient management and appointment scheduling',
      'tech': ['Flutter', 'PostgreSQL', 'AWS'],
      'status': 'Completed',
      'date': 'Sep 2024',
      'collaborators': 4,
      'earnings': '\$3,200',
      'icon': Icons.local_hospital,
    },
  ];

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return AppColors.success;
      case 'In Progress':
        return AppColors.accentPrimary;
      case 'On Hold':
        return AppColors.textTertiary;
      default:
        return AppColors.textSecondary;
    }
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
                      'Project Portfolio',
                      style: AppTextStyles.headlineMedium(
                        weight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        _showMessage('Add new project - Coming soon');
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accentPrimary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.add,
                          color: AppColors.accentPrimary,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.all(20),
                  itemCount: _projects.length,
                  itemBuilder: (context, index) {
                    final project = _projects[index];
                    final status = project['status'] as String;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getStatusColor(status).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.accentPrimary.withOpacity(0.3),
                                      AppColors.accentSecondary.withOpacity(0.3),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  project['icon'],
                                  color: AppColors.accentPrimary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      project['title'],
                                      style: AppTextStyles.bodyLarge(
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      project['date'],
                                      style: AppTextStyles.bodySmall(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  status,
                                  style: AppTextStyles.bodySmall(
                                    color: _getStatusColor(status),
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          Text(
                            project['description'],
                            style: AppTextStyles.bodyMedium(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          
                          // Technologies
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: (project['tech'] as List<String>).map((tech) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundPrimary.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  tech,
                                  style: AppTextStyles.bodySmall(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          
                          // Stats
                          Row(
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 16,
                                color: AppColors.textTertiary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${project['collaborators']} collaborators',
                                style: AppTextStyles.bodySmall(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(
                                Icons.attach_money,
                                size: 16,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                project['earnings'],
                                style: AppTextStyles.bodySmall(
                                  color: AppColors.success,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: AppColors.textTertiary,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTextStyles.bodySmall(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

