import 'dart:typed_data';
import 'package:image/image.dart' as image;

Uint8List attractionTestPhoto() =>
    Uint8List.fromList(image.encodePng(image.Image(width: 8, height: 8)));
