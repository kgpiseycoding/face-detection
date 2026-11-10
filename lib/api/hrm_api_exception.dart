class HrmApiException implements Exception {
  const HrmApiException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  String get userMessage => switch (statusCode) {
    401 => 'API key របស់អ្នកត្រូវបានបដិសេធ។ សូមពិនិត្យ HRM_API_KEY ហើយព្យាយាមម្ដងទៀត។',
    404 => 'រកមិនឃើញបុគ្គលិក ឬទីតាំង HRM API ទេ។',
    503 => 'សេវា HRM មិនអាចប្រើបានបណ្ដោះអាសន្ន។ សូមព្យាយាមម្ដងទៀតនៅពេលក្រោយ។',
    _ when message.isNotEmpty => 'សារពី HRM៖ $message',
    _ => 'សំណើទៅ HRM បរាជ័យ។ សូមព្យាយាមម្ដងទៀត។',
  };

  @override
  String toString() => 'HRM API error ($statusCode): $message';
}
