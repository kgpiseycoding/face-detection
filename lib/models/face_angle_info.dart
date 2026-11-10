import '../constants/face_angles.dart';

class FaceAngleInfo {
  const FaceAngleInfo({
    required this.angle,
    required this.labelEn,
    required this.labelKm,
  });

  final String angle;
  final String labelEn;
  final String labelKm;

  factory FaceAngleInfo.fromJson(Map<String, dynamic> json) {
    final angleValue = json['angle'] ?? json['key'];
    final angle = angleValue is String ? angleValue : '';
    final labelEnValue = json['labelEn'];
    final labelKmValue = json['labelKm'];

    return FaceAngleInfo(
      angle: angle,
      labelEn: labelEnValue is String
          ? labelEnValue
          : faceAngleLabels[angle] ?? angle,
      labelKm: labelKmValue is String ? labelKmValue : '',
    );
  }
}
