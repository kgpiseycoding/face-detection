import 'dart:io';

import 'package:image/image.dart' as img;

Future<String> normalizeFacePhoto(String path) async {
  final source = File(path);
  final decoded = img.decodeImage(await source.readAsBytes());
  if (decoded == null) {
    throw const FormatException('The captured face photo could not be read.');
  }

  final upright = img.bakeOrientation(decoded);
  final outputPath = path.replaceFirst(
    RegExp(r'\.(jpe?g|png|heic)$', caseSensitive: false),
    '-upright.jpg',
  );
  final output = File(outputPath);
  await output.writeAsBytes(img.encodeJpg(upright, quality: 95), flush: true);
  return output.path;
}
