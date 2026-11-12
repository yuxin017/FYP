import 'package:collaborative_asg/admin/cameras/camera_heatmap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'heat covers the upper and lower body without spilling past the detection',
    () {
      final near = CameraHeatmap.fromBoxes([
        const Rect.fromLTRB(.35, .2, .65, .85),
      ]);
      final far = CameraHeatmap.fromBoxes([
        const Rect.fromLTRB(.425, .4, .575, .65),
      ]);
      int cell(CameraHeatmap heat, int row, int column) =>
          heat.cells[row * CameraHeatmap.side + column];

      expect(cell(near, 7, 9), greaterThanOrEqualTo(12));
      expect(cell(near, 13, 9), greaterThanOrEqualTo(12));
      expect(cell(near, 10, 9), greaterThan(cell(near, 7, 9)));
      expect(cell(near, 10, 6), lessThan(12));
      expect(cell(near, 3, 9), lessThan(12));
      expect(cell(far, 7, 9), lessThan(12));
      expect(cell(far, 10, 9), greaterThanOrEqualTo(12));
    },
  );

  test(
    'overlapping detections add heat and preserve the camera message format',
    () {
      const right = Rect.fromLTRB(.7, .3, .85, .75);
      final lone = CameraHeatmap.fromBoxes([right]);
      final grouped = CameraHeatmap.fromBoxes([
        right,
        right,
        const Rect.fromLTRB(.15, .3, .3, .75),
      ]);
      final leftCell = 10 * CameraHeatmap.side + 4;
      final rightCell = 10 * CameraHeatmap.side + 15;
      expect(lone.cells[leftCell], 0);
      expect(grouped.cells[rightCell], greaterThan(lone.cells[rightCell]));
      expect(grouped.cells[rightCell], greaterThan(grouped.cells[leftCell]));
      expect(CameraHeatmap.decode(grouped.encode())?.count, 3);
      expect(CameraHeatmap.decode(grouped.encode())?.cells, grouped.cells);
      expect(
        CameraHeatmap.fromBoxes([]).cells.every((cell) => cell == 0),
        isTrue,
      );
    },
  );

  test('a truncated or malformed camera message cannot become an overlay', () {
    expect(CameraHeatmap.decode('{"count":1,"cells":[255]}'), isNull);
    expect(CameraHeatmap.decode('not json'), isNull);
  });
}
