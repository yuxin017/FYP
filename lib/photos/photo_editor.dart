import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'photo_widgets.dart';

const photoFilters = {
  'original': 'Original',
  'warm': 'Warm',
  'vivid': 'Vivid',
  'cool': 'Cool',
  'vintage': 'Vintage',
  'mono': 'B&W',
};
Uint8List applyPhotoChanges(Map<String, dynamic> value) {
  var source = img.decodeImage(value['source'] as Uint8List);
  if (source == null) throw StateError('This photo could not be opened.');
  final edits = Map<String, dynamic>.from(value['edits'] as Map? ?? {}),
      crop = edits['crop'] as Map?;
  if (crop != null) {
    final x = ((crop['x'] as num) * source.width).round().clamp(
          0,
          source.width - 1,
        ),
        y = ((crop['y'] as num) * source.height).round().clamp(
          0,
          source.height - 1,
        ),
        width = ((crop['width'] as num) * source.width).round().clamp(
          1,
          source.width - x,
        ),
        height = ((crop['height'] as num) * source.height).round().clamp(
          1,
          source.height - y,
        );
    source = img.copyCrop(source, x: x, y: y, width: width, height: height);
  }
  final rotation = (edits['rotation'] as num?)?.toInt() ?? 0;
  if (rotation != 0) source = img.copyRotate(source, angle: rotation);
  final beauty = (edits['beauty'] as num?)?.toDouble() ?? 0;
  if (beauty > 0) {
    final smooth = img.gaussianBlur(img.Image.from(source), radius: 2);
    for (final pixel in source) {
      final other = smooth.getPixel(pixel.x, pixel.y);
      pixel
        ..r = pixel.r * (1 - beauty) + other.r * beauty
        ..g = pixel.g * (1 - beauty) + other.g * beauty
        ..b = pixel.b * (1 - beauty) + other.b * beauty;
    }
  }
  final filter = edits['filter'] as String? ?? 'original',
      intensity = (edits['intensity'] as num?)?.toDouble() ?? 1,
      brightness = ((edits['brightness'] as num?)?.toDouble() ?? 0) * 255;
  for (final pixel in source) {
    final r = pixel.r.toDouble(),
        g = pixel.g.toDouble(),
        b = pixel.b.toDouble(),
        gray = .299 * r + .587 * g + .114 * b;
    double red = r, green = g, blue = b;
    switch (filter) {
      case 'warm':
        red = r * 1.12;
        green = g * 1.02;
        blue = b * .91;
      case 'cool':
        red = r * .94;
        green = g * 1.02;
        blue = b * 1.14;
      case 'mono':
        red = gray;
        green = gray;
        blue = gray;
      case 'vintage':
        red = (.393 * r + .769 * g + .189 * b) * .9 + 12;
        green = (.349 * r + .686 * g + .168 * b) * .9 + 12;
        blue = (.272 * r + .534 * g + .131 * b) * .9 + 12;
      case 'vivid':
        red = gray + (r - gray) * 1.25;
        green = gray + (g - gray) * 1.25;
        blue = gray + (b - gray) * 1.25;
    }
    pixel
      ..r = (red * intensity + r * (1 - intensity) + brightness).clamp(0, 255)
      ..g = (green * intensity + g * (1 - intensity) + brightness).clamp(0, 255)
      ..b = (blue * intensity + b * (1 - intensity) + brightness).clamp(0, 255);
  }
  final sticker = edits['sticker'] as Map?;
  if (sticker != null) {
    final cx = (sticker['x'] as num).toDouble() * source.width,
        cy = (sticker['y'] as num).toDouble() * source.height,
        radius =
            (sticker['scale'] as num).toDouble() *
            math.min(source.width, source.height),
        kind = sticker['type'];
    final polygon = <math.Point<double>>[];
    if (kind == 'star') {
      for (int i = 0; i < 10; i++) {
        final size = radius * (i.isEven ? 1 : .45),
            angle = i * math.pi / 5 - math.pi / 2;
        polygon.add(
          math.Point(cx + size * math.cos(angle), cy + size * math.sin(angle)),
        );
      }
    }
    if (kind == 'heart') {
      for (int i = 0; i < 80; i++) {
        final t = i * 2 * math.pi / 79;
        polygon.add(
          math.Point(
            cx + radius * math.pow(math.sin(t), 3),
            cy -
                radius *
                    (13 * math.cos(t) -
                        5 * math.cos(2 * t) -
                        2 * math.cos(3 * t) -
                        math.cos(4 * t)) /
                    17,
          ),
        );
      }
    }
    bool inside(double x, double y) {
      var within = false;
      for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
        final a = polygon[i], b = polygon[j];
        if ((a.y > y) != (b.y > y) &&
            x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x) {
          within = !within;
        }
      }
      return within;
    }

    for (
      int y = math.max(0, (cy - radius * 1.1).floor());
      y < math.min(source.height, (cy + radius * 1.1).ceil());
      y++
    ) {
      for (
        int x = math.max(0, (cx - radius * 1.1).floor());
        x < math.min(source.width, (cx + radius * 1.1).ceil());
        x++
      ) {
        if (kind == 'smile') {
          final dx = x - cx, dy = y - cy;
          if (dx * dx + dy * dy > radius * radius) continue;
          final left =
                  math.pow(dx + radius / 3, 2) + math.pow(dy + radius / 4, 2) <
                  math.pow(radius / 12, 2),
              right =
                  math.pow(dx - radius / 3, 2) + math.pow(dy + radius / 4, 2) <
                  math.pow(radius / 12, 2),
              mouth =
                  dy > 0 &&
                  ((dx * dx + dy * dy).toDouble().sqrtDistance(radius * .5) <
                      radius * .05);
          source.setPixelRgb(
            x,
            y,
            left || right || mouth ? 40 : 255,
            left || right || mouth ? 40 : 220,
            left || right || mouth ? 40 : 80,
          );
        } else if (inside(x.toDouble(), y.toDouble())) {
          source.setPixelRgb(
            x,
            y,
            kind == 'heart' ? 205 : 255,
            kind == 'heart' ? 95 : 205,
            kind == 'heart' ? 100 : 80,
          );
        }
      }
    }
  }
  return Uint8List.fromList(img.encodeJpg(source, quality: 82));
}

