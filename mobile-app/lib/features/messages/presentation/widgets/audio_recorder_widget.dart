import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';

/// WhatsApp-like audio recorder widget
/// Shows recording UI with waveform, timer, and gesture controls
class AudioRecorderWidget extends StatefulWidget {
  final VoidCallback? onCancel;
  final Function(String filePath)? onSend;
  final Function()? onLock;
  final bool isLocked;

  const AudioRecorderWidget({
    Key? key,
    this.onCancel,
    this.onSend,
    this.onLock,
    this.isLocked = false,
  }) : super(key: key);

  @override
  State<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends State<AudioRecorderWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveformController;
  Duration _recordingDuration = Duration.zero;
  Timer? _durationTimer;
  bool _isSlidingLeft = false;
  bool _isSlidingUp = false;

  @override
  void initState() {
    super.initState();
    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
    
    _startDurationTimer();
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        setState(() {
          _recordingDuration = Duration(
            milliseconds: _recordingDuration.inMilliseconds + 100,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _waveformController.dispose();
    _durationTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56, // Match TextField height
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.accentPrimary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Delete/Cancel button (left)
          GestureDetector(
            onTap: widget.onCancel,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.isLocked ? Icons.close : Icons.delete_outline,
                color: AppColors.textSecondary,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),
          
          // Waveform visualization (WhatsApp style - larger, animated)
          Expanded(
            child: SizedBox(
              height: 40,
              child: _buildWaveform(),
            ),
          ),
          const SizedBox(width: 8),
          
          // Timer (right side, WhatsApp style)
          Text(
            _formatDuration(_recordingDuration),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          
          // Send button (always visible - WhatsApp style)
          GestureDetector(
            onTap: widget.onSend != null
                ? () => widget.onSend!('')
                : null,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accentPrimary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.send,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveform() {
    return AnimatedBuilder(
      animation: _waveformController,
      builder: (context, child) {
        return CustomPaint(
          painter: WaveformPainter(
            animationValue: _waveformController.value,
            isSlidingLeft: _isSlidingLeft,
            isSlidingUp: _isSlidingUp,
            isRecording: true, // Always recording when this widget is shown
          ),
          size: Size.infinite,
        );
      },
    );
  }

  /// Update slide state for gesture feedback
  void updateSlideState({bool isLeft = false, bool isUp = false}) {
    setState(() {
      _isSlidingLeft = isLeft;
      _isSlidingUp = isUp;
    });
  }

  /// Reset slide state
  void resetSlideState() {
    setState(() {
      _isSlidingLeft = false;
      _isSlidingUp = false;
    });
  }
}

/// Custom painter for animated waveform (WhatsApp style)
class WaveformPainter extends CustomPainter {
  final double animationValue;
  final bool isSlidingLeft;
  final bool isSlidingUp;
  final bool isRecording;

  WaveformPainter({
    required this.animationValue,
    this.isSlidingLeft = false,
    this.isSlidingUp = false,
    this.isRecording = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final color = isSlidingLeft
        ? Colors.red
        : isSlidingUp
            ? AppColors.accentPrimary
            : AppColors.accentPrimary;

    final barCount = 50; // More bars for smoother look
    final barWidth = (size.width - (barCount - 1) * 3) / barCount; // 3px spacing
    final maxHeight = size.height * 0.9;
    final minHeight = size.height * 0.15;

    for (int i = 0; i < barCount; i++) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      // Create animated waveform pattern (WhatsApp style - more dynamic)
      final normalizedIndex = i / barCount;
      final wavePhase = (normalizedIndex * 4 * 3.14159) + (animationValue * 4 * 3.14159);
      final baseAmplitude = (math.sin(wavePhase) + 1) / 2; // 0 to 1
      
      // Add variation for more natural look
      final variation = math.sin(normalizedIndex * 10) * 0.3;
      final amplitude = (baseAmplitude + variation).clamp(0.2, 1.0);
      
      // Bar height with smooth animation
      final barHeight = minHeight + (maxHeight - minHeight) * amplitude;
      
      final x = i * (barWidth + 3) + barWidth / 2;
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
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isSlidingLeft != isSlidingLeft ||
        oldDelegate.isSlidingUp != isSlidingUp ||
        oldDelegate.isRecording != isRecording;
  }
}
