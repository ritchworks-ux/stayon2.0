import 'package:flutter/material.dart';

/// Overlay widget for barcode scanner showing a centered crosshair.
///
/// - Horizontal + vertical lines crossing at the center
/// - Optional corner markers (dots or brackets)
/// - Status text at the bottom
class BarcodeOverlay extends StatelessWidget {
  const BarcodeOverlay({
    super.key,
    this.statusText = 'Point camera at barcode',
    this.statusColor,
  });

  /// Status message shown at the bottom of the overlay
  final String statusText;

  /// Color of the status text and overlay lines (defaults to white)
  final Color? statusColor;

  @override
  Widget build(BuildContext context) {
    final color = statusColor ?? Colors.white;

    return Stack(
      children: [
        // Crosshair
        CustomPaint(
          painter: _CrosshairPainter(color: color),
          size: Size.infinite,
        ),
        // Status text at bottom
        Positioned(
          bottom: 32,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter for the scanner crosshair.
class _CrosshairPainter extends CustomPainter {
  _CrosshairPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final crosshairLength = 60.0;

    // Vertical line
    canvas.drawLine(
      Offset(centerX, centerY - crosshairLength),
      Offset(centerX, centerY + crosshairLength),
      paint,
    );

    // Horizontal line
    canvas.drawLine(
      Offset(centerX - crosshairLength, centerY),
      Offset(centerX + crosshairLength, centerY),
      paint,
    );

    // Center dot
    canvas.drawCircle(Offset(centerX, centerY), 4, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
