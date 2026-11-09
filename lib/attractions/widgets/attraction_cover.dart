import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Real administrator-selected image. Legacy records get an honest image state.
class AttractionCover extends StatefulWidget {
  const AttractionCover({
    super.key,
    required this.encoded,
    this.width = 86,
    this.height = 90,
    this.radius = 9,
    this.placeholderIcon = Icons.image_outlined,
  });
  final String? encoded;
  final double width;
  final double height;
  final double radius;
  final IconData placeholderIcon;
  @override
  State<AttractionCover> createState() => _AttractionCoverState();
}

class _AttractionCoverState extends State<AttractionCover> {
  Uint8List? _bytes;
  void _decode() {
    try {
      _bytes = widget.encoded == null ? null : base64Decode(widget.encoded!);
    } on FormatException {
      _bytes = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(AttractionCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.encoded != widget.encoded) _decode();
  }

  Widget _missing() => ColoredBox(
    color: const Color(0xFFF3ECE9),
    child: Center(
      child: Icon(
        widget.placeholderIcon,
        color: const Color(0xFFAB9390),
        size: 28,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(widget.radius),
    child: SizedBox(
      width: widget.width,
      height: widget.height,
      child: _bytes == null
          ? _missing()
          : Image.memory(
              _bytes!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => _missing(),
            ),
    ),
  );
}
