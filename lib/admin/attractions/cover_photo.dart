import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as image;

/// A compressed catalogue thumbnail stays well below Firestore's document limit.
/// Reuses this project's existing image package; no separate storage service.
String encodeAttractionCover(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > 8 * 1024 * 1024) {
    throw const FormatException('Choose a photo smaller than 8 MB.');
  }
  image.Image? decoded;
  try {
    decoded = image.decodeImage(bytes);
  } catch (_) {
    throw const FormatException('Choose a supported JPG, PNG or WebP photo.');
  }
  if (decoded == null) {
    throw const FormatException('Choose a supported JPG, PNG or WebP photo.');
  }
  var picture = image.bakeOrientation(decoded);
  if (picture.width > 640 || picture.height > 640) {
    picture = image.copyResize(
      picture,
      width: picture.width >= picture.height ? 640 : null,
      height: picture.height > picture.width ? 640 : null,
    );
  }
  for (final quality in [85, 70, 55]) {
    final encoded = base64Encode(image.encodeJpg(picture, quality: quality));
    if (encoded.length <= 240000) return encoded;
  }
  throw const FormatException(
    'This photo is too large after compression. Choose a smaller photo.',
  );
}
