import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../data/providers/signup_state_provider.dart';

class AgeScreen extends StatefulWidget {
  const AgeScreen({super.key});

  @override
  State<AgeScreen> createState() => _AgeScreenState();
}

class _AgeScreenState extends State<AgeScreen> {
  late final FixedExtentScrollController _scrollController;
  int? _selectedAge;
  final int _minAge = 13;
  final int _maxAge = 100;

  @override
  void initState() {
    super.initState();
    // Start at age 25 (middle-ish)
    _selectedAge = 25;
    _scrollController = FixedExtentScrollController(
      initialItem: _selectedAge! - _minAge,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleNext() {
    if (_selectedAge != null) {
      // Store age in signup state
      final signupProvider = context.read<SignupStateProvider>();
      signupProvider.setAge(_selectedAge);
      context.push('/profile-setup');
    }
  }

  void _handleSkip() {
    // Age is optional, so skip is fine
    context.push('/profile-setup');
  }

  List<int> get _ages =>
      List.generate(_maxAge - _minAge + 1, (index) => _minAge + index);

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      colors: AppColors.gradientPurple,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => context.pop(),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text('How old are you?', style: AppTextStyles.displayMedium()),
                const SizedBox(height: 8),
                Text(
                  'This helps us show you age-appropriate content and connect you with peers. (Optional)',
                  style: AppTextStyles.bodyLarge(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 40),
                // Age wheel picker
                Container(
                  height: 300,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.glassBorder.withOpacity(0.3),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    children: [
                      // Selection indicator overlay
                      Center(
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            border: Border.symmetric(
                              horizontal: BorderSide(
                                color: AppColors.accentPrimary.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Wheel picker
                      ListWheelScrollView.useDelegate(
                        controller: _scrollController,
                        itemExtent: 60,
                        physics: const FixedExtentScrollPhysics(),
                        perspective: 0.003,
                        diameterRatio: 1.5,
                        onSelectedItemChanged: (index) {
                          setState(() {
                            _selectedAge = _ages[index];
                          });
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          builder: (context, index) {
                            if (index < 0 || index >= _ages.length) {
                              return const SizedBox.shrink();
                            }
                            final age = _ages[index];
                            final isSelected = age == _selectedAge;

                            return _AgeWheelItem(
                              age: age,
                              isSelected: isSelected,
                            );
                          },
                          childCount: _ages.length,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_selectedAge != null) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.accentPrimary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cake_outlined,
                            size: 20,
                            color: AppColors.accentPrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Selected: $_selectedAge years old',
                            style: AppTextStyles.bodyMedium(
                              color: AppColors.accentPrimary,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                // Navigation buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.pop(),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.glassBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text('Back', style: AppTextStyles.labelLarge()),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextButton(
                        onPressed: _handleSkip,
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          'Skip',
                          style: AppTextStyles.labelLarge(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _selectedAge != null ? _handleNext : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentPrimary,
                          disabledBackgroundColor: AppColors.surface
                              .withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        child: Text(
                          'Next',
                          style: AppTextStyles.labelLarge(
                            color: AppColors.textPrimary,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AgeWheelItem extends StatelessWidget {
  final int age;
  final bool isSelected;

  const _AgeWheelItem({required this.age, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.center,
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        style: isSelected
            ? AppTextStyles.displayMedium(
                color: AppColors.accentPrimary,
                weight: FontWeight.bold,
              )
            : AppTextStyles.headlineSmall(
                color: AppColors.textSecondary.withOpacity(0.5),
              ),
        child: Text('$age', textAlign: TextAlign.center),
      ),
    );
  }
}
