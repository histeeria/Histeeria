import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../data/providers/signup_state_provider.dart';
import '../../data/services/auth_service.dart';

class AccountNameScreen extends StatefulWidget {
  const AccountNameScreen({super.key});

  @override
  State<AccountNameScreen> createState() => _AccountNameScreenState();
}

class _AccountNameScreenState extends State<AccountNameScreen>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _selectedGender;
  bool _isFormValid = false;
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  String? _usernameMessage;
  Timer? _debounceTimer;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  final List<String> _genders = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _usernameController.addListener(_onUsernameChanged);
    _displayNameController.addListener(_validateForm);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _usernameController.removeListener(_onUsernameChanged);
    _displayNameController.removeListener(_validateForm);
    _usernameController.dispose();
    _displayNameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    final username = _usernameController.text.trim();
    _validateForm();

    // Reset availability state when username changes
    if (username.length < 3) {
      if (mounted) {
        setState(() {
          _isCheckingUsername = false;
          _isUsernameAvailable = null;
          _usernameMessage = null;
        });
      }
      return;
    }

    _debounceTimer?.cancel();
    // Reduced debounce for faster username checking (optimized for speed)
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted && _usernameController.text.trim() == username) {
        _checkUsernameAvailability(username);
      }
    });
  }

  Future<void> _checkUsernameAvailability(String username) async {
    if (username.isEmpty || username.length < 3) {
      if (mounted) {
        setState(() {
          _isCheckingUsername = false;
          _isUsernameAvailable = null;
          _usernameMessage = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isCheckingUsername = true;
        _isUsernameAvailable = null;
        _usernameMessage = null;
      });
    }

    // Call actual API to check username availability
    final isAvailable = await _authService.checkUsernameAvailability(username);

    if (mounted) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = isAvailable;
        _usernameMessage = isAvailable
            ? 'Username is available!'
            : 'This username is already taken';
      });
      _animationController.forward(from: 0.0);
      _validateForm(); // Re-validate after check completes
    }
  }

  void _validateForm() {
    final usernameValid = _usernameController.text.length >= 3;
    final displayNameValid = _displayNameController.text.isNotEmpty;

    setState(() {
      // Allow form validation without database - frontend only
      _isFormValid = usernameValid && displayNameValid;
      // Don't require username availability check to pass
    });
  }

  void _handleNext() {
    if (_formKey.currentState!.validate()) {
      // Store data in signup state
      final signupProvider = context.read<SignupStateProvider>();
      signupProvider.setUsername(_usernameController.text.trim());
      signupProvider.setDisplayName(_displayNameController.text.trim());
      if (_selectedGender != null) {
        signupProvider.setGender(_selectedGender);
      }

      // Navigate to next screen
      context.push('/age');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      colors: AppColors.gradientCool,
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
                Text(
                  'Tell us about yourself',
                  style: AppTextStyles.displayMedium(),
                ),
                const SizedBox(height: 8),
                Text(
                  'This helps us personalize your experience and connect you with the right people.',
                  style: AppTextStyles.bodyLarge(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 40),
                // Form
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.glassBorder.withOpacity(0.3),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Username
                        Text('Username', style: AppTextStyles.labelLarge()),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _usernameController,
                          style: AppTextStyles.bodyLarge(),
                          onChanged: (_) {
                            _validateForm();
                          },
                          decoration: InputDecoration(
                            hintText: 'johndoe',
                            hintStyle: AppTextStyles.bodyMedium(),
                            filled: true,
                            fillColor: Colors.transparent,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _isUsernameAvailable == false
                                    ? AppColors.error
                                    : _isUsernameAvailable == true
                                    ? AppColors.success
                                    : AppColors.glassBorder,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _isUsernameAvailable == false
                                    ? AppColors.error
                                    : _isUsernameAvailable == true
                                    ? AppColors.success
                                    : AppColors.accentPrimary,
                                width: 2,
                              ),
                            ),
                            prefixIcon: const Icon(
                              Icons.alternate_email,
                              color: AppColors.textSecondary,
                            ),
                            suffixIcon: _buildUsernameSuffix(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a username';
                            }
                            if (value.length < 3) {
                              return 'Username must be at least 3 characters';
                            }
                            // Frontend-only: Don't block form submission based on availability
                            // Backend will validate username uniqueness on actual submission
                            return null;
                          },
                        ),
                        // Username status message
                        if (_usernameMessage != null) ...[
                          const SizedBox(height: 8),
                          AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              return FadeTransition(
                                opacity: _fadeAnimation,
                                child: ScaleTransition(
                                  scale: _scaleAnimation,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (_isUsernameAvailable == true
                                                  ? AppColors.success
                                                  : AppColors.error)
                                              .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color:
                                            (_isUsernameAvailable == true
                                                    ? AppColors.success
                                                    : AppColors.error)
                                                .withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _isUsernameAvailable == true
                                              ? Icons.check_circle
                                              : Icons.cancel,
                                          size: 18,
                                          color: _isUsernameAvailable == true
                                              ? AppColors.success
                                              : AppColors.error,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _usernameMessage!,
                                          style: AppTextStyles.bodySmall(
                                            color: _isUsernameAvailable == true
                                                ? AppColors.success
                                                : AppColors.error,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                        const SizedBox(height: 24),
                        // Display name
                        Text('Display name', style: AppTextStyles.labelLarge()),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _displayNameController,
                          style: AppTextStyles.bodyLarge(),
                          decoration: InputDecoration(
                            hintText: 'John Doe',
                            hintStyle: AppTextStyles.bodyMedium(),
                            filled: true,
                            fillColor: Colors.transparent,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.glassBorder,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.accentPrimary,
                                width: 2,
                              ),
                            ),
                            prefixIcon: const Icon(
                              Icons.person_outline,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          onChanged: (_) => _validateForm(),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your display name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        // Gender
                        Text('Gender', style: AppTextStyles.labelLarge()),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedGender,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.transparent,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.glassBorder,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.accentPrimary,
                                width: 2,
                              ),
                            ),
                            prefixIcon: const Icon(
                              Icons.people_outline,
                              color: AppColors.textSecondary,
                            ),
                            hint: Text(
                              'Select gender',
                              style: AppTextStyles.bodyMedium(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                          items: _genders.map((gender) {
                            return DropdownMenuItem(
                              value: gender,
                              child: Text(
                                gender,
                                style: AppTextStyles.bodyLarge(),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedGender = value;
                            });
                          },
                          style: AppTextStyles.bodyLarge(),
                          dropdownColor: AppColors.backgroundSecondary,
                          icon: Icon(
                            Icons.keyboard_arrow_down,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isFormValid ? _handleNext : null,
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

  Widget? _buildUsernameSuffix() {
    if (_isCheckingUsername) {
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentPrimary),
          ),
        ),
      );
    }
    if (_isUsernameAvailable == true) {
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: Icon(Icons.check_circle, color: AppColors.success, size: 24),
      );
    }
    if (_isUsernameAvailable == false) {
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: Icon(Icons.cancel, color: AppColors.error, size: 24),
      );
    }
    return null;
  }
}
