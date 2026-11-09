import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'support_models.dart';

SupportAttachment prepareSupportAttachment(
  String originalName,
  Uint8List originalBytes,
) {
  var bytes = originalBytes;
  if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
    throw StateError('Choose a photo or PDF smaller than 10 MB.');
  }
  var name = originalName
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
      .trim();
  if (name.isEmpty || name == '.' || name == '..') name = 'attachment';
  if (name.length > 90) name = name.substring(name.length - 90);
  String mime;
  if (bytes.length >= 5 && String.fromCharCodes(bytes.take(5)) == '%PDF-') {
    mime = 'application/pdf';
    if (bytes.length > 512000) {
      throw StateError('Choose a PDF no larger than 500 KB.');
    }
  } else {
    final png =
        bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71 &&
        bytes[4] == 13 &&
        bytes[5] == 10 &&
        bytes[6] == 26 &&
        bytes[7] == 10;
    final jpg =
        bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    if (!png && !jpg) throw StateError('Choose a JPG, PNG or PDF file.');
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError(
        'This photo could not be read. Choose another JPG or PNG.',
      );
    }
    mime = png ? 'image/png' : 'image/jpeg';
    if (bytes.length > 512000) {
      var picture = decoded;
      if (picture.width > 1600 || picture.height > 1600) {
        picture = img.copyResize(
          picture,
          width: picture.width >= picture.height ? 1600 : null,
          height: picture.height > picture.width ? 1600 : null,
        );
      }
      bytes = img.encodeJpg(picture, quality: 82);
      if (bytes.length > 512000) bytes = img.encodeJpg(picture, quality: 55);
      mime = 'image/jpeg';
      name = '${name.replaceFirst(RegExp(r'\.[^.]*$'), '')}.jpg';
    }
  }
  if (bytes.length > 512000) {
    throw StateError('Choose a smaller photo, up to 500 KB after compression.');
  }
  return SupportAttachment(name, mime, bytes);
}
