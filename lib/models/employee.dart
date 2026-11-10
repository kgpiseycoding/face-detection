class Employee {
  const Employee({
    required this.employeeCode,
    required this.firstName,
    required this.lastName,
    required this.departmentName,
    this.hasPhoto = false,
    this.faceEnrolled = false,
  });

  final String employeeCode;
  final String firstName;
  final String lastName;
  final String departmentName;
  final bool hasPhoto;
  final bool faceEnrolled;

  String get displayName => '$firstName $lastName'.trim();

  factory Employee.fromJson(Map<String, dynamic> json) {
    final employeeCode = json['employeeCode'] ?? json['code'];
    if (employeeCode is! String || employeeCode.trim().isEmpty) {
      throw const FormatException(
        'An employee response is missing its employee code.',
      );
    }

    final firstName = _stringValue(json['firstName']);
    final lastName = _stringValue(json['lastName']);
    final fullName = _stringValue(
      json['fullName'] ?? json['employeeName'] ?? json['name'],
    );
    final nameParts = fullName.split(RegExp(r'\s+'));
    final resolvedFirstName = firstName.isNotEmpty
        ? firstName
        : fullName.isEmpty
        ? ''
        : nameParts.first;
    final resolvedLastName = lastName.isNotEmpty
        ? lastName
        : nameParts.length > 1
        ? nameParts.skip(1).join(' ')
        : '';

    return Employee(
      employeeCode: employeeCode,
      firstName: resolvedFirstName,
      lastName: resolvedLastName,
      departmentName: _stringValue(
        json['departmentName'] ?? json['department'],
      ),
      hasPhoto: json['hasPhoto'] == true,
      faceEnrolled: json['faceEnrolled'] == true,
    );
  }

  static String _stringValue(Object? value) =>
      value is String ? value.trim() : '';
}
