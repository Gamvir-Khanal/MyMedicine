import 'package:flutter/material.dart';

enum SocialAuthType {
  google,
  apple,
  biometrics,
}

class SocialAuthButton extends StatelessWidget {
  const SocialAuthButton({
    super.key,
    required this.type,
    required this.onTap,
    this.label,
    this.isFullWidth = false,
  });

  final SocialAuthType type;
  final VoidCallback onTap;
  final String? label;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget iconWidget;
    String defaultLabel;

    switch (type) {
      case SocialAuthType.google:
        iconWidget = _buildGoogleIcon();
        defaultLabel = 'Continue with Google';
        break;
      case SocialAuthType.apple:
        iconWidget = Icon(
          Icons.apple,
          size: 24,
          color: isDark ? Colors.white : Colors.black87,
        );
        defaultLabel = 'Continue with Apple';
        break;
      case SocialAuthType.biometrics:
        iconWidget = Icon(
          Icons.fingerprint_rounded,
          size: 24,
          color: theme.colorScheme.primary,
        );
        defaultLabel = 'Quick Biometric Sign-in';
        break;
    }

    final displayText = label ?? defaultLabel;

    if (isFullWidth) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            backgroundColor:
                isDark ? const Color(0xFF1E2421) : Colors.white,
            side: BorderSide(
              color: isDark ? Colors.white12 : Colors.grey.shade300,
              width: 1.2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconWidget,
              const SizedBox(width: 12),
              Text(
                displayText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2421) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            if (label != null) ...[
              const SizedBox(width: 10),
              Text(
                label!,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w / 2;

    final bluePaint = Paint()..color = const Color(0xFF4285F4);

    final strokeWidth = radius * 0.45;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    // Blue arc (right top to bottom)
    strokePaint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.4, 1.4, false, strokePaint);

    // Green arc (bottom right to left)
    strokePaint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 1.0, 1.3, false, strokePaint);

    // Yellow arc (left bottom to top)
    strokePaint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.3, 1.3, false, strokePaint);

    // Red arc (top left to right)
    strokePaint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 3.6, 1.3, false, strokePaint);

    // Center blue crossbar
    final barRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(center.dx - radius * 0.1, center.dy - strokeWidth / 2, radius * 1.05, strokeWidth),
      Radius.circular(strokeWidth / 2),
    );
    canvas.drawRRect(barRect, bluePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
