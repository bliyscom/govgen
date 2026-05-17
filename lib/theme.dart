import 'package:flutter/material.dart';

class OhadaTheme {
  static const Color primary = Color(0xFF004D99); // Institutional Blue
  static const Color accent = Color(0xFFC5A059);  // Imperial Gold
  
  // Dark Theme
  static const Color background = Color(0xFF0A0F0C); // Black Slate
  static const Color surface = Color(0xFF1B241E);    // Dark Green Slate
  static const Color border = Colors.white12;

  // Light Theme
  static const Color lightBackground = Color(0xFFFDFBF7); // Parchment/Sand
  static const Color lightSurface = Color(0xFFF2EEE4);    // Muted Sand
  static const Color lightBorder = Colors.black12;
}

class GovGenLogo extends StatelessWidget {
  final double size;
  const GovGenLogo({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: GovGenPainter(),
      ),
    );
  }
}

class GovGenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer Gold Ring (Institutional Seal)
    final outerRingPaint = Paint()
      ..color = OhadaTheme.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05;
    canvas.drawCircle(center, radius * 0.9, outerRingPaint);

    // Inner Forest Green Fill
    final bgPaint = Paint()
      ..color = OhadaTheme.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.82, bgPaint);

    // Heraldic Shield Path
    final shieldPath = Path();
    final sw = size.width;
    final sh = size.height;
    shieldPath.moveTo(sw * 0.5, sh * 0.25); // Top center
    shieldPath.quadraticBezierTo(sw * 0.75, sh * 0.25, sw * 0.75, sh * 0.45);
    shieldPath.quadraticBezierTo(sw * 0.75, sh * 0.75, sw * 0.5, sh * 0.85); // Bottom tip
    shieldPath.quadraticBezierTo(sw * 0.25, sh * 0.75, sw * 0.25, sh * 0.45);
    shieldPath.quadraticBezierTo(sw * 0.25, sh * 0.25, sw * 0.5, sh * 0.25);
    shieldPath.close();

    final shieldPaint = Paint()
      ..color = OhadaTheme.accent.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw * 0.03;
    canvas.drawPath(shieldPath, shieldPaint);

    // Digital Security Motif (Center Node)
    final nodePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, sw * 0.04, nodePaint);

    // Circuit lines coming from the node
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw * 0.015;
    
    canvas.drawLine(center, Offset(sw * 0.4, sh * 0.4), linePaint);
    canvas.drawLine(center, Offset(sw * 0.6, sh * 0.4), linePaint);
    canvas.drawLine(center, Offset(sw * 0.5, sh * 0.65), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
