import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart' as audio;
import '../../../../core/theme/app_colors.dart';
import '../../data/services/audio_service.dart';
import '../../data/services/messages_service.dart';
import '../../data/services/file_storage_service.dart';
import '../../data/models/message.dart';

/// WhatsApp-like audio message bubble with waveform and playback controls
class AudioMessageBubble extends StatefulWidget {
  final String messageId;
  final String? attachmentUrl;
  final int? attachmentSize; // Duration in seconds
  final bool isMe;
  final DateTime timestamp;
  final MessageStatus? status;

  const AudioMessageBubble({
    Key? key,
    required this.messageId,
    this.attachmentUrl,
    this.attachmentSize,
    required this.isMe,
    required this.timestamp,
    this.status,
  }) : super(key: key);

  @override
  State<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<AudioMessageBubble> {
  final AudioService _audioService = AudioService();
  final MessagesService _messagesService = MessagesService();
  final FileStorageService _fileStorage = FileStorageService();
  
  bool _isLoading = false;
  bool _isDownloading = false;
  bool _isPlaying = false;
  bool _hasError = false;
  double _playbackSpeed = 1.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _localFilePath;
  String? _signedUrl;
  String? _errorMessage;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<audio.PlayerState>? _stateSubscription;
  List<double> _waveform = [];

  @override
  void initState() {
    super.initState();
    _initializeAudio();
    _setupAudioListeners();
  }

  Future<void> _initializeAudio() async {
    // Set initial duration from attachmentSize if available
    if (widget.attachmentSize != null && widget.attachmentSize! > 0) {
      setState(() {
        _duration = Duration(seconds: widget.attachmentSize!);
      });
    }

    // Generate placeholder waveform immediately
    _generatePlaceholderWaveform();

    // Check if file is already downloaded
    final isDownloaded = await _fileStorage.isFileDownloaded(widget.messageId);
    if (isDownloaded) {
      final file = await _fileStorage.getDownloadedFile(widget.messageId);
      if (file != null && await file.exists()) {
        setState(() {
          _localFilePath = file.path;
        });
        await _loadDuration();
        await _generateWaveform();
        return;
      }
    }

    // Always try to get signed URL - backend fetches from DB using messageId
    // Don't depend on widget.attachmentUrl which might be null or relative path
    await _downloadAndPrepare();
  }

  void _setupAudioListeners() {
    _positionSubscription = _audioService.playbackPositionStream.listen((position) {
      if (mounted && _audioService.currentPlayingId == widget.messageId) {
        setState(() {
          _position = position;
        });
      }
    });

    _stateSubscription = _audioService.playbackStateStream.listen((state) {
      if (mounted && _audioService.currentPlayingId == widget.messageId) {
        setState(() {
          _isPlaying = state == audio.PlayerState.playing;
          if (state == audio.PlayerState.completed) {
            _isPlaying = false;
            _position = Duration.zero;
          }
        });
      } else if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    });
  }

  Future<void> _downloadAndPrepare() async {
    if (_isDownloading || _localFilePath != null) return;

    setState(() {
      _isDownloading = true;
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      // Get signed URL from backend
      print('[AudioMessageBubble] Getting signed URL for message: ${widget.messageId}');
      final signedUrlResponse = await _messagesService.getFileSignedUrl(widget.messageId);
      
      if (!signedUrlResponse.success || signedUrlResponse.data == null) {
        print('[AudioMessageBubble] Failed to get signed URL: ${signedUrlResponse.error}');
        throw Exception(signedUrlResponse.error ?? 'Failed to get download URL');
      }

      final signedUrl = signedUrlResponse.data!;
      print('[AudioMessageBubble] Got signed URL: ${signedUrl.substring(0, signedUrl.length > 100 ? 100 : signedUrl.length)}...');
      
      // Validate signed URL format
      if (!signedUrl.startsWith('http://') && !signedUrl.startsWith('https://')) {
        throw Exception('Invalid signed URL format: $signedUrl');
      }
      
      _signedUrl = signedUrl;

      // Try to download file for offline access (optional)
      // But we can also use the signed URL directly for playback
      try {
        final file = await _fileStorage.downloadFile(
          widget.messageId,
          signedUrl,
          onProgress: (received, total) {
            // Could show download progress if needed
          },
        );

        if (file != null && await file.exists()) {
          _localFilePath = file.path;
        }
      } catch (downloadError) {
        // Download failed, but we can still use signed URL for playback
        print('[AudioMessageBubble] Download failed, will use signed URL: $downloadError');
      }

      // Load duration using signed URL (works for both local and remote)
      // Only load duration if we have a source
      if (_localFilePath != null || _signedUrl != null) {
        await _loadDuration();
        await _generateWaveform();
      }

      setState(() {
        _isDownloading = false;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('[AudioMessageBubble] Error preparing audio: $e');
      print('[AudioMessageBubble] Stack trace: $stackTrace');
      setState(() {
        _isDownloading = false;
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadDuration() async {
    try {
      Duration? duration;
      
      // Try local file first
      if (_localFilePath != null) {
        print('[AudioMessageBubble] Loading duration from local file: $_localFilePath');
        duration = await _audioService.getDuration(_localFilePath!);
        print('[AudioMessageBubble] Local file duration: $duration');
      }
      
      // If no local file or duration failed, try signed URL
      if ((duration == null || duration == Duration.zero) && _signedUrl != null) {
        print('[AudioMessageBubble] Loading duration from signed URL');
        try {
          duration = await _audioService.getDurationFromUrl(_signedUrl!);
          print('[AudioMessageBubble] Signed URL duration: $duration');
        } catch (e) {
          print('[AudioMessageBubble] Failed to get duration from URL: $e');
          // Continue without duration - we'll use attachmentSize as fallback
        }
      }
      
      // Fallback to attachmentSize if available
      if ((duration == null || duration == Duration.zero) && widget.attachmentSize != null && widget.attachmentSize! > 0) {
        duration = Duration(seconds: widget.attachmentSize!);
      }
      
      if (duration != null && duration != Duration.zero && mounted) {
        setState(() {
          _duration = duration!;
        });
      }
    } catch (e) {
      print('[AudioMessageBubble] Error loading duration: $e');
      // Use attachmentSize as fallback
      if (widget.attachmentSize != null && widget.attachmentSize! > 0) {
        setState(() {
          _duration = Duration(seconds: widget.attachmentSize!);
        });
      }
    }
  }

  void _generatePlaceholderWaveform() {
    // Generate a more realistic-looking waveform pattern
    final random = math.Random(widget.messageId.hashCode);
    _waveform = List.generate(50, (index) {
      // Create a pattern that looks more like real audio
      final base = 0.3 + (random.nextDouble() * 0.4);
      final variation = math.sin(index * 0.3) * 0.2;
      return (base + variation).clamp(0.1, 0.9);
    });
  }

  Future<void> _generateWaveform() async {
    // For now, use placeholder waveform
    // Real waveform generation would require audio processing
    // which can be added later with audio_waveforms package
    _generatePlaceholderWaveform();
  }

  Future<void> _togglePlayback() async {
    if (_hasError) {
      // Retry preparation on error
      await _downloadAndPrepare();
      return;
    }

    // Ensure we have a signed URL or local file
    if (_signedUrl == null && _localFilePath == null) {
      await _downloadAndPrepare();
      if (_signedUrl == null && _localFilePath == null) {
        setState(() {
          _hasError = true;
          _errorMessage = 'No audio source available';
        });
        return;
      }
    }

    try {
      if (_isPlaying) {
        print('[AudioMessageBubble] Pausing playback');
        await _audioService.pauseAudio();
      } else {
        if (_audioService.currentPlayingId == widget.messageId) {
          print('[AudioMessageBubble] Resuming playback');
          await _audioService.resumeAudio();
        } else {
          // Use local file if available, otherwise use signed URL
          if (_localFilePath != null) {
            print('[AudioMessageBubble] Playing from local file: $_localFilePath');
            await _audioService.playAudio(
              widget.messageId,
              _localFilePath!,
              speed: _playbackSpeed,
            );
          } else if (_signedUrl != null) {
            print('[AudioMessageBubble] Playing from signed URL: ${_signedUrl!.substring(0, _signedUrl!.length > 80 ? 80 : _signedUrl!.length)}...');
            try {
              await _audioService.playAudioFromUrl(
                widget.messageId,
                _signedUrl!,
                speed: _playbackSpeed,
              );
            } catch (playError) {
              print('[AudioMessageBubble] Failed to play from signed URL: $playError');
              // Try to re-fetch signed URL - it might have expired
              await _downloadAndPrepare();
              if (_signedUrl != null) {
                await _audioService.playAudioFromUrl(
                  widget.messageId,
                  _signedUrl!,
                  speed: _playbackSpeed,
                );
              } else {
                throw playError;
              }
            }
          } else {
            print('[AudioMessageBubble] No audio source available');
            setState(() {
              _hasError = true;
              _errorMessage = 'No audio source available. Please retry.';
            });
            return;
          }
        }
      }
    } catch (e, stackTrace) {
      print('[AudioMessageBubble] Error toggling playback: $e');
      print('[AudioMessageBubble] Stack trace: $stackTrace');
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to play audio: ${e.toString()}';
      });
    }
  }

  Future<void> _seekToPosition(double position) async {
    if (_duration == Duration.zero) return;
    if (_localFilePath == null && _signedUrl == null) return;
    
    final seekPosition = Duration(
      milliseconds: (_duration.inMilliseconds * position).round(),
    );
    
    try {
      await _audioService.seekTo(seekPosition);
      setState(() {
        _position = seekPosition;
      });
    } catch (e) {
      print('[AudioMessageBubble] Error seeking: $e');
    }
  }

  Future<void> _changeSpeed() async {
    final speeds = [1.0, 1.5, 2.0];
    final currentIndex = speeds.indexOf(_playbackSpeed);
    final nextIndex = (currentIndex + 1) % speeds.length;
    final newSpeed = speeds[nextIndex];

    setState(() {
      _playbackSpeed = newSpeed;
    });

    if (_isPlaying && (_localFilePath != null || _signedUrl != null)) {
      await _audioService.setPlaybackSpeed(newSpeed);
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _stateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = widget.isMe
        ? AppColors.accentPrimary
        : AppColors.backgroundSecondary;
    final textColor = widget.isMe ? Colors.white : AppColors.textPrimary;
    final iconColor = widget.isMe ? Colors.white : AppColors.accentPrimary;

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: widget.isMe ? const Radius.circular(12) : const Radius.circular(4),
            bottomRight: widget.isMe ? const Radius.circular(4) : const Radius.circular(12),
          ),
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Play/Pause button
              GestureDetector(
                onTap: _isLoading ? null : _togglePlayback,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: _isLoading || _isDownloading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                          ),
                        )
                      : _hasError
                          ? GestureDetector(
                              onTap: () {
                                // Retry on error tap
                                setState(() {
                                  _hasError = false;
                                  _errorMessage = null;
                                });
                                _downloadAndPrepare();
                              },
                              child: Icon(
                                Icons.refresh,
                                color: Colors.red,
                                size: 22,
                              ),
                            )
                          : Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              color: iconColor,
                              size: 22,
                            ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Waveform and progress
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Waveform visualization
                    GestureDetector(
                      onTapDown: (details) {
                        if (_duration == Duration.zero || (_localFilePath == null && _signedUrl == null)) return;
                        final box = context.findRenderObject() as RenderBox?;
                        if (box == null) return;
                        final localX = details.localPosition.dx;
                        final width = box.size.width - 24;
                        final position = (localX / width).clamp(0.0, 1.0);
                        _seekToPosition(position);
                      },
                      child: SizedBox(
                        height: 32,
                        child: _buildWaveform(textColor, iconColor),
                      ),
                    ),
                    const SizedBox(height: 6),
                    
                    // Duration and position
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: textColor.withOpacity(0.8),
                          ),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: textColor.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Speed button
              GestureDetector(
                onTap: _changeSpeed,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_playbackSpeed}x',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: iconColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildWaveform(Color textColor, Color iconColor) {
    if (_waveform.isEmpty) {
      _generatePlaceholderWaveform();
    }

    final progress = _duration == Duration.zero
        ? 0.0
        : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);

    return CustomPaint(
      painter: WaveformPainter(
        waveform: _waveform,
        progress: progress,
        isMe: widget.isMe,
        textColor: textColor,
        iconColor: iconColor,
      ),
      size: Size.infinite,
    );
  }
}

/// Custom painter for audio waveform
class WaveformPainter extends CustomPainter {
  final List<double> waveform;
  final double progress;
  final bool isMe;
  final Color textColor;
  final Color iconColor;

  WaveformPainter({
    required this.waveform,
    required this.progress,
    required this.isMe,
    required this.textColor,
    required this.iconColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final playedColor = isMe ? Colors.white : iconColor;
    final unplayedColor = isMe
        ? Colors.white.withOpacity(0.4)
        : textColor.withOpacity(0.3);

    final barCount = waveform.length;
    final barWidth = size.width / barCount;
    final maxHeight = size.height * 0.85;
    final minHeight = size.height * 0.15;

    for (int i = 0; i < barCount; i++) {
      final normalizedIndex = i / barCount;
      final isPlayed = normalizedIndex <= progress;
      
      final paint = Paint()
        ..color = isPlayed ? playedColor : unplayedColor
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      final barHeight = minHeight + (maxHeight - minHeight) * waveform[i];
      final x = i * barWidth + barWidth / 2;
      final y = size.height / 2;

      canvas.drawLine(
        Offset(x, y - barHeight / 2),
        Offset(x, y + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.waveform != waveform ||
        oldDelegate.progress != progress ||
        oldDelegate.isMe != isMe;
  }
}
