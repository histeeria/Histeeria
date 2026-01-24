import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../statuses/data/services/status_service.dart';
import '../../../feed/data/providers/feed_provider.dart';

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final StatusService _statusService = StatusService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _textController = TextEditingController();
  bool _hasMedia = false;
  String? _mediaUrl;
  String? _mediaType;
  File? _mediaFile;
  String _statusType = 'text'; // 'text', 'image', 'video'
  String _backgroundColor = '#1a1f3a';
  final List<String> _backgroundColors = [
    '#1a1f3a', // Dark blue
    '#FF6B6B', // Red
    '#4ECDC4', // Teal
    '#45B7D1', // Blue
    '#FFA07A', // Light salmon
    '#98D8C8', // Mint
    '#F7DC6F', // Yellow
    '#BB8FCE', // Purple
  ];
  bool _isPosting = false;
  double _uploadProgress = 0.0;

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

  Future<void> _publishStory() async {
    if (_statusType == 'text' && _textController.text.trim().isEmpty) {
      _showMessage('Please add text or media');
      return;
    }

    if ((_statusType == 'image' || _statusType == 'video') && !_hasMedia) {
      _showMessage('Please add a photo or video');
      return;
    }

    setState(() {
      _isPosting = true;
      _uploadProgress = 0.0;
    });

    try {
      String? finalMediaUrl = _mediaUrl;
      String? finalMediaType = _mediaType;

      // Upload media if we have a file but no URL yet
      if (_statusType != 'text' && _mediaFile != null && (_mediaUrl == null || _mediaUrl!.isEmpty)) {
        final uploadResponse = await _statusService.uploadStatusMedia(
          _mediaFile!.path,
          onProgress: (sent, total) {
            setState(() {
              _uploadProgress = sent / total;
            });
          },
        );

        if (uploadResponse.success && uploadResponse.data != null) {
          finalMediaUrl = uploadResponse.data!['url'] as String? ?? '';
          finalMediaType = _statusType == 'video' ? 'video/mp4' : 'image/jpeg';
        } else {
          throw Exception(uploadResponse.error ?? 'Failed to upload media');
        }
      }

      final response = await _statusService.createStatus(
        statusType: _statusType,
        content: _statusType == 'text' ? _textController.text.trim() : null,
        mediaUrl: finalMediaUrl,
        mediaType: finalMediaType,
        backgroundColor: _statusType == 'text' ? _backgroundColor : null,
      );

      if (response.success && response.data != null) {
        // Refresh statuses
        final feedProvider = Provider.of<FeedProvider>(context, listen: false);
        await feedProvider.loadStatuses();

        _showMessage('Story published successfully');
        Navigator.pop(context);
      } else {
        _showMessage(response.error ?? 'Failed to publish story');
      }
    } catch (e) {
      _showMessage('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  Future<void> _pickMedia(ImageSource source, {bool isVideo = false}) async {
    try {
      if (isVideo) {
        final XFile? video = await _imagePicker.pickVideo(
          source: source,
          maxDuration: const Duration(seconds: 60), // Stories are short
        );

        if (video != null) {
          setState(() {
            _mediaFile = File(video.path);
            _hasMedia = true;
            _mediaType = 'video';
            _statusType = 'video';
          });
        }
      } else {
        final XFile? image = await _imagePicker.pickImage(
          source: source,
          imageQuality: 90,
          maxWidth: 1080,
          maxHeight: 1920,
        );

        if (image != null) {
          setState(() {
            _mediaFile = File(image.path);
            _hasMedia = true;
            _mediaType = 'image';
            _statusType = 'image';
          });
        }
      }
    } catch (e) {
      _showMessage('Failed to pick media: ${e.toString()}');
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
                      'Create Story',
                      style: AppTextStyles.headlineMedium(
                        weight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _statusType == 'text'
                      ? Column(
                          children: [
                            // Text Input with Background Color
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Color(int.parse(_backgroundColor.replaceFirst('#', '0xff'))),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.all(24),
                                child: Center(
                                  child: TextField(
                                    controller: _textController,
                                    maxLength: 500,
                                    maxLines: null,
                                    textAlign: TextAlign.center,
                                    expands: true,
                                    style: AppTextStyles.headlineMedium(
                                      color: Colors.white,
                                      weight: FontWeight.bold,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Type your story...',
                                      hintStyle: AppTextStyles.headlineMedium(
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                      border: InputBorder.none,
                                      counterText: '',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Background Color Picker
                            SizedBox(
                              height: 60,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _backgroundColors.length,
                                itemBuilder: (context, index) {
                                  final color = _backgroundColors[index];
                                  final isSelected = _backgroundColor == color;
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _backgroundColor = color;
                                      });
                                    },
                                    child: Container(
                                      width: 50,
                                      height: 50,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        color: Color(int.parse(color.replaceFirst('#', '0xff'))),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.transparent,
                                          width: 3,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 24,
                                            )
                                          : null,
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Switch to Media
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                            TextButton.icon(
                                  onPressed: () => _pickMedia(ImageSource.gallery, isVideo: false),
                              icon: const Icon(Icons.photo_library_outlined),
                                  label: const Text('Photo'),
                                ),
                                TextButton.icon(
                                  onPressed: () => _pickMedia(ImageSource.gallery, isVideo: true),
                                  icon: const Icon(Icons.videocam_outlined),
                                  label: const Text('Video'),
                                ),
                                TextButton.icon(
                                  onPressed: () => _pickMedia(ImageSource.camera, isVideo: false),
                                  icon: const Icon(Icons.camera_alt_outlined),
                                  label: const Text('Camera'),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
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
                                          ListTile(
                                            leading: Icon(Icons.photo_library_outlined, color: AppColors.accentPrimary),
                                            title: Text('Choose Photo', style: AppTextStyles.bodyMedium()),
                                            onTap: () {
                                              Navigator.pop(context);
                                              _pickMedia(ImageSource.gallery, isVideo: false);
                                            },
                                          ),
                                          ListTile(
                                            leading: Icon(Icons.camera_alt_outlined, color: AppColors.accentPrimary),
                                            title: Text('Take Photo', style: AppTextStyles.bodyMedium()),
                                            onTap: () {
                                              Navigator.pop(context);
                                              _pickMedia(ImageSource.camera, isVideo: false);
                                            },
                                          ),
                                          ListTile(
                                            leading: Icon(Icons.videocam_outlined, color: AppColors.accentSecondary),
                                            title: Text('Choose Video', style: AppTextStyles.bodyMedium()),
                                            onTap: () {
                                              Navigator.pop(context);
                                              _pickMedia(ImageSource.gallery, isVideo: true);
                                            },
                                          ),
                                          ListTile(
                                            leading: Icon(Icons.videocam, color: AppColors.accentSecondary),
                                            title: Text('Record Video', style: AppTextStyles.bodyMedium()),
                          onTap: () {
                                              Navigator.pop(context);
                                              _pickMedia(ImageSource.camera, isVideo: true);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.accentPrimary.withOpacity(0.3),
                                  AppColors.accentSecondary.withOpacity(0.3),
                                  AppColors.accentTertiary.withOpacity(0.3),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.accentPrimary.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                                  child: _hasMedia && _mediaFile != null
                                      ? Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(20),
                                              child: _statusType == 'video'
                                                  ? Container(
                                                      color: Colors.black,
                                                      child: Center(
                                                        child: Icon(
                                                          Icons.play_circle_outline,
                                                          size: 64,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    )
                                                  : Image.file(
                                                      _mediaFile!,
                                                      fit: BoxFit.cover,
                                                      width: double.infinity,
                                                      height: double.infinity,
                                                    ),
                                            ),
                                            if (_isPosting && _uploadProgress > 0 && _uploadProgress < 1)
                                              Positioned.fill(
                                                child: Container(
                                                  color: Colors.black.withOpacity(0.5),
                            child: Center(
                                                    child: CircularProgressIndicator(
                                                      value: _uploadProgress,
                                                      valueColor: AlwaysStoppedAnimation<Color>(
                                                        AppColors.accentPrimary,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            Positioned(
                                              top: 16,
                                              right: 16,
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _hasMedia = false;
                                                    _mediaFile = null;
                                                    _mediaUrl = null;
                                                    _mediaType = null;
                                                  });
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withOpacity(0.6),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.accentPrimary,
                                          AppColors.accentSecondary,
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                                  Icons.add_photo_alternate_outlined,
                                      size: 56,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                                'Tap to add photo or video',
                                    style: AppTextStyles.headlineSmall(
                                      weight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Stories disappear after 24 hours',
                                    style: AppTextStyles.bodyMedium(
                                      color: AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _statusType = 'text';
                                        _hasMedia = false;
                                  _mediaFile = null;
                                      });
                                    },
                                    icon: const Icon(Icons.text_fields),
                                    label: const Text('Create Text Story'),
                                  ),
                                ],
                        ),
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
                    onPressed: _isPosting ? null : _publishStory,
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
                            'Share Story',
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