extension on double {
  double sqrtDistance(double radius) => (math.sqrt(this) - radius).abs();
}

Map<String, Uint8List> photoThumbnails(Uint8List bytes) {
  final source = img.decodeImage(bytes);
  if (source == null) return {};
  final small = Uint8List.fromList(
    img.encodeJpg(img.copyResize(source, width: 90), quality: 70),
  );
  return {
    for (final filter in photoFilters.keys)
      filter: applyPhotoChanges({
        'source': small,
        'edits': {'filter': filter},
      }),
  };
}

class PhotoEditorPage extends StatefulWidget {
  final String preview;
  final Map<String, dynamic> initialEdits;
  const PhotoEditorPage({
    super.key,
    required this.preview,
    this.initialEdits = const {},
  });
  @override
  State<PhotoEditorPage> createState() => _PhotoEditorPageState();
}

class _PhotoEditorPageState extends State<PhotoEditorPage> {
  late final source = base64Decode(widget.preview);
  late Map<String, dynamic> edits = Map.from(widget.initialEdits);
  Uint8List? rendered;
  Map<String, Uint8List> thumbnails = {};
  String section = 'Filters';
  bool busy = false, comparing = false;
  int generation = 0;
  String? error;
  @override
  void initState() {
    super.initState();
    render();
    compute(photoThumbnails, source)
        .then((value) {
          if (mounted) setState(() => thumbnails = value);
        })
        .catchError((Object _) {});
  }

  Future<void> render() async {
    final current = ++generation;
    setState(() => busy = true);
    try {
      final result = await compute(applyPhotoChanges, {
        'source': source,
        'edits': Map<String, dynamic>.from(edits),
      });
      if (mounted && current == generation) {
        setState(() {
          rendered = result;
          busy = false;
          error = null;
        });
      }
    } catch (_) {
      if (mounted && current == generation) {
        setState(() {
          busy = false;
          error = 'Unable to apply these edits. Reset the photo and try again.';
        });
      }
    }
  }

  void change(String key, dynamic value) {
    setState(() => edits[key] = value);
    render();
  }

  void rotate(int amount) => change(
    'rotation',
    (((edits['rotation'] as num?)?.toInt() ?? 0) + amount + 360) % 360,
  );
  void crop(String option) {
    final decoded = img.decodeImage(source);
    if (decoded == null) return;
    setState(() {
      edits['rotation'] = 0;
      if (option == 'Original') {
        edits.remove('crop');
      } else {
        final ratio = option == 'Square'
                ? 1.0
                : option == 'Portrait'
                ? 0.8
                : 4 / 3,
            actual = decoded.width / decoded.height;
        final width = actual > ratio ? ratio / actual : 1.0,
            height = actual > ratio ? 1.0 : actual / ratio;
        edits['crop'] = {
          'x': (1 - width) / 2,
          'y': (1 - height) / 2,
          'width': width,
          'height': height,
        };
      }
    });
    render();
  }

