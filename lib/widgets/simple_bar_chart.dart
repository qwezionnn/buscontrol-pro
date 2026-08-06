import 'dart:math' as math;

import 'package:flutter/material.dart';

class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.height = 180,
  });

  final List<double> values;
  final List<String> labels;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SimpleBarChartPainter(
          values: values,
          labels: labels,
          color: Theme.of(context).colorScheme.primary,
          textColor: Theme.of(context).colorScheme.onSurface,
          gridColor: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class _SimpleBarChartPainter extends CustomPainter {
  _SimpleBarChartPainter({
    required this.values,
    required this.labels,
    required this.color,
    required this.textColor,
    required this.gridColor,
  });

  final List<double> values;
  final List<String> labels;
  final Color color;
  final Color textColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    const bottomPadding = 30.0;
    const topPadding = 12.0;
    final chartHeight = size.height - bottomPadding - topPadding;
    final maxValue = math.max(
      1.0,
      values.fold<double>(0, math.max),
    );
    final gap = size.width / values.length;
    final barWidth = math.max(8.0, gap * 0.55);

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var line = 0; line <= 3; line++) {
      final y = topPadding + chartHeight * line / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final barPaint = Paint()..color = color;
    final labelStyle = TextStyle(
      color: textColor,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    for (var index = 0; index < values.length; index++) {
      final x = gap * index + gap / 2;
      final barHeight = chartHeight * values[index] / maxValue;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x - barWidth / 2,
          topPadding + chartHeight - barHeight,
          barWidth,
          barHeight,
        ),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, barPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: index < labels.length ? labels[index] : '',
          style: labelStyle,
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: gap);
      textPainter.paint(
        canvas,
        Offset(
          x - textPainter.width / 2,
          size.height - bottomPadding + 8,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SimpleBarChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.labels != labels ||
        oldDelegate.color != color;
  }
}
