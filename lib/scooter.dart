// Crispy — splash-ல் ஓடும் ஸ்கூட்டர் + ஓட்டுநர் (index.html-ன் .sp-sc SVG-யை அப்படியே வரைகிறது)
// viewBox "0 -6 150 106"; நிறங்கள் Pro v3 palette-க்கு மாற்றப்பட்டவை.
import 'dart:math' as math;

import 'package:flutter/material.dart';

class SittaScooter extends StatelessWidget {
  final double spin; // சக்கரம்: 0..1 = ஒரு சுற்று
  final double width;
  const SittaScooter({super.key, this.spin = 0, this.width = 150});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: width * 106 / 150,
        child: CustomPaint(painter: _ScooterPainter(spin)),
      );
}

class _ScooterPainter extends CustomPainter {
  final double spin;
  const _ScooterPainter(this.spin);

  static const Color _g = Color(0xFF15803D); // முன்பு #00a884
  static const Color _dk = Color(0xFF14532D); // முன்பு #075e54
  static const Color _ink = Color(0xFF1C2420); // முன்பு #17201d
  static const Color _tint = Color(0xFFECF6EF); // முன்பு #e9f7f2

  Paint _fill(Color c) => Paint()
    ..color = c
    ..style = PaintingStyle.fill;

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _wheel(Canvas c, double cx, double cy) {
    c.save();
    c.translate(cx, cy);
    c.rotate(spin * 2 * math.pi);
    c.drawCircle(Offset.zero, 13, _fill(const Color(0xFF1F2A28)));
    c.drawCircle(Offset.zero, 7, _fill(const Color(0xFFDFE7E4)));
    c.drawCircle(Offset.zero, 2.5, _fill(const Color(0xFF1F2A28)));
    final sp = _stroke(const Color(0xFF9AA9A4), 1.5);
    c.drawLine(const Offset(0, -7), const Offset(0, 7), sp);
    c.drawLine(const Offset(-7, 0), const Offset(7, 0), sp);
    c.restore();
  }

  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / 150, size.height / 106);
    c.translate(0, 6); // viewBox y = -6

    // பின் பெட்டி + "C"
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(14, 22, 32, 28), const Radius.circular(6)), _fill(_g));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(14, 22, 32, 8), const Radius.circular(4)), _fill(_dk));
    final tp = TextPainter(
      text: const TextSpan(text: 'C', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(30 - tp.width / 2, 44 - tp.computeDistanceToActualBaseline(TextBaseline.alphabetic)));

    // உடல்
    final body = Path()
      ..moveTo(30, 80)
      ..arcToPoint(const Offset(32, 54), radius: const Radius.circular(16), clockwise: true)
      ..relativeLineTo(40, 0)
      ..relativeCubicTo(6, 0, 9, 4, 10, 9)
      ..relativeLineTo(3, 17)
      ..close();
    c.drawPath(body, _fill(_g));
    // இருக்கை
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(40, 46, 34, 7), const Radius.circular(3.5)), _fill(_ink));
    // கால் தளம்
    c.drawPath(
        Path()
          ..moveTo(64, 74)
          ..relativeLineTo(34, 0)
          ..relativeLineTo(4, -8)
          ..relativeLineTo(-36, 0)
          ..close(),
        _fill(_dk));
    // முன் கம்பம்
    c.drawLine(const Offset(98, 76), const Offset(106, 38), _stroke(_dk, 7));
    // முன் மூடி
    c.drawPath(
        Path()
          ..moveTo(104, 50)
          ..relativeCubicTo(6, 2, 10, 8, 11, 16)
          ..relativeLineTo(-11, 4)
          ..close(),
        _fill(_g));
    // கைப்பிடி + விளக்கு
    c.drawLine(const Offset(100, 34), const Offset(114, 34), _stroke(_ink, 4));
    c.drawCircle(const Offset(113, 40), 4, _fill(const Color(0xFFFBBF24)));

    // ஓட்டுநர்: உடல்
    c.drawPath(
        Path()
          ..moveTo(58, 46)
          ..relativeLineTo(-2, 0)
          ..relativeCubicTo(-1, -10, 6, -22, 18, -24)
          ..relativeLineTo(8, 2)
          ..relativeLineTo(-6, 22)
          ..close(),
        _fill(_dk));
    // கால்
    c.drawPath(
        Path()
          ..moveTo(60, 50)
          ..relativeLineTo(20, -2)
          ..relativeLineTo(6, 22),
        _stroke(_ink, 7));
    c.drawLine(const Offset(86, 70), const Offset(94, 70), _stroke(_ink, 5));
    // கை
    c.drawPath(
        Path()
          ..moveTo(76, 28)
          ..relativeLineTo(14, 4)
          ..relativeLineTo(10, 2),
        _stroke(_dk, 6));
    c.drawCircle(const Offset(102, 34), 3, _fill(const Color(0xFFF2C9A0)));
    // தலைக்கவசம்
    c.drawCircle(const Offset(82, 14), 10, _fill(_g));
    c.drawPath(
        Path()
          ..moveTo(84, 10)
          ..relativeLineTo(8, 0)
          ..arcToPoint(const Offset(92, 18), radius: const Radius.circular(10), clockwise: true)
          ..relativeLineTo(-8, 0)
          ..close(),
        _fill(_tint));
    c.drawPath(
        Path()
          ..moveTo(72, 16)
          ..arcToPoint(const Offset(92, 12), radius: const Radius.circular(10), clockwise: true),
        _stroke(_dk, 2.5));

    // சக்கரங்கள் (சுழலும்)
    _wheel(c, 34, 80);
    _wheel(c, 112, 80);
    // முன் சக்கர மூடி
    c.drawPath(
        Path()
          ..moveTo(100, 74)
          ..arcToPoint(const Offset(124, 68), radius: const Radius.circular(14), clockwise: true),
        _stroke(_g, 4));

    c.restore();
  }

  @override
  bool shouldRepaint(covariant _ScooterPainter o) => o.spin != spin;
}
