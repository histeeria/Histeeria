import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../posts/data/services/posts_service.dart';
import '../../../feed/data/providers/feed_provider.dart';
import '../../../auth/data/providers/auth_provider.dart';

class CreateArticleScreen extends StatefulWidget {
  const CreateArticleScreen({super.key});

  @override
  State<CreateArticleScreen> createState() => _CreateArticleScreenState();
}

class _CreateArticleScreenState extends State<CreateArticleScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subtitleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final PostsService _postsService = PostsService();
  final ImagePicker _imagePicker = ImagePicker();
  String _selectedCategory = 'Technology';
  File? _coverImageFile;
  String? _coverImageUrl;
  bool _isPosting = false;
  bool _isUploadingCover = false;
  double _coverUploadProgress = 0.0;

  final List<String> _categories = [
    'Technology',
    'Science',
    'Business',
    'Health',
    'Education',
    'Entertainment',
    'Sports',
    'Politics',
    'Travel',
    'Food',
    'Lifestyle',
    'Other',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _coverImageFile = File(image.path);
          _coverImageUrl = null; // Reset URL until uploaded
        });
      }
    } catch (e) {
      _showMessage('Failed to pick image: ${e.toString()}');
    }
  }

  Future<void> _takeCoverPhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _coverImageFile = File(image.path);
          _coverImageUrl = null; // Reset URL until uploaded
        });
      }
    } catch (e) {
      _showMessage('Failed to take photo: ${e.toString()}');
    }
  }

  void _showCoverImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundSecondary.withOpacity(0.95),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.accentPrimary),
              title: Text(
                'Choose from Gallery',
                style: AppTextStyles.bodyMedium(),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickCoverImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.accentPrimary),
              title: Text(
                'Take Photo',
                style: AppTextStyles.bodyMedium(),
              ),
              onTap: () {
                Navigator.pop(context);
                _takeCoverPhoto();
              },
            ),
            if (_coverImageFile != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(
                  'Remove Cover Image',
                  style: AppTextStyles.bodyMedium(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _coverImageFile = null;
                    _coverImageUrl = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
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

  Future<void> _publishArticle() async {
    if (_titleController.text.trim().isEmpty) {
      _showMessage('Please add a title');
      return;
    }

    if (_contentController.text.trim().isEmpty) {
      _showMessage('Please add content');
      return;
    }

    setState(() {
      _isPosting = true;
      _isUploadingCover = _coverImageFile != null;
      _coverUploadProgress = 0.0;
    });

    try {
      String? coverImageUrl = _coverImageUrl;

      // Upload cover image if selected
      if (_coverImageFile != null && coverImageUrl == null) {
        setState(() {
          _isUploadingCover = true;
        });

        final uploadResponse = await _postsService.uploadImage(
          _coverImageFile!.path,
          onProgress: (sent, total) {
            setState(() {
              _coverUploadProgress = sent / total;
            });
          },
        );

        if (uploadResponse.success && uploadResponse.data != null) {
          coverImageUrl = uploadResponse.data!['url'] as String?;
        } else {
          throw Exception(uploadResponse.error ?? 'Failed to upload cover image');
        }
      }

      // Convert plain text to HTML (basic conversion)
      final contentHtml = _contentController.text
          .split('\n')
          .map((line) => line.isEmpty ? '<br>' : '<p>$line</p>')
          .join('');

      // Parse tags
      final tags = _tagsController.text
          .trim()
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .take(5)
          .toList();

      final articleData = {
        'title': _titleController.text.trim(),
        'subtitle': _subtitleController.text.trim().isNotEmpty
            ? _subtitleController.text.trim()
            : null,
        'content_html': contentHtml,
        'cover_image_url': coverImageUrl,
        'category': _selectedCategory,
        if (tags.isNotEmpty) 'tags': tags,
      };

      final response = await _postsService.createPost(
        postType: 'article',
        content: _titleController.text.trim(), // Use title as content
        visibility: 'public',
        allowsComments: true,
        allowsSharing: true,
        article: articleData,
      );

      if (response.success && response.data != null) {
        // Refresh feed
        final feedProvider = Provider.of<FeedProvider>(context, listen: false);
        await feedProvider.refresh();

        _showMessage('Article published successfully');
        Navigator.pop(context);
      } else {
        _showMessage(response.error ?? 'Failed to publish article');
      }
    } catch (e) {
      _showMessage('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
          _isUploadingCover = false;
          _coverUploadProgress = 0.0;
        });
      }
    }
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
                      'Write Article',
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
                    
                    // Cover Image
                    GestureDetector(
                      onTap: _showCoverImageOptions,
                      child: Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSecondary.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.glassBorder.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: _coverImageFile != null
                            ? Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.file(
                                      _coverImageFile!,
                                      width: double.infinity,
                                      height: 200,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  if (_isUploadingCover)
                                    Container(
                                      color: Colors.black.withOpacity(0.5),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            CircularProgressIndicator(
                                              value: _coverUploadProgress > 0
                                                  ? _coverUploadProgress
                                                  : null,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Uploading...',
                                              style: AppTextStyles.bodySmall(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.close, color: Colors.white),
                                        onPressed: () {
                                          setState(() {
                                            _coverImageFile = null;
                                            _coverImageUrl = null;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 48,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Add Cover Image',
                                    style: AppTextStyles.bodyMedium(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap to choose from gallery or camera',
                                    style: AppTextStyles.bodySmall(
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Title
                    TextField(
                      controller: _titleController,
                      maxLength: 100,
                      style: AppTextStyles.headlineMedium(
                        weight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Article Title',
                        hintStyle: AppTextStyles.headlineMedium(
                          color: AppColors.textTertiary,
                        ),
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Subtitle
                    TextField(
                      controller: _subtitleController,
                      maxLength: 150,
                      style: AppTextStyles.headlineSmall(
                        color: AppColors.textSecondary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Subtitle (optional)',
                        hintStyle: AppTextStyles.headlineSmall(
                          color: AppColors.textTertiary,
                        ),
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Category Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        isExpanded: true,
                        underline: const SizedBox(),
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: AppColors.accentPrimary,
                        ),
                        style: AppTextStyles.bodySmall(
                          color: AppColors.accentPrimary,
                          weight: FontWeight.w600,
                        ),
                        items: _categories.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                      child: Row(
                        children: [
                          Icon(
                            Icons.category_outlined,
                            size: 16,
                            color: AppColors.accentPrimary,
                          ),
                                const SizedBox(width: 8),
                                Text(category),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedCategory = newValue;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Content
                    TextField(
                      controller: _contentController,
                      maxLines: 15,
                      style: AppTextStyles.bodyLarge(),
                      decoration: InputDecoration(
                        hintText: 'Start writing your article...',
                        hintStyle: AppTextStyles.bodyLarge(
                          color: AppColors.textTertiary,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Tags Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tags',
                          style: AppTextStyles.bodyMedium(
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundSecondary.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.glassBorder.withOpacity(0.2),
                              width: 0.5,
                            ),
                          ),
                          child: TextField(
                            controller: _tagsController,
                            style: AppTextStyles.bodyMedium(),
                            decoration: InputDecoration(
                              hintText: 'e.g., technology, programming, flutter',
                              hintStyle: AppTextStyles.bodyMedium(
                                color: AppColors.textTertiary,
                              ),
                              border: InputBorder.none,
                              prefixIcon: Icon(
                                Icons.tag_outlined,
                                size: 20,
                                color: AppColors.textSecondary,
                              ),
                              isDense: true,
                            ),
                            onChanged: (value) {
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Display tags as chips
                        if (_tagsController.text.trim().isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _tagsController.text
                                .split(',')
                                .map((tag) => tag.trim())
                                .where((tag) => tag.isNotEmpty)
                                .take(5)
                                .map((tag) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentPrimary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.accentPrimary.withOpacity(0.3),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          tag,
                                          style: AppTextStyles.bodySmall(
                                            color: AppColors.accentPrimary,
                                            weight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        GestureDetector(
                                          onTap: () {
                                            final tags = _tagsController.text
                                                .split(',')
                                                .map((t) => t.trim())
                                                .where((t) => t.isNotEmpty && t != tag)
                                                .join(', ');
                                            _tagsController.text = tags;
                                            setState(() {});
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
                                })
                                .toList(),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          'Separate tags with commas (max 5 tags)',
                          style: AppTextStyles.bodySmall(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
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
                    onPressed: _isPosting ? null : _publishArticle,
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
                            'Publish Article',
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

