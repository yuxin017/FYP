import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../attractions/models/attraction.dart';
import '../attractions/widgets/attraction_widgets.dart';
import '../attractions/widgets/queue_attraction_card.dart';
import 'park_visit.dart';
import 'venue_configuration.dart';
import 'venue_map.dart';

class ParkMapCanvas extends StatelessWidget {
  const ParkMapCanvas({
    super.key,
    required this.visit,
    required this.visible,
    required this.onPlace,
    this.origin,
    this.destination,
    this.selectedId,
    this.heatmap = false,
    this.density,
  });

  final ParkVisit visit;
  final List<Attraction> visible;
  final ValueChanged<Attraction> onPlace;
  final Attraction? origin;
  final Attraction? destination;
  final String? selectedId;
  final bool heatmap;
  final Map<String, dynamic>? density;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child:
        VenueConfiguration.mapboxReady &&
            VenueConfiguration.boundsReady &&
            visit.places.isNotEmpty
        ? GeographicParkMap(
            visit: visit,
            visible: visible,
            onPlace: onPlace,
            origin: origin,
            destination: destination,
            density: heatmap ? density : null,
          )
        : LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              final compact =
                  size.width < 320 ||
                  MediaQuery.textScalerOf(context).scale(10) > 12;
              final positions = _positions(size);
              final start = positions[origin?.id];
              final finish = positions[destination?.id];
              return Stack(
                children: [
                  Positioned.fill(
                    child: InteractiveViewer(
                      maxScale: 3,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CustomPaint(painter: _ParkSchematic(start, finish)),
                          if (heatmap && density != null)
                            CustomPaint(painter: QueueDensityPainter(density!)),
                          if (heatmap && density == null)
                            for (final place in visible)
                              if (visit.crowdFor(place) case final crowd?)
                                Positioned(
                                  left: positions[place.id]!.dx - 47,
                                  top: positions[place.id]!.dy - 47,
                                  child: IgnorePointer(
                                    child: Container(
                                      width: 94,
                                      height: 94,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            crowdColor(
                                              crowd,
                                            ).withValues(alpha: .55),
                                            crowdColor(
                                              crowd,
                                            ).withValues(alpha: .10),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                          for (final place in visible)
                            if (place.id != origin?.id)
                              _pin(
                                place,
                                positions[place.id]!,
                                compact: compact,
                              ),
                          if (start != null)
                            Positioned(
                              left: start.dx - 54,
                              top: start.dy - 17,
                              width: 108,
                              child: IgnorePointer(
                                child: Column(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: queueRose,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.my_location,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    if (!compact)
                                      const Chip(
                                        label: Text(
                                          'Start here',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .95),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        child: Text(
                          'Schematic park map',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
  );

  Map<String, Offset> _positions(Size size) {
    final places = visit.places;
    if (places.isEmpty) return {};
    final normalized = places.every(
      (p) => p.mapX >= 0 && p.mapX <= 1 && p.mapY >= 0 && p.mapY <= 1,
    );
    final xs = places.map((p) => p.mapX);
    final ys = places.map((p) => p.mapY);
    final minX = xs.reduce(math.min);
    final minY = ys.reduce(math.min);
    final maxX = xs.reduce(math.max);
    final maxY = ys.reduce(math.max);
    double relative(double value, double low, double high) {
      if (low == high) return .5;
      final scale = math.max(low.abs(), high.abs());
      return ((value / scale - low / scale) / (high / scale - low / scale))
          .clamp(0.0, 1.0);
    }

    return {
      for (final place in places)
        place.id: Offset(
          size.width *
              (.16 +
                  .68 *
                      (normalized
                          ? place.mapX
                          : relative(place.mapX, minX, maxX))),
          size.height *
              (.14 +
                  .70 *
                      (normalized
                          ? place.mapY
                          : relative(place.mapY, minY, maxY))),
        ),
    };
  }

  Widget _pin(Attraction place, Offset point, {required bool compact}) {
    final crowd = visit.crowdFor(place);
    final color = heatmap ? crowdColor(crowd) : queueRose;
    final wait = place.isRide ? place.standbyMinutes : null;
    final status = switch (place.status) {
      AttractionStatus.open => 'Open',
      AttractionStatus.closed => 'Closed',
      AttractionStatus.maintenance => 'Maintenance',
    };
    var subtitle = status;
    if (place.status == AttractionStatus.open) {
      if (heatmap && place.isRide) {
        subtitle = crowd?.label ?? 'Not reported';
      } else if (wait != null) {
        subtitle = '$wait min';
      }
    }
    final labelWidth = compact
        ? 44.0
        : heatmap
        ? 106.0
        : 88.0;
    return Positioned(
      left: point.dx - labelWidth / 2,
      top: point.dy - 19,
      width: labelWidth,
      child: Semantics(
        button: true,
        label: '${place.name}, $subtitle',
        child: Tooltip(
          message: place.name,
          child: InkWell(
            onTap: () => onPlace(place),
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                Container(
                  width: 37,
                  height: 37,
                  decoration: BoxDecoration(
                    color: place.id == selectedId ? queueInk : color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Color(0x24000000), blurRadius: 4),
                    ],
                  ),
                  child: Icon(
                    parkPlaceIcon(place.placeKind),
                    color: Colors.white,
                    size: 19,
                  ),
                ),
                if (compact) const SizedBox(height: 7),
                if (!compact)
                  Container(
                    margin: const EdgeInsets.only(top: 1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Column(
                      children: [
                        if (heatmap)
                          Text(
                            place.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: queueInk,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: heatmap ? color : queueInk,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QueueDensityPainter extends CustomPainter {
  final Map<String, dynamic> grid;
  QueueDensityPainter(this.grid);
  @override
  void paint(Canvas canvas, Size size) {
    final count = grid['size'] as int? ?? 0,
        values = grid['values'] as List? ?? [];
    if (count < 2 || count > 100 || values.length != count * count) return;
    final paint = Paint();
    for (int y = 0; y < count; y++) {
      for (int x = 0; x < count; x++) {
        final value = (values[y * count + x] as num)
            .toDouble()
            .clamp(0.0, 1.0)
            .toDouble();
        if (value < .03) continue;
        paint.color = Color.lerp(
          const Color(0xFF56B976),
          const Color(0xFFE66456),
          value,
        )!.withValues(alpha: value * .55);
        canvas.drawRect(
          Rect.fromLTWH(
            size.width * (.16 + .68 * x / count),
            size.height * (.14 + .70 * y / count),
            size.width * .68 / count + 1,
            size.height * .70 / count + 1,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(QueueDensityPainter oldDelegate) =>
      grid != oldDelegate.grid;
}

class _ParkSchematic extends CustomPainter {
  const _ParkSchematic(this.start, this.finish);
  final Offset? start;
  final Offset? finish;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFF0EADF);
    canvas.drawRect(Offset.zero & size, paint);
    final w = size.width;
    final h = size.height;
    // Soft landscaped shapes give the schematic texture without adding fake
    // attractions or drawing an unverified pedestrian network.
    for (final (x, y, rx, ry) in const [
      (.15, .14, .24, .18),
      (.77, .12, .27, .21),
      (.44, .46, .24, .25),
      (.06, .61, .19, .24),
      (.91, .55, .20, .25),
      (.58, .89, .31, .17),
    ]) {
      paint.color = const Color(0xFFCEDCC1);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * x, h * y),
          width: w * rx * 2,
          height: h * ry * 2,
        ),
        paint,
      );
      paint.color = const Color(0xFFA8BF9B);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * x, h * y),
          width: w * rx * 1.26,
          height: h * ry * 1.27,
        ),
        paint,
      );
    }
    paint.color = const Color(0xFFB8D9DB);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * .14, h * .42),
        width: w * .27,
        height: h * .20,
      ),
      paint,
    );
    paint.color = const Color(0xFFE8D8BE);
    canvas.drawCircle(Offset(w * .53, h * .58), w * .13, paint);
    paint.color = const Color(0xFFF4EADD);
    canvas.drawCircle(Offset(w * .53, h * .58), w * .096, paint);
    if (start != null && finish != null) {
      paint
        ..color = Colors.white
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(start!, finish!, paint);
      paint
        ..color = queueRose
        ..strokeWidth = 5;
      canvas.drawLine(start!, finish!, paint);
    }
  }

  @override
  bool shouldRepaint(_ParkSchematic oldDelegate) =>
      oldDelegate.start != start || oldDelegate.finish != finish;
}
