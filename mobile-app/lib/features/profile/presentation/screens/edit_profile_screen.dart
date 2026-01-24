import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../features/auth/data/providers/auth_provider.dart';
import '../../../../features/auth/data/models/user.dart';
import '../../data/providers/profile_provider.dart';
import '../../../../core/services/storage_service.dart';
import '../../data/services/profile_service.dart';
import '../../../../core/api/models/api_response.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/services/token_storage_service.dart';
import '../../data/models/certification.dart';
import '../../data/models/skill.dart';
import '../../data/models/language.dart';
import '../../data/models/volunteering.dart';
import '../../data/models/publication.dart';
import '../../data/models/interest.dart';
import '../../data/models/achievement.dart';
import '../../data/models/experience.dart';
import '../../data/models/education.dart';
import 'package:intl/intl.dart';

/// Modern Edit Profile Screen
/// Clean, professional design with toggle switches for section visibility
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _scrollController = ScrollController();
  bool _initialLoad = true;
  final ProfileService _profileService = ProfileService();
  bool _isSavingVisibility = false;

  // Section visibility toggles - mapped from field_visibility
  Map<String, bool> _sectionVisibility = {
    'basic_info': true,
    'story': true,
    'experience': true,
    'education': true,
    'skills': true,
    'certifications': true,
    'languages': true,
    'volunteering': true,
    'publications': true,
    'interests': true,
    'achievements': true,
    'social_links': true,
  };

  // Map section keys to field visibility keys
  final Map<String, String> _sectionToFieldMap = {
    'basic_info': 'location', // Basic info visibility controlled by location/age/gender/website
    'story': 'story',
    'experience': 'experience',
    'education': 'education',
    'skills': 'skills',
    'certifications': 'certifications',
    'languages': 'languages',
    'volunteering': 'volunteering',
    'publications': 'publications',
    'interests': 'interests',
    'achievements': 'achievements',
    'social_links': 'social_links',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileData();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final authProvider = context.read<AuthProvider>();
    final profileProvider = context.read<ProfileProvider>();
    
    // Refresh user to get latest field visibility
    await authProvider.refreshUser();
    
    // Load profile data
    profileProvider.loadAllProfileData().then((_) {
      if (mounted) {
        setState(() {
          _initialLoad = false;
        });
      }
    });
    
    // Load field visibility from user
    final user = authProvider.currentUser;
    if (user != null && user.fieldVisibility != null) {
      setState(() {
        // Map field visibility to section visibility
        _sectionVisibility['basic_info'] = 
            (user.fieldVisibility!['location'] ?? true) ||
            (user.fieldVisibility!['age'] ?? true) ||
            (user.fieldVisibility!['gender'] ?? true) ||
            (user.fieldVisibility!['website'] ?? true);
        _sectionVisibility['story'] = user.fieldVisibility!['story'] ?? true;
        // Map other fields if they exist in fieldVisibility
        for (var entry in _sectionToFieldMap.entries) {
          if (user.fieldVisibility!.containsKey(entry.value)) {
            _sectionVisibility[entry.key] = user.fieldVisibility![entry.value] ?? true;
          }
        }
      });
    }
    
    // Set initial load to false after a short delay to show UI faster
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _initialLoad = false;
        });
      }
    });
  }

  Future<void> _saveVisibilityToggle(String sectionKey, bool value) async {
    setState(() {
      _sectionVisibility[sectionKey] = value;
      _isSavingVisibility = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser;
      if (user == null) return;

      // Build field visibility map
      final fieldVisibility = Map<String, bool>.from(user.fieldVisibility ?? {});
      
      // Update the corresponding field visibility
      final fieldKey = _sectionToFieldMap[sectionKey];
      if (fieldKey != null) {
        if (sectionKey == 'basic_info') {
          // For basic info, update multiple fields
          fieldVisibility['location'] = value;
          fieldVisibility['age'] = value;
          fieldVisibility['gender'] = value;
          fieldVisibility['website'] = value;
        } else {
          fieldVisibility[fieldKey] = value;
        }
      }

      // Save to backend - include current profile_privacy (required by backend)
      final response = await _profileService.updatePrivacySettings(
        profilePrivacy: user.profilePrivacy ?? 'public', // Default to public if not set
        fieldVisibility: fieldVisibility,
      );

      if (response.success) {
        // Refresh user to get updated visibility
        await authProvider.refreshUser();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(value ? 'Section is now visible' : 'Section is now hidden'),
              backgroundColor: AppColors.accentPrimary,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Revert on error
        setState(() {
          _sectionVisibility[sectionKey] = !value;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.error ?? 'Failed to update visibility'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // Revert on error
      setState(() {
        _sectionVisibility[sectionKey] = !value;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingVisibility = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    final profileProvider = context.read<ProfileProvider>();
    setState(() => _initialLoad = true);
    await profileProvider.loadAllProfileData();
    if (mounted) {
      setState(() {
        _initialLoad = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Please log in to edit your profile',
            style: AppTextStyles.bodyMedium(),
          ),
        ),
      );
    }

    return GradientBackground(
      colors: AppColors.gradientWarm,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Modern Header
              _ModernHeader(
                onBack: () => context.pop(),
                onRefresh: _refreshData,
                isLoading: _initialLoad || profileProvider.isLoading,
              ),
              Expanded(
                child: _initialLoad || profileProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          const SizedBox(height: 8),

                          // Cover Photo (moved above profile picture)
                          _CoverPhotoSection(user: user),
                          const SizedBox(height: 24),

                          // Profile Picture
                          _ProfilePictureSection(user: user),
                          const SizedBox(height: 24),
                          
                          // Display Name and Username (editable)
                          _DisplayNameUsernameSection(user: user),
                          const SizedBox(height: 24),

                          // Basic Information
                          _SectionHeader(
                            title: 'Basic Information',
                            icon: Icons.person_outline_rounded,
                            isVisible: _sectionVisibility['basic_info']!,
                            isLoading: _isSavingVisibility,
                            onToggle: (value) {
                              _saveVisibilityToggle('basic_info', value);
                            },
                          ),
                          if (_sectionVisibility['basic_info']!) ...[
                            const SizedBox(height: 12),
                            _BasicInfoSection(
                              user: user,
                              context: context,
                              onUpdate: () async {
                                await context.read<AuthProvider>().refreshUser();
                              },
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Story
                          _SectionHeader(
                            title: 'Story',
                            icon: Icons.book_outlined,
                            isVisible: _sectionVisibility['story']!,
                            isLoading: _isSavingVisibility,
                            onToggle: (value) {
                              _saveVisibilityToggle('story', value);
                            },
                          ),
                          if (_sectionVisibility['story']!) ...[
                            const SizedBox(height: 12),
                            _StorySection(
                              user: user,
                              context: context,
                              onUpdate: () {
                                // Refresh user data after story update
                                context.read<AuthProvider>().refreshUser();
                              },
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Experience
                          _SectionHeader(
                            title: 'Experience',
                            icon: Icons.work_outline_rounded,
                            isVisible: _sectionVisibility['experience']!,
                            isLoading: _isSavingVisibility,
                            onToggle: (value) {
                              _saveVisibilityToggle('experience', value);
                            },
                          ),
                          if (_sectionVisibility['experience']!) ...[
                            const SizedBox(height: 12),
                            _ExperienceSection(
                              context: context,
                              onUpdate: () async {
                                await context.read<ProfileProvider>().loadExperiences();
                              },
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Education
                          _SectionHeader(
                            title: 'Education',
                            icon: Icons.school_outlined,
                            isVisible: _sectionVisibility['education']!,
                            isLoading: _isSavingVisibility,
                            onToggle: (value) {
                              _saveVisibilityToggle('education', value);
                            },
                          ),
                          if (_sectionVisibility['education']!) ...[
                            const SizedBox(height: 12),
                            _EducationSection(
                              context: context,
                              onUpdate: () async {
                                await context.read<ProfileProvider>().loadEducation();
                              },
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Skills
                          _SectionHeader(
                            title: 'Skills',
                            icon: Icons.stars_outlined,
                            isVisible: _sectionVisibility['skills']!,
                            isLoading: _isSavingVisibility,
                            onToggle: (value) {
                              _saveVisibilityToggle('skills', value);
                            },
                          ),
                          if (_sectionVisibility['skills']!) ...[
                            const SizedBox(height: 12),
                            _SkillsSection(
                              skills: profileProvider.skills,
                              context: context,
                              onUpdate: () {
                                // Refresh skills after add/edit
                                profileProvider.loadSkills();
                              },
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Certifications
                          _SectionHeader(
                            title: 'Certifications',
                            icon: Icons.verified_outlined,
                            isVisible: _sectionVisibility['certifications']!,
                            isLoading: _isSavingVisibility,
                            onToggle: (value) {
                              _saveVisibilityToggle('certifications', value);
                            },
                          ),
                          if (_sectionVisibility['certifications']!) ...[
                            const SizedBox(height: 12),
                            _CertificationsSection(
                              certifications: profileProvider.certifications,
                              context: context,
                              onUpdate: () {
                                profileProvider.loadCertifications();
                              },
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Languages
                          _SectionHeader(
                            title: 'Languages',
                            icon: Icons.translate_outlined,
                            isVisible: _sectionVisibility['languages']!,
                            isLoading: _isSavingVisibility,
                            onToggle: (value) {
                              _saveVisibilityToggle('languages', value);
                            },
                          ),
                          if (_sectionVisibility['languages']!) ...[
                            const SizedBox(height: 12),
                            _LanguagesSection(
                              languages: profileProvider.languages,
                              context: context,
                              onUpdate: () {
                                profileProvider.loadLanguages();
                              },
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Volunteering
                          _SectionHeader(
                            title: 'Volunteering',
                            icon: Icons.volunteer_activism_outlined,
                            isVisible: _sectionVisibility['volunteering']!,
                            isLoading: _isSavingVisibility,
                            onToggle: (value) {
                              _saveVisibilityToggle('volunteering', value);
                            },
                          ),
                          if (_sectionVisibility['volunteering']!) ...[
                            const SizedBox(height: 12),
                            _VolunteeringSection(
                              volunteering: profileProvider.volunteering,
                              context: context,
                              onUpdate: () {
                                profileProvider.loadVolunteering();
                              },
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Publications
                          _SectionHeader(
                            title: 'Publications',
                            icon: Icons.article_outlined,
                            isVisible: _sectionVisibility['publications']!,
                            isLoading: _isSavingVisibility,
                            onToggle: (value) {
                              _saveVisibilityToggle('publications', value);
                            },
                          ),
                          if (_sectionVisibility['publications']!) ...[
                            const SizedBox(height: 12),
                            _PublicationsSection(
                              publications: profileProvider.publications,
                              context: context,
                              onUpdate: () {
                                profileProvider.loadPublications();
                              },
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Interests
                          _SectionHeader(
                            title: 'Interests',
                            icon: Icons.favorite_outline_rounded,
                            isVisible: _sectionVisibility['interests']!,
                            isLoading: _isSavingVisibility,
                            onToggle: (value) {
                              _saveVisibilityToggle('interests', value);
                            },
                          ),
                          if (_sectionVisibility['interests']!) ...[
                            const SizedBox(height: 12),
                            _InterestsSection(
                              interests: profileProvider.interests,
                              context: context,
                              onUpdate: () {
                                profileProvider.loadInterests();
                              },
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Achievements
                          _SectionHeader(
                            title: 'Achievements',
                            icon: Icons.emoji_events_outlined,
                            isVisible: _sectionVisibility['achievements']!,
                            isLoading: _isSavingVisibility,
                            onToggle: (value) {
                              _saveVisibilityToggle('achievements', value);
                            },
                          ),
                          if (_sectionVisibility['achievements']!) ...[
                            const SizedBox(height: 12),
                            _AchievementsSection(
                              achievements: profileProvider.achievements,
                              context: context,
                              onUpdate: () {
                                profileProvider.loadAchievements();
                              },
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Social Links
                          _SectionHeader(
                            title: 'Social Links',
                            icon: Icons.share_outlined,
                            isVisible: _sectionVisibility['social_links']!,
                            isLoading: _isSavingVisibility,
                            onToggle: (value) {
                              _saveVisibilityToggle('social_links', value);
                            },
                          ),
                          if (_sectionVisibility['social_links']!) ...[
                            const SizedBox(height: 12),
                            _SocialLinksSection(user: user, context: context),
                            const SizedBox(height: 40),
                          ],

                          const SizedBox(height: 40),
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

/// Modern Header with back button and refresh
class _ModernHeader extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onRefresh;
  final bool isLoading;

  const _ModernHeader({
    required this.onBack,
    this.onRefresh,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary,
              size: 22,
            ),
            onPressed: onBack,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Edit Profile',
              style: AppTextStyles.headlineMedium(weight: FontWeight.bold),
            ),
          ),
          if (onRefresh != null)
            IconButton(
              icon: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.refresh_rounded,
                      color: AppColors.textPrimary,
                      size: 22,
                    ),
              onPressed: isLoading ? null : onRefresh,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

/// Section Header with Toggle Switch
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isVisible;
  final ValueChanged<bool> onToggle;
  final bool isLoading;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.isVisible,
    required this.onToggle,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accentPrimary, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.headlineSmall(weight: FontWeight.w600),
          ),
        ),
        if (isLoading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else ...[
        Text(
          isVisible ? 'Visible' : 'Hidden',
          style: AppTextStyles.bodySmall(
            color: isVisible ? AppColors.accentPrimary : AppColors.textTertiary,
          ),
        ),
        const SizedBox(width: 8),
        ],
        Switch(
          value: isVisible,
          onChanged: isLoading ? null : onToggle,
          activeColor: AppColors.accentPrimary,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}

/// Profile Picture Section
class _ProfilePictureSection extends StatefulWidget {
  final User user;

  const _ProfilePictureSection({required this.user});

  @override
  State<_ProfilePictureSection> createState() => _ProfilePictureSectionState();
}

class _ProfilePictureSectionState extends State<_ProfilePictureSection> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  final StorageService _storageService = StorageService();
  bool _isUploading = false;

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _isUploading = true;
        });

        // Upload to backend
        try {
          final pictureUrl = await _storageService.uploadProfilePicture(
            File(image.path),
          );

          // Update user in AuthProvider
          final authProvider = context.read<AuthProvider>();
          await authProvider.refreshUser();

          // Clear selected image since it's now uploaded
          if (mounted) {
            setState(() {
              _selectedImage = null;
              _isUploading = false;
            });
          }

          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile picture updated successfully'),
                backgroundColor: AppColors.accentPrimary,
                duration: Duration(seconds: 2),
              ),
            );
      }
    } catch (e) {
          // Show error message
          if (mounted) {
            setState(() {
              _isUploading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload profile picture: ${e.toString()}'),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch AuthProvider to get updated user data
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;
    final profilePicture = currentUser?.profilePicture ?? widget.user.profilePicture;
    
    // Show selected image if uploading, otherwise show profile picture
    final imageToShow = _isUploading 
        ? _selectedImage?.path 
        : (_selectedImage?.path ?? profilePicture);

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: imageToShow == null
                  ? LinearGradient(
                      colors: [
                        AppColors.accentPrimary,
                        AppColors.accentSecondary,
                      ],
                    )
                  : null,
              border: Border.all(
                color: AppColors.accentPrimary.withOpacity(0.3),
                width: 3,
              ),
            ),
            child: _isUploading
                ? ClipOval(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (imageToShow != null && !imageToShow.startsWith('http'))
                          Image.file(File(imageToShow), fit: BoxFit.cover),
                        Container(
                          color: Colors.black.withOpacity(0.5),
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : imageToShow != null
                ? ClipOval(
                    child: imageToShow.startsWith('http')
                        ? CachedNetworkImage(
                            imageUrl: imageToShow,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: AppColors.surface,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 50,
                            ),
                          )
                        : Image.file(File(imageToShow), fit: BoxFit.cover),
                  )
                : Icon(Icons.person, color: Colors.white, size: 50),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: _isUploading ? null : _pickImage,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isUploading 
                      ? AppColors.textSecondary 
                      : AppColors.accentPrimary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.backgroundPrimary,
                    width: 3,
                  ),
                ),
                child: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cover Photo Section
class _CoverPhotoSection extends StatefulWidget {
  final User user;

  const _CoverPhotoSection({required this.user});

  @override
  State<_CoverPhotoSection> createState() => _CoverPhotoSectionState();
}

class _CoverPhotoSectionState extends State<_CoverPhotoSection> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  final ProfileService _profileService = ProfileService();
  bool _isUploading = false;

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _isUploading = true;
        });

        try {
          final response = await _profileService.uploadCoverPhoto(image.path);
          if (response.success && response.data != null) {
            final authProvider = context.read<AuthProvider>();
            // Update immediately for instant UI feedback
            authProvider.updateCoverPhoto(response.data!);
            // Then refresh from server to ensure sync
            await authProvider.refreshUser();
            if (mounted) {
              setState(() {
                _selectedImage = null;
                _isUploading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cover photo updated successfully'),
                  backgroundColor: AppColors.accentPrimary,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } else {
            if (mounted) {
              setState(() {
                _isUploading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(response.error ?? 'Failed to upload cover photo'),
                  backgroundColor: AppColors.error,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _isUploading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload: ${e.toString()}'),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;
    // Prioritize currentUser over widget.user for real-time updates
    final coverPhoto = currentUser?.coverPhoto ?? widget.user.coverPhoto;
    
    // Debug: Log cover photo for troubleshooting
    print('[EditProfile] _CoverPhotoSection - coverPhoto: $coverPhoto');
    print('[EditProfile] _CoverPhotoSection - currentUser.coverPhoto: ${currentUser?.coverPhoto}');
    print('[EditProfile] _CoverPhotoSection - widget.user.coverPhoto: ${widget.user.coverPhoto}');

    return GestureDetector(
      onTap: _isUploading ? null : _pickImage,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: coverPhoto == null && _selectedImage == null
              ? LinearGradient(
                  colors: [
                    AppColors.accentPrimary.withOpacity(0.3),
                    AppColors.accentSecondary.withOpacity(0.3),
                  ],
                )
              : null,
          border: Border.all(
            color: AppColors.accentPrimary.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (coverPhoto != null || _selectedImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _isUploading && _selectedImage != null
                    ? Image.file(_selectedImage!, fit: BoxFit.cover)
                    : coverPhoto != null
                        ? CachedNetworkImage(
                            imageUrl: coverPhoto,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: AppColors.surface,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: AppColors.surface,
                              child: const Icon(
                                Icons.image_not_supported,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                          )
                        : null,
              ),
            if (_isUploading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            if (!_isUploading)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      coverPhoto == null ? Icons.add_photo_alternate : Icons.edit,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      coverPhoto == null ? 'Add Cover Photo' : 'Change Cover Photo',
                      style: AppTextStyles.bodyMedium(color: Colors.white),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Display Name and Username Section
class _DisplayNameUsernameSection extends StatefulWidget {
  final User user;

  const _DisplayNameUsernameSection({required this.user});

  @override
  State<_DisplayNameUsernameSection> createState() => _DisplayNameUsernameSectionState();
}

class _DisplayNameUsernameSectionState extends State<_DisplayNameUsernameSection> {
  final ProfileService _profileService = ProfileService();
  final ApiClient _apiClient = ApiClient();

  Future<void> _editDisplayName() async {
    final controller = TextEditingController(text: widget.user.displayName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Display Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Display Name',
            hintText: 'Enter display name',
          ),
          maxLength: 50,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Display name cannot be empty'),
                    backgroundColor: AppColors.error,
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              Navigator.pop(context, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result != widget.user.displayName) {
      // Show loading indicator
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        // Update display name in database
        final response = await _profileService.updateBasicProfile(displayName: result);
        
        // Close loading dialog
        if (mounted) {
          Navigator.pop(context);
        }

        if (response.success) {
          // Refresh user data from backend to get updated display name
          await context.read<AuthProvider>().refreshUser();
          
          // Update local state immediately for instant UI feedback
          setState(() {
            // The widget will rebuild with updated user from AuthProvider
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Display name updated successfully'),
                backgroundColor: AppColors.accentPrimary,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response.error ?? 'Failed to update display name'),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } catch (e) {
        // Close loading dialog if still open
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  Future<void> _editUsername() async {
    final controller = TextEditingController(text: widget.user.username);
    final passwordController = TextEditingController();
    
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Username'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'New Username',
                hintText: 'Enter new username',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final username = controller.text.trim();
              final password = passwordController.text.trim();
              if (username.isNotEmpty && password.isNotEmpty) {
                Navigator.pop(context, {'username': username, 'password': password});
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      // Verify token exists before making request
      final tokenStorage = TokenStorageService();
      final token = await tokenStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in again. Your session has expired.'),
              backgroundColor: AppColors.error,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      try {
        final response = await _apiClient.post<Map<String, dynamic>>(
          '${ApiConfig.account}/change-username',
          data: {
            'new_username': result['username'],
            'password': result['password'],
          },
          fromJson: (json) => json as Map<String, dynamic>,
        );

        if (response['success'] == true) {
          await context.read<AuthProvider>().refreshUser();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Username changed successfully'),
                backgroundColor: AppColors.accentPrimary,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response['message'] as String? ?? 'Failed to change username'),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser ?? widget.user;

    return Column(
      children: [
        _ModernField(
          label: 'Display Name',
          value: user.displayName,
          icon: Icons.badge_outlined,
          onTap: _editDisplayName,
        ),
        _ModernField(
          label: 'Username',
          value: '@${user.username}',
          icon: Icons.alternate_email,
          onTap: _editUsername,
        ),
      ],
    );
  }
}

/// Basic Info Section
class _BasicInfoSection extends StatefulWidget {
  final User user;
  final BuildContext context;
  final VoidCallback? onUpdate;

  const _BasicInfoSection({
    required this.user,
    required this.context,
    this.onUpdate,
  });

  @override
  State<_BasicInfoSection> createState() => _BasicInfoSectionState();
}

class _BasicInfoSectionState extends State<_BasicInfoSection> {
  final ProfileService _profileService = ProfileService();

  Future<void> _editField(String field, dynamic currentValue) async {
    final result = await _showEditDialog(field, currentValue);
    if (result == null) return;

    try {
      ApiResponse<void> response;
      switch (field) {
        case 'bio':
          response = await _profileService.updateBasicProfile(bio: result as String?);
          break;
        case 'location':
          response = await _profileService.updateBasicProfile(location: result as String?);
          break;
        case 'age':
          response = await _profileService.updateBasicProfile(age: result as int?);
          break;
        case 'gender':
          final genderData = result as Map<String, String?>;
          response = await _profileService.updateBasicProfile(
            gender: genderData['gender'],
            genderCustom: genderData['genderCustom'],
          );
          break;
        case 'website':
          response = await _profileService.updateBasicProfile(website: result as String?);
          break;
        default:
          return;
      }

      if (response.success) {
        await context.read<AuthProvider>().refreshUser();
        widget.onUpdate?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Updated successfully'),
              backgroundColor: AppColors.accentPrimary,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.error ?? 'Failed to update'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<dynamic> _showEditDialog(String field, dynamic currentValue) async {
    final controller = TextEditingController(text: currentValue?.toString() ?? '');
    
    if (field == 'age') {
      return showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Edit Age'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Age'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final age = int.tryParse(controller.text);
                Navigator.pop(context, age);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
    } else if (field == 'gender') {
      String? selectedGender = widget.user.gender;
      String? customGender = widget.user.genderCustom;
      final customController = TextEditingController(text: customGender ?? '');
      
      return showDialog<Map<String, String?>>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Edit Gender'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedGender,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: ['male', 'female', 'non-binary', 'prefer-not-to-say', 'custom']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (value) => setState(() => selectedGender = value),
                ),
                if (selectedGender == 'custom') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: customController,
                    decoration: const InputDecoration(labelText: 'Custom Gender'),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'gender': selectedGender,
                    'genderCustom': selectedGender == 'custom' ? customController.text : null,
                  });
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
    } else {
      return showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Edit ${field[0].toUpperCase()}${field.substring(1)}'),
          content: TextField(
            controller: controller,
            maxLines: field == 'bio' ? 3 : 1,
            maxLength: field == 'bio' ? 150 : null,
            decoration: InputDecoration(
              labelText: field[0].toUpperCase() + field.substring(1),
              hintText: 'Enter ${field}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final value = controller.text.trim();
                Navigator.pop(context, value.isEmpty ? null : value);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser ?? widget.user;

    return Column(
      children: [
        _ModernField(
          label: 'Bio',
          value: user.bio ?? 'Add a bio',
          icon: Icons.description_outlined,
          isPlaceholder: user.bio == null,
          onTap: () => _editField('bio', user.bio),
        ),
        _ModernField(
          label: 'Age',
          value: user.age != null ? '${user.age} years old' : 'Add your age',
          icon: Icons.cake_outlined,
          isPlaceholder: user.age == null,
          onTap: () => _editField('age', user.age),
        ),
        _ModernField(
          label: 'Gender',
          value: _getGenderDisplay(user),
          icon: Icons.person_outline,
          isPlaceholder: user.gender == null,
          onTap: () => _editField('gender', user.gender),
        ),
        _ModernField(
          label: 'Location',
          value: user.location ?? 'Add location',
          icon: Icons.location_on_outlined,
          isPlaceholder: user.location == null,
          onTap: () => _editField('location', user.location),
        ),
        _ModernField(
          label: 'Website',
          value: user.website ?? 'Add website',
          icon: Icons.language,
          isPlaceholder: user.website == null,
          onTap: () => _editField('website', user.website),
        ),
      ],
    );
  }

  String _getGenderDisplay(User user) {
    if (user.gender == null) return 'Add gender';
    if (user.gender == 'custom' && user.genderCustom != null) {
      return user.genderCustom!;
    }
    return user.gender!.substring(0, 1).toUpperCase() +
        user.gender!.substring(1);
  }
}

/// Modern Field Item
class _ModernField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isPlaceholder;
  final VoidCallback? onTap;

  const _ModernField({
    required this.label,
    required this.value,
    required this.icon,
    this.isPlaceholder = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.6 : 1.0,
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accentPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.accentPrimary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodySmall(
                      color: AppColors.textSecondary,
                      weight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: AppTextStyles.bodyMedium(
                      color: isPlaceholder
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
              if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
          ),
        ),
      ),
    );
  }
}

/// Story Section
class _StorySection extends StatelessWidget {
  final User user;
  final BuildContext context;
  final VoidCallback? onUpdate;

  const _StorySection({
    required this.user,
    required this.context,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => this.context.push('/edit-profile/story'),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accentPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.book_outlined,
                color: AppColors.accentPrimary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Story',
                    style: AppTextStyles.bodySmall(
                      color: AppColors.textSecondary,
                      weight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.story ?? 'Tell your story (up to 1000 characters)',
                    style: AppTextStyles.bodyMedium(
                      color: user.story == null
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Experience Section
class _ExperienceSection extends StatelessWidget {
  final BuildContext context;
  final VoidCallback? onUpdate;

  const _ExperienceSection({
    required this.context,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final experiences = profileProvider.experiences;

    return Column(
      children: [
        _AddButton(
          label: 'Add Experience',
          icon: Icons.add_circle_outline_rounded,
          onTap: () => context.push('/edit-profile/experience/add'),
        ),
        if (experiences.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No experiences added yet',
              style: AppTextStyles.bodyMedium(color: AppColors.textTertiary),
            ),
          )
        else
          ...experiences.map(
            (exp) => _ListItem(
              title: exp.title,
              subtitle: '${exp.companyName} • ${_formatDateRange(exp.startDate, exp.endDate, exp.isCurrent)}',
              onTap: () => context.push('/edit-profile/experience/${exp.id}'),
              onDelete: () async {
                await profileProvider.deleteExperience(exp.id);
                onUpdate?.call();
              },
            ),
          ),
      ],
    );
  }

  String _formatDateRange(DateTime start, DateTime? end, bool isCurrent) {
    final startStr = DateFormat('MMM yyyy').format(start);
    if (isCurrent) {
      return '$startStr - Present';
    }
    if (end != null) {
      final endStr = DateFormat('MMM yyyy').format(end);
      return '$startStr - $endStr';
    }
    return startStr;
  }
}

/// Education Section
class _EducationSection extends StatelessWidget {
  final BuildContext context;
  final VoidCallback? onUpdate;

  const _EducationSection({
    required this.context,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final education = profileProvider.education;

    return Column(
      children: [
        _AddButton(
          label: 'Add Education',
          icon: Icons.add_circle_outline_rounded,
          onTap: () => context.push('/edit-profile/education/add'),
        ),
        if (education.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No education added yet',
              style: AppTextStyles.bodyMedium(color: AppColors.textTertiary),
            ),
          )
        else
          ...education.map(
            (edu) => _ListItem(
              title: edu.schoolName,
              subtitle: '${edu.degree ?? ''}${edu.degree != null && edu.fieldOfStudy != null ? ' in ' : ''}${edu.fieldOfStudy ?? ''} • ${_formatDateRange(edu.startDate, edu.endDate, edu.isCurrent)}',
              onTap: () => context.push('/edit-profile/education/${edu.id}'),
              onDelete: () async {
                await profileProvider.deleteEducation(edu.id);
                onUpdate?.call();
              },
            ),
          ),
      ],
    );
  }

  String _formatDateRange(DateTime start, DateTime? end, bool isCurrent) {
    final startStr = DateFormat('MMM yyyy').format(start);
    if (isCurrent) {
      return '$startStr - Present';
    }
    if (end != null) {
      final endStr = DateFormat('MMM yyyy').format(end);
      return '$startStr - $endStr';
    }
    return startStr;
  }
}

/// Skills Section
class _SkillsSection extends StatelessWidget {
  final List<Skill> skills;
  final BuildContext context;
  final VoidCallback? onUpdate;

  const _SkillsSection({
    required this.skills,
    required this.context,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AddButton(
          label: 'Add Skill',
          icon: Icons.add_circle_outline_rounded,
          onTap: () => context.push('/edit-profile/skills/add'),
        ),
        if (skills.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No skills added yet',
              style: AppTextStyles.bodyMedium(color: AppColors.textTertiary),
            ),
          )
        else
          ...skills.map(
            (skill) => _ListItem(
              title: skill.skillName,
              subtitle: skill.proficiencyLevel,
              onTap: () => context.push('/edit-profile/skills/${skill.id}'),
            ),
          ),
      ],
    );
  }
}

/// Certifications Section
class _CertificationsSection extends StatelessWidget {
  final List<Certification> certifications;
  final BuildContext context;
  final VoidCallback? onUpdate;

  const _CertificationsSection({
    required this.certifications,
    required this.context,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AddButton(
          label: 'Add Certification',
          icon: Icons.add_circle_outline_rounded,
          onTap: () => context.push('/edit-profile/certifications/add'),
        ),
        if (certifications.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No certifications added yet',
              style: AppTextStyles.bodyMedium(color: AppColors.textTertiary),
            ),
          )
        else
          ...certifications.map(
            (cert) => _ListItem(
              title: cert.name,
              subtitle: cert.issuingOrganization,
              onTap: () =>
                  context.push('/edit-profile/certifications/${cert.id}'),
            ),
          ),
      ],
    );
  }
}

/// Languages Section
class _LanguagesSection extends StatelessWidget {
  final List<Language> languages;
  final BuildContext context;
  final VoidCallback? onUpdate;

  const _LanguagesSection({
    required this.languages,
    required this.context,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AddButton(
          label: 'Add Language',
          icon: Icons.add_circle_outline_rounded,
          onTap: () => context.push('/edit-profile/languages/add'),
        ),
        if (languages.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No languages added yet',
              style: AppTextStyles.bodyMedium(color: AppColors.textTertiary),
            ),
          )
        else
          ...languages.map(
            (lang) => _ListItem(
              title: lang.languageName,
              subtitle: lang.proficiencyLevel,
              onTap: () => context.push('/edit-profile/languages/${lang.id}'),
            ),
          ),
      ],
    );
  }
}

/// Volunteering Section
class _VolunteeringSection extends StatelessWidget {
  final List<Volunteering> volunteering;
  final BuildContext context;
  final VoidCallback? onUpdate;

  const _VolunteeringSection({
    required this.volunteering,
    required this.context,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AddButton(
          label: 'Add Volunteering',
          icon: Icons.add_circle_outline_rounded,
          onTap: () => context.push('/edit-profile/volunteering/add'),
        ),
        if (volunteering.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No volunteering added yet',
              style: AppTextStyles.bodyMedium(color: AppColors.textTertiary),
            ),
          )
        else
          ...volunteering.map(
            (vol) => _ListItem(
              title: '${vol.role} at ${vol.organizationName}',
              subtitle:
                  '${vol.startDate.year}${vol.endDate != null
                      ? ' - ${vol.endDate!.year}'
                      : vol.isCurrent
                      ? ' - Present'
                      : ''}',
              onTap: () => context.push('/edit-profile/volunteering/${vol.id}'),
            ),
          ),
      ],
    );
  }
}

/// Publications Section
class _PublicationsSection extends StatelessWidget {
  final List<Publication> publications;
  final BuildContext context;
  final VoidCallback? onUpdate;

  const _PublicationsSection({
    required this.publications,
    required this.context,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AddButton(
          label: 'Add Publication',
          icon: Icons.add_circle_outline_rounded,
          onTap: () => context.push('/edit-profile/publications/add'),
        ),
        if (publications.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No publications added yet',
              style: AppTextStyles.bodyMedium(color: AppColors.textTertiary),
            ),
          )
        else
          ...publications.map(
            (pub) => _ListItem(
              title: pub.title,
              subtitle: pub.publisher,
              onTap: () => context.push('/edit-profile/publications/${pub.id}'),
            ),
          ),
      ],
    );
  }
}

/// Interests Section
class _InterestsSection extends StatelessWidget {
  final List<Interest> interests;
  final BuildContext context;
  final VoidCallback? onUpdate;

  const _InterestsSection({
    required this.interests,
    required this.context,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AddButton(
          label: 'Add Interest',
          icon: Icons.add_circle_outline_rounded,
          onTap: () => context.push('/edit-profile/interests/add'),
        ),
        if (interests.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No interests added yet',
              style: AppTextStyles.bodyMedium(color: AppColors.textTertiary),
            ),
          )
        else
          ...interests.map(
            (interest) => _ListItem(
              title: interest.interestName,
              subtitle: interest.category,
              onTap: () =>
                  context.push('/edit-profile/interests/${interest.id}'),
            ),
          ),
      ],
    );
  }
}

/// Achievements Section
class _AchievementsSection extends StatelessWidget {
  final List<Achievement> achievements;
  final BuildContext context;
  final VoidCallback? onUpdate;

  const _AchievementsSection({
    required this.achievements,
    required this.context,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AddButton(
          label: 'Add Achievement',
          icon: Icons.add_circle_outline_rounded,
          onTap: () => context.push('/edit-profile/achievements/add'),
        ),
        if (achievements.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No achievements added yet',
              style: AppTextStyles.bodyMedium(color: AppColors.textTertiary),
            ),
          )
        else
          ...achievements.map(
            (achievement) => _ListItem(
              title: achievement.title,
              subtitle: achievement.issuingOrganization,
              onTap: () =>
                  context.push('/edit-profile/achievements/${achievement.id}'),
            ),
          ),
      ],
    );
  }
}

/// Social Links Section
class _SocialLinksSection extends StatelessWidget {
  final User user;
  final BuildContext context;

  const _SocialLinksSection({required this.user, required this.context});

  @override
  Widget build(BuildContext context) {
    final socialLinks = user.socialLinks;
    final count = socialLinks != null
        ? socialLinks.values
              .where((link) => link != null && link.isNotEmpty)
              .length
        : 0;

    return InkWell(
      onTap: () => context.push('/settings/profile/social-links'),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accentPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.share_outlined,
                color: AppColors.accentPrimary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Social Media',
                    style: AppTextStyles.bodySmall(
                      color: AppColors.textSecondary,
                      weight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    count > 0
                        ? '$count social link${count != 1 ? 's' : ''} connected'
                        : 'Add social media links',
                    style: AppTextStyles.bodyMedium(
                      color: count > 0
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Modern List Item
class _ListItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _ListItem({
    required this.title,
    this.subtitle,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodyMedium()),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: AppTextStyles.bodySmall(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                  size: 20,
                ),
                onPressed: onDelete,
                tooltip: 'Delete',
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Add Button
class _AddButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _AddButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.accentPrimary.withOpacity(0.3),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.accentPrimary, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.bodyMedium(
                color: AppColors.accentPrimary,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