  @override
  Widget build(BuildContext context) => PhotoFrame(
    title: 'Edit Photo',
    actions: [
      TextButton(
        onPressed: busy
            ? null
            : () {
                setState(() => edits = {});
                render();
              },
        child: const Text('Reset'),
      ),
    ],
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final decoded = img.decodeImage(rendered ?? source),
                ratio = decoded == null ? 1.0 : decoded.width / decoded.height,
                height = math.min(420.0, c.maxWidth / ratio),
                width = height * ratio;
            return Center(
              child: GestureDetector(
                onLongPressStart: (_) => setState(() => comparing = true),
                onLongPressEnd: (_) => setState(() => comparing = false),
                onTapUp: section == 'Stickers' && edits['sticker'] != null
                    ? (details) {
                        final sticker = Map<String, dynamic>.from(
                          edits['sticker'] as Map,
                        );
                        sticker['x'] = (details.localPosition.dx / width).clamp(
                          0,
                          1,
                        );
                        sticker['y'] = (details.localPosition.dy / height)
                            .clamp(0, 1);
                        change('sticker', sticker);
                      }
                    : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.memory(
                    comparing ? source : rendered ?? source,
                    width: width,
                    height: height,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            );
          },
        ),
        if (busy) const LinearProgressIndicator(color: photoRose),
        const SizedBox(height: 10),
        Row(
          children: [
            IconButton(
              tooltip: 'Rotate left',
              onPressed: busy ? null : () => rotate(-90),
              icon: const Icon(Icons.rotate_left, color: photoRose),
            ),
            IconButton(
              tooltip: 'Rotate right',
              onPressed: busy ? null : () => rotate(90),
              icon: const Icon(Icons.rotate_right, color: photoRose),
            ),
            const Spacer(),
            const Flexible(
              child: Text(
                'Hold photo to compare\nbefore / after',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 10, color: Color(0xFF7C8289)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        PhotoPanel(
          child: Column(
            children: [
              Row(
                children: [
                  for (final item in [
                    ('Filters', Icons.auto_fix_high_outlined),
                    ('Stickers', Icons.emoji_emotions_outlined),
                    ('Beauty', Icons.face_retouching_natural),
                    ('Crop', Icons.crop),
                  ])
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => section = item.$1),
                        child: Column(
                          children: [
                            Icon(
                              item.$2,
                              color: section == item.$1
                                  ? photoRose
                                  : Colors.grey,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.$1,
                              style: TextStyle(
                                fontSize: 11,
                                color: section == item.$1
                                    ? photoRose
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const Divider(height: 25),
              if (section == 'Filters') ...[
                SizedBox(
                  height: 84,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final filter in photoFilters.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: busy
                                ? null
                                : () => change('filter', filter.key),
                            child: Column(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color:
                                          (edits['filter'] ?? 'original') ==
                                              filter.key
                                          ? photoRose
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.memory(
                                      thumbnails[filter.key] ?? source,
                                      width: 52,
                                      height: 51,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  filter.value,
                                  style: const TextStyle(fontSize: 9),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Intensity', style: TextStyle(fontSize: 12)),
                    ),
                    Text(
                      '${(((edits['intensity'] as num?) ?? 1) * 100).round()}%',
                    ),
                  ],
                ),
                Slider(
                  value: ((edits['intensity'] as num?)?.toDouble() ?? 1).clamp(
                    0,
                    1,
                  ),
                  onChanged: (value) =>
                      setState(() => edits['intensity'] = value),
                  onChangeEnd: (_) => render(),
                ),
              ],
              if (section == 'Stickers') ...[
                Wrap(
                  spacing: 12,
                  children: [
                    for (final sticker in [
                      ('heart', Icons.favorite),
                      ('star', Icons.star),
                      ('smile', Icons.emoji_emotions),
                    ])
                      IconButton.filledTonal(
                        tooltip: '${sticker.$1} sticker',
                        onPressed: busy
                            ? null
                            : () => change('sticker', {
                                'type': sticker.$1,
                                'x': .8,
                                'y': .8,
                                'scale': .12,
                              }),
                        icon: Icon(sticker.$2, color: photoRose),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tap the photo to position your sticker.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF7C8289)),
                ),
                if (edits['sticker'] != null) ...[
                  Slider(
                    min: .04,
                    max: .3,
                    value: ((edits['sticker'] as Map)['scale'] as num)
                        .toDouble(),
                    onChanged: (v) => setState(
                      () => edits['sticker'] = {
                        ...edits['sticker'] as Map,
                        'scale': v,
                      },
                    ),
                    onChangeEnd: (_) => render(),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => edits.remove('sticker'));
                      render();
                    },
                    child: const Text('Remove sticker'),
                  ),
                ],
              ],
              if (section == 'Beauty') ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Softening'),
                ),
                Slider(
                  min: 0,
                  max: .5,
                  value: (edits['beauty'] as num?)?.toDouble() ?? 0,
                  onChanged: (v) => setState(() => edits['beauty'] = v),
                  onChangeEnd: (_) => render(),
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Brightness'),
                ),
                Slider(
                  min: -.3,
                  max: .3,
                  value: (edits['brightness'] as num?)?.toDouble() ?? 0,
                  onChanged: (v) => setState(() => edits['brightness'] = v),
                  onChangeEnd: (_) => render(),
                ),
              ],
              if (section == 'Crop')
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in [
                      'Original',
                      'Square',
                      'Portrait',
                      'Landscape',
                    ])
                      ActionChip(
                        label: Text(option),
                        onPressed: busy ? null : () => crop(option),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(error!, style: const TextStyle(color: photoRose)),
          ),
        PhotoButton(
          'Save & Continue',
          onPressed: busy ? null : () => Navigator.pop(context, edits),
        ),
        const SizedBox(height: 10),
        PhotoButton(
          'Cancel Editing',
          onPressed: () => Navigator.pop(context),
          outlined: true,
        ),
      ],
    ),
  );
}
