import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/services/auth_service.dart';
import '../../../../core/services/token_storage_service.dart';

/// Screen for adding a new account to the account group
class AddAccountScreen extends StatefulWidget {
  const AddAccountScreen({Key? key}) : super(key: key);

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _isLoginMode = true; // true = login, false = create account
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAddAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (_isLoginMode) {
        // Login to existing account, then link
        final loginResponse = await _authService.login(email, password);
        
        if (loginResponse.success && loginResponse.data != null) {
          final user = loginResponse.data!.user;
          if (user != null) {
            // Save token for this user
            final tokenStorage = TokenStorageService();
            await tokenStorage.saveAccessTokenForUser(
              user.id,
              loginResponse.data!.token!,
            );
            await tokenStorage.saveUserDataForUser(
              user.id,
              jsonEncode(user.toJson()),
            );

            // Check if account is already linked before attempting to link
            final linkedAccounts = authProvider.linkedAccounts;
            final isAlreadyLinked = linkedAccounts.any(
              (account) => account.userId == user.id || account.email == email,
            );

            if (isAlreadyLinked) {
              // Account is already linked - refresh and show success message
              await authProvider.refreshLinkedAccounts();
              if (mounted) {
                Navigator.pop(context, true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text('Account is already linked'),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
              return;
            }

            // Link account to current account group
            final linkSuccess = await authProvider.linkAccount(email, password);
            
            if (linkSuccess) {
              if (mounted) {
                Navigator.pop(context, true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text('Account linked successfully'),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            } else {
              // Link failed - check if it's an "already linked" error
              // Refresh accounts first to get latest state
              await authProvider.refreshLinkedAccounts();
              
              final linkedAccountsAfter = authProvider.linkedAccounts;
              final isNowLinked = linkedAccountsAfter.any(
                (account) => account.userId == user.id || account.email == email,
              );

              if (isNowLinked) {
                // Account is actually linked (was already linked or got linked)
                if (mounted) {
                  Navigator.pop(context, true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text('Account is already linked'),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              } else {
                setState(() {
                  _errorMessage = 'Failed to link account. Please try again.';
                });
              }
            }
          }
        } else {
          // Login failed - maybe account doesn't exist
          setState(() {
            _errorMessage = loginResponse.error ?? 'Login failed. Account may not exist.';
          });
        }
      } else {
        // Create new account - navigate to signup flow
        // Store email for signup
        context.push('/signup-email', extra: email).then((result) {
          if (result == true && mounted) {
            // After signup, try to link the account
            Navigator.pop(context, true);
          }
        });
        return;
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Add Account',
          style: AppTextStyles.headlineSmall(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 20),

                // Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accentPrimary.withOpacity(0.1),
                  ),
                  child: Icon(
                    Icons.person_add,
                    size: 40,
                    color: AppColors.accentPrimary,
                  ),
                ),

                SizedBox(height: 30),

                // Title
                Text(
                  _isLoginMode ? 'Login to Account' : 'Create New Account',
                  style: AppTextStyles.headlineMedium(),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 10),

                // Description
                Text(
                  _isLoginMode
                      ? 'Login to an existing account and link it to switch between accounts easily.'
                      : 'Create a new account that will be linked to your current account.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 20),

                // Toggle between login and create
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLoginMode = true;
                          _errorMessage = null;
                        });
                      },
                      child: Text(
                        'Login',
                        style: TextStyle(
                          color: _isLoginMode
                              ? AppColors.accentPrimary
                              : AppColors.textSecondary,
                          fontWeight: _isLoginMode ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    Text('|', style: TextStyle(color: AppColors.textSecondary)),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLoginMode = false;
                          _errorMessage = null;
                        });
                      },
                      child: Text(
                        'Create Account',
                        style: TextStyle(
                          color: !_isLoginMode
                              ? AppColors.accentPrimary
                              : AppColors.textSecondary,
                          fontWeight: !_isLoginMode ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20),

                // Error message
                if (_errorMessage != null)
                  Container(
                    padding: EdgeInsets.all(12),
                    margin: EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Email field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter email address',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),

                SizedBox(height: 20),

                // Password field (only for login mode)
                if (_isLoginMode) ...[
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleAddAccount(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter password',
                    prefixIcon: Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                  ),
                  SizedBox(height: 20),
                ],

                SizedBox(height: 30),

                // Action button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleAddAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _isLoginMode ? 'Login & Link Account' : 'Create Account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),

                // For create account mode, show info
                if (!_isLoginMode) ...[
                  SizedBox(height: 20),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.accentPrimary,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'You will be taken through the account creation process. The new account will be automatically linked.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Info text (only for login mode)
                if (_isLoginMode) ...[
                  SizedBox(height: 20),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.accentPrimary,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your password is required to verify account ownership. It will not be stored.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
