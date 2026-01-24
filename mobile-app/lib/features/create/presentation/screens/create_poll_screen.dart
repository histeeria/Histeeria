import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../posts/data/services/posts_service.dart';
import '../../../feed/data/providers/feed_provider.dart';
import '../../../auth/data/providers/auth_provider.dart';

class CreatePollScreen extends StatefulWidget {
  const CreatePollScreen({super.key});

  @override
  State<CreatePollScreen> createState() => _CreatePollScreenState();
}

class _CreatePollScreenState extends State<CreatePollScreen> {
  final TextEditingController _questionController = TextEditingController();
  final PostsService _postsService = PostsService();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  
  String _duration = '1 day';
  bool _allowMultipleVotes = false;
  bool _showResults = true;
  bool _isPosting = false;

  @override
  void dispose() {
    _questionController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
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

  void _addOption() {
    if (_optionControllers.length < 4) {
      setState(() {
        _optionControllers.add(TextEditingController());
      });
    } else {
      _showMessage('Maximum 4 options allowed');
    }
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        _optionControllers[index].dispose();
        _optionControllers.removeAt(index);
      });
    }
  }

  Future<void> _publishPoll() async {
    if (_questionController.text.trim().isEmpty) {
      _showMessage('Please enter a question');
      return;
    }

    final filledOptions = _optionControllers
        .where((controller) => controller.text.trim().isNotEmpty)
        .toList();
    
    if (filledOptions.length < 2) {
      _showMessage('Please add at least 2 options');
      return;
    }

    setState(() {
      _isPosting = true;
    });

    try {
      // Map duration to hours
      int durationHours = 24; // Default 1 day
      switch (_duration) {
        case '1 day':
          durationHours = 24;
          break;
        case '3 days':
          durationHours = 72;
          break;
        case '1 week':
          durationHours = 168;
          break;
        case '2 weeks':
          durationHours = 336;
          break;
        case 'Never':
          durationHours = 168; // Max allowed is 1 week, use that
          break;
      }

      final pollData = {
        'question': _questionController.text.trim(),
        'options': filledOptions.map((c) => c.text.trim()).toList(),
        'duration_hours': durationHours,
        'allow_multiple_votes': _allowMultipleVotes,
        'show_results_before_vote': _showResults,
        'allow_vote_changes': false,
        'anonymous_votes': false,
      };

      final response = await _postsService.createPost(
        postType: 'poll',
        content: _questionController.text.trim(),
        visibility: 'public',
        allowsComments: true,
        allowsSharing: true,
        poll: pollData,
      );

      if (response.success && response.data != null) {
        // Refresh feed
        final feedProvider = Provider.of<FeedProvider>(context, listen: false);
        await feedProvider.refresh();

        _showMessage('Poll published successfully');
        Navigator.pop(context);
      } else {
        _showMessage(response.error ?? 'Failed to publish poll');
      }
    } catch (e) {
      _showMessage('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  void _showDurationPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.glassBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Poll Duration',
              style: AppTextStyles.headlineSmall(weight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ...['1 day', '3 days', '1 week', '2 weeks', 'Never'].map((duration) {
              final isSelected = _duration == duration;
              return ListTile(
                title: Text(
                  duration,
                  style: AppTextStyles.bodyMedium(
                    color: isSelected ? AppColors.accentPrimary : AppColors.textPrimary,
                    weight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check, color: AppColors.accentPrimary)
                    : null,
                onTap: () {
                  setState(() {
                    _duration = duration;
                  });
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ],
        ),
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
                        Icons.close,
                        color: AppColors.textPrimary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Create Poll',
                      style: AppTextStyles.headlineMedium(
                        weight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        _showMessage('Saved to drafts');
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Draft',
                        style: AppTextStyles.bodyMedium(
                          color: AppColors.accentPrimary,
                          weight: FontWeight.w600,
                        ),
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
                    // User Info
                    Consumer<AuthProvider>(
                      builder: (context, authProvider, _) {
                        final currentUser = authProvider.currentUser;
                        final displayName = currentUser?.displayName ?? currentUser?.username ?? 'User';
                        final username = currentUser?.username ?? '';
                        final profilePicture = currentUser?.profilePicture;
                        
                        return Row(
                          children: [
                            profilePicture != null && profilePicture.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(25),
                                    child: CachedNetworkImage(
                                      imageUrl: profilePicture,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.accentPrimary,
                                              AppColors.accentSecondary,
                                            ],
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : 'U',
                                            style: AppTextStyles.bodyLarge(
                                              color: Colors.white,
                                              weight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.accentPrimary,
                                              AppColors.accentSecondary,
                                            ],
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : 'U',
                                            style: AppTextStyles.bodyLarge(
                                              color: Colors.white,
                                              weight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.accentPrimary,
                                          AppColors.accentSecondary,
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : 'U',
                                        style: AppTextStyles.bodyLarge(
                                          color: Colors.white,
                                          weight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    style: AppTextStyles.bodyLarge(
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                  if (username.isNotEmpty)
                                    Text(
                                      '@$username',
                                      style: AppTextStyles.bodySmall(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    // Question
                    Text(
                      'Question',
                      style: AppTextStyles.bodySmall(
                        color: AppColors.textSecondary,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _questionController,
                      maxLength: 200,
                      style: AppTextStyles.bodyLarge(
                        weight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Ask a question...',
                        hintStyle: AppTextStyles.bodyMedium(
                          color: AppColors.textTertiary,
                        ),
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
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Options
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Options',
                          style: AppTextStyles.bodySmall(
                            color: AppColors.textSecondary,
                            weight: FontWeight.w600,
                          ),
                        ),
                        if (_optionControllers.length < 4)
                          TextButton.icon(
                            onPressed: _addOption,
                            icon: Icon(
                              Icons.add,
                              size: 16,
                              color: AppColors.accentPrimary,
                            ),
                            label: Text(
                              'Add Option',
                              style: AppTextStyles.bodySmall(
                                color: AppColors.accentPrimary,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    ...List.generate(_optionControllers.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextField(
                          controller: _optionControllers[index],
                          maxLength: 50,
                          style: AppTextStyles.bodyMedium(),
                          decoration: InputDecoration(
                            hintText: 'Option ${index + 1}',
                            hintStyle: AppTextStyles.bodyMedium(
                              color: AppColors.textTertiary,
                            ),
                            prefixIcon: Icon(
                              Icons.radio_button_unchecked,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            suffixIcon: _optionControllers.length > 2
                                ? IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      color: AppColors.accentQuaternary,
                                      size: 20,
                                    ),
                                    onPressed: () => _removeOption(index),
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
                            counterText: '',
                          ),
                        ),
                      );
                    }),
                    
                    const SizedBox(height: 20),
                    
                    // Poll Settings
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _showDurationPicker,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Poll Duration',
                                    style: AppTextStyles.bodyMedium(
                                      weight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Text(
                                  _duration,
                                  style: AppTextStyles.bodySmall(
                                    color: AppColors.accentPrimary,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.chevron_right,
                                  color: AppColors.textTertiary,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(
                                Icons.how_to_vote_outlined,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Allow Multiple Votes',
                                  style: AppTextStyles.bodyMedium(
                                    weight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Switch(
                                value: _allowMultipleVotes,
                                onChanged: (value) => setState(() => _allowMultipleVotes = value),
                                activeColor: AppColors.accentPrimary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(
                                Icons.visibility_outlined,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Show Results',
                                  style: AppTextStyles.bodyMedium(
                                    weight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Switch(
                                value: _showResults,
                                onChanged: (value) => setState(() => _showResults = value),
                                activeColor: AppColors.accentPrimary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Bottom Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary.withOpacity(0.9),
                  border: Border(
                    top: BorderSide(
                      color: AppColors.glassBorder.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isPosting ? null : _publishPoll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentPrimary,
                      disabledBackgroundColor:
                          AppColors.textTertiary.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    child: _isPosting
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Publish Poll',
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

