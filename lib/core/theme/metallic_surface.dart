import 'dart:math' as math;

import 'package:flutter/material.dart';

@immutable
class MetallicPalette extends ThemeExtension<MetallicPalette> {
  final Color base;
  final Color sheen;
  final Color wave;
  final Color ridge;
  final Color panel;
  final Color panelBorder;

  const MetallicPalette({
    required this.base,
    required this.sheen,
    required this.wave,
    required this.ridge,
    required this.panel,
    required this.panelBorder,
  });

  static MetallicPalette of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<MetallicPalette>() ??
        (theme.brightness == Brightness.dark ? _fallbackDark : _fallbackLight);
  }

  static const _fallbackLight = MetallicPalette(
    base: Color(0xFFF1F3F5),
    sheen: Colors.white,
    wave: Color(0xFFD4D9DF),
    ridge: Color(0xFFAEB7C0),
    panel: Color(0xDDF7F8FA),
    panelBorder: Color(0xBFFFFFFF),
  );

  static const _fallbackDark = MetallicPalette(
    base: Color(0xFF111417),
    sheen: Color(0xFF4D5660),
    wave: Color(0xFF2B3138),
    ridge: Color(0xFF6D7782),
    panel: Color(0xDD20252B),
    panelBorder: Color(0x667D8792),
  );

  @override
  MetallicPalette copyWith({
    Color? base,
    Color? sheen,
    Color? wave,
    Color? ridge,
    Color? panel,
    Color? panelBorder,
  }) {
    return MetallicPalette(
      base: base ?? this.base,
      sheen: sheen ?? this.sheen,
      wave: wave ?? this.wave,
      ridge: ridge ?? this.ridge,
      panel: panel ?? this.panel,
      panelBorder: panelBorder ?? this.panelBorder,
    );
  }

  @override
  MetallicPalette lerp(ThemeExtension<MetallicPalette>? other, double t) {
    if (other is! MetallicPalette) return this;
    return MetallicPalette(
      base: Color.lerp(base, other.base, t)!,
      sheen: Color.lerp(sheen, other.sheen, t)!,
      wave: Color.lerp(wave, other.wave, t)!,
      ridge: Color.lerp(ridge, other.ridge, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      panelBorder: Color.lerp(panelBorder, other.panelBorder, t)!,
    );
  }
}

class MetallicBackground extends StatelessWidget {
  final Widget child;

  const MetallicBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final palette = MetallicPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.base,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.sheen.withValues(alpha: isDark ? 0.16 : 0.74),
            palette.base,
            palette.wave.withValues(alpha: isDark ? 0.36 : 0.64),
            palette.base,
          ],
          stops: const [0, 0.28, 0.68, 1],
        ),
      ),
      child: CustomPaint(
        painter: _MetallicWavePainter(palette: palette, isDark: isDark),
        child: child,
      ),
    );
  }
}

class MetallicPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final VoidCallback? onTap;

  const MetallicPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 20,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = MetallicPalette.of(context);
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(borderRadius);
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: palette.panelBorder),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.sheen.withValues(alpha: 0.18),
            palette.panel,
            palette.wave.withValues(alpha: 0.22),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(onTap: onTap, borderRadius: radius, child: content),
    );
  }
}

class _MetallicWavePainter extends CustomPainter {
  final MetallicPalette palette;
  final bool isDark;

  const _MetallicWavePainter({required this.palette, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = palette.ridge.withValues(alpha: isDark ? 0.13 : 0.2);

    for (var i = 0; i < 7; i++) {
      final y = size.height * (0.1 + i * 0.15);
      final amplitude = size.height * (0.025 + i * 0.002);
      final path = Path()..moveTo(-size.width * 0.08, y);
      path.cubicTo(
        size.width * 0.16,
        y - amplitude,
        size.width * 0.34,
        y + amplitude,
        size.width * 0.55,
        y,
      );
      path.cubicTo(
        size.width * 0.74,
        y - amplitude * 1.2,
        size.width * 0.92,
        y + amplitude * 0.9,
        size.width * 1.08,
        y - amplitude * 0.25,
      );
      canvas.drawPath(path, wavePaint);
    }

    final sheenPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, size.shortestSide * 0.002)
      ..color = palette.sheen.withValues(alpha: isDark ? 0.06 : 0.22);

    for (var i = 0; i < 4; i++) {
      final x = size.width * (0.18 + i * 0.24);
      canvas.drawLine(
        Offset(x, -size.height * 0.05),
        Offset(x + size.width * 0.24, size.height * 1.05),
        sheenPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_MetallicWavePainter oldDelegate) =>
      oldDelegate.palette != palette || oldDelegate.isDark != isDark;
}
