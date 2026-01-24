import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/gradient_background.dart';

class MyApplicationsScreen extends StatefulWidget {
  const MyApplicationsScreen({super.key});

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen> {
  String _selectedFilter = 'All';
  
  final List<Map<String, dynamic>> _applications = [
    {
      'company': 'TechCorp Inc.',
      'position': 'Senior Flutter Developer',
      'location': 'Remote',
      'salary': '\$100K - \$130K',
      'appliedDate': 'Nov 25, 2024',
      'status': 'Under Review',
      'type': 'Full-time',
      'icon': Icons.business,
    },
    {
      'company': 'StartupXYZ',
      'position': 'Mobile App Developer',
      'location': 'San Francisco, CA',
      'salary': '\$90K - \$120K',
      'appliedDate': 'Nov 20, 2024',
      'status': 'Interview Scheduled',
      'type': 'Full-time',
      'icon': Icons.business_center,
    },
    {
      'company': 'Design Studio',
      'position': 'UI/UX Designer',
      'location': 'Hybrid',
      'salary': '\$80K - \$100K',
      'appliedDate': 'Nov 15, 2024',
      'status': 'Rejected',
      'type': 'Contract',
      'icon': Icons.design_services,
    },
    {
      'company': 'Innovation Labs',
      'position': 'Full Stack Developer',
      'location': 'Remote',
      'salary': '\$110K - \$140K',
      'appliedDate': 'Nov 10, 2024',
      'status': 'Offer Received',
      'type': 'Full-time',
      'icon': Icons.code,
    },
    {
      'company': 'Creative Agency',
      'position': 'Frontend Developer',
      'location': 'New York, NY',
      'salary': '\$85K - \$110K',
      'appliedDate': 'Nov 5, 2024',
      'status': 'Withdrawn',
      'type': 'Part-time',
      'icon': Icons.web,
    },
  ];

  List<Map<String, dynamic>> get _filteredApplications {
    if (_selectedFilter == 'All') return _applications;
    return _applications.where((app) => app['status'] == _selectedFilter).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Under Review':
        return AppColors.textTertiary;
      case 'Interview Scheduled':
        return AppColors.accentPrimary;
      case 'Offer Received':
        return AppColors.success;
      case 'Rejected':
        return AppColors.accentQuaternary;
      case 'Withdrawn':
        return AppColors.textSecondary;
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
                      'My Applications',
                      style: AppTextStyles.headlineMedium(
                        weight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Filter Tabs
              Container(
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    'All',
                    'Under Review',
                    'Interview Scheduled',
                    'Offer Received',
                    'Rejected',
                    'Withdrawn'
                  ].map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accentPrimary
                              : AppColors.backgroundSecondary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Center(
                          child: Text(
                            filter,
                            style: AppTextStyles.bodySmall(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              weight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              // Applications List
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.all(20),
                  itemCount: _filteredApplications.length,
                  itemBuilder: (context, index) {
                    final app = _filteredApplications[index];
                    final status = app['status'] as String;
                    
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
                                  color: AppColors.accentPrimary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  app['icon'],
                                  color: AppColors.accentPrimary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      app['position'],
                                      style: AppTextStyles.bodyLarge(
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      app['company'],
                                      style: AppTextStyles.bodyMedium(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Details
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              _InfoChip(
                                icon: Icons.location_on_outlined,
                                text: app['location'],
                              ),
                              _InfoChip(
                                icon: Icons.attach_money,
                                text: app['salary'],
                              ),
                              _InfoChip(
                                icon: Icons.work_outline,
                                text: app['type'],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // Status and Date
                          Row(
                            children: [
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
                              const Spacer(),
                              Text(
                                'Applied ${app['appliedDate']}',
                                style: AppTextStyles.bodySmall(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                          
                          if (status == 'Under Review' || status == 'Interview Scheduled') ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () {
                                  _showMessage('Withdraw application - Coming soon');
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  side: BorderSide(
                                    color: AppColors.accentQuaternary,
                                    width: 1,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Withdraw Application',
                                  style: AppTextStyles.bodySmall(
                                    color: AppColors.accentQuaternary,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
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

