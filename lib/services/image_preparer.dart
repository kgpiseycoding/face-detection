import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

abstract final class ImagePreparer {
  static const maxBytes = 500000;

  static Future<Uint8List> prepareForUpload(String path) async {
    var jpeg = await FlutterImageCompress.compressWithFile(
      path,
      minWidth: 1024,
      minHeight: 1024,
      quality: 80,
      autoCorrectionAngle: true,
      format: CompressFormat.jpeg,
    );
    if (jpeg == null || jpeg.isEmpty) {
      throw StateError('The selected photo could not be prepared.');
    }
    if (jpeg.length >= maxBytes) {
      jpeg = await FlutterImageCompress.compressWithList(
        jpeg,
        minWidth: 1024,
        minHeight: 1024,
        quality: 60,
        format: CompressFormat.jpeg,
      );
    }
    if (jpeg.length >= maxBytes) {
      throw StateError(
        'The photo could not be compressed below 500 KB. Please retake it.',
      );
    }
    return jpeg;
  }
}
