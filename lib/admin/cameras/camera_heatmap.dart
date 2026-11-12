import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CameraHeatmap {
  CameraHeatmap(this.count, this.cells);
  static const side = 20;
  final int count;
  final List<int> cells;

  factory CameraHeatmap.fromBoxes(List<Rect> boxes) {
    final density = List<double>.filled(side * side, 0);
    for (final box in boxes) {
      final center = box.center;
      // Keep the strongest heat near the torso. A half-cell minimum keeps
      // small detections visible on the grid.
      final sigmaX = math.max(box.width * .21, .5 / side);
      final sigmaY = math.max(box.height * .23, .5 / side);
      for (var row = 0; row < side; row++) {
        final dy = ((row + .5) / side - center.dy) / sigmaY;
        for (var column = 0; column < side; column++) {
          final dx = ((column + .5) / side - center.dx) / sigmaX;
          density[row * side + column] += math.exp(-.5 * (dx * dx + dy * dy));
        }
      }
    }
    return CameraHeatmap(boxes.length, [
      for (final value in density) (value * 80).round().clamp(0, 255),
    ]);
  }

  String encode() => jsonEncode({'count': count, 'cells': cells});

  static CameraHeatmap? decode(String message) {
    if (message.length > 3000) return null;
    try {
      final data = jsonDecode(message);
      if (data is! Map) return null;
      final count = data['count'];
      final cells = data['cells'];
      if (count is! int ||
          count < 0 ||
          count > 60 ||
          cells is! List ||
          cells.length != side * side ||
          cells.any((c) => c is! int || c < 0 || c > 255)) {
        return null;
      }
      return CameraHeatmap(count, cells.cast<int>());
    } on FormatException {
      return null;
    }
  }
}

class CameraVideo extends StatelessWidget {
  const CameraVideo({super.key, required this.renderer, this.heat});
  final RTCVideoRenderer renderer;
  final CameraHeatmap? heat;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 16 / 9,
    child: ColoredBox(
      color: Colors.black,
      child: ValueListenableBuilder<RTCVideoValue>(
        valueListenable: renderer,
        builder: (context, value, _) => Center(
          child: AspectRatio(
            aspectRatio: value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                RTCVideoView(renderer),
                if (heat != null && value.width > 0)
                  IgnorePointer(
                    child: CustomPaint(painter: _HeatPainter(heat!)),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _HeatPainter extends CustomPainter {
  const _HeatPainter(this.heat);
  final CameraHeatmap heat;

  @override
  void paint(Canvas canvas, Size size) {
    const side = CameraHeatmap.side;
    final paint = Paint();
    for (var row = 0; row < side; row++) {
      for (var column = 0; column < side; column++) {
        final value = heat.cells[row * side + column] / 255;
        if (value < .045) continue;
        paint.color = HSVColor.fromAHSV(
          .18 + value * .51,
          215 * (1 - value),
          .92,
          1,
        ).toColor();
        canvas.drawRect(
          Rect.fromLTWH(
            column * size.width / side,
            row * size.height / side,
            size.width / side + .5,
            size.height / side + .5,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_HeatPainter oldDelegate) => oldDelegate.heat != heat;
}
