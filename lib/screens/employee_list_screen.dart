import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api/hrm_api_exception.dart';
import '../api/hrm_face_api.dart';
import '../models/employee.dart';
import 'enrollment_screen.dart';

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({
    super.key,
    required this.api,
    this.selectionOnly = false,
    this.registeredEmployeeCodes = const {},
  });

  final HrmFaceApi api;
  final bool selectionOnly;
  final Set<String> registeredEmployeeCodes;

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  final _searchController = TextEditingController();
  final Map<String, Future<Uint8List?>> _profilePhotoRequests = {};
  List<Employee> _employees = const [];
  bool _isLoading = true;
  String? _errorMessage;
  _EmployeeFilter _employeeFilter = _EmployeeFilter.all;

  bool _isRegistered(Employee employee) => widget.registeredEmployeeCodes
      .contains(employee.employeeCode.trim().toUpperCase());

  List<Employee> get _filteredEmployees => _employees
      .where((employee) {
        final isRegistered = _isRegistered(employee);
        return switch (_employeeFilter) {
          _EmployeeFilter.all => true,
          _EmployeeFilter.registered => isRegistered,
          _EmployeeFilter.notRegistered => !isRegistered,
        };
      })
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    if (!widget.api.hasApiKey) {
      _setLoadError(
        'ខ្វះកូនសោ HRM API។ សូមបើកកម្មវិធីដោយប្រើ '
        '--dart-define=HRM_API_KEY=YOUR_KEY.',
      );
      return;
    }
    if (widget.api.hasPlaceholderBaseUrl) {
      _setLoadError(
        'នៅតែប្រើអាសយដ្ឋាន UAT គំរូ។ សូមកំណត់អាសយដ្ឋាន API ពិត '
        'ដោយប្រើ --dart-define=HRM_BASE_URL=https://your-hrm-host.',
      );
      return;
    }
    try {
      final response = await widget.api.employees(
        search: _searchController.text.trim(),
        status: 'ACTIVE',
        page: 0,
        size: 500,
      );
      final rows = _employeeRows(response);
      final employees = rows
          .map((row) {
            if (row is! Map<String, dynamic>) {
              throw const FormatException('Employee record was not an object.');
            }
            return Employee.fromJson(row);
          })
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _employees = employees;
        _isLoading = false;
      });
    } on HrmApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.statusCode == 401
            ? 'ម៉ាស៊ីនមេ HRM នៅ ${widget.api.baseUrl} បានបដិសេធ API key។ '
                  'សូមបញ្ជាក់ថា key ត្រឹមត្រូវសម្រាប់ម៉ាស៊ីនមេនេះ ហើយបើកកម្មវិធីម្ដងទៀតដោយប្រើ '
                  '--dart-define=HRM_API_KEY=YOUR_KEY.'
            : error.userMessage;
        _isLoading = false;
      });
    } on FormatException {
      _setLoadError('ម៉ាស៊ីនមេ HRM បានផ្ញើបញ្ជីបុគ្គលិកដែលមិនត្រឹមត្រូវ។');
    } on SocketException {
      _setLoadError(
        'មិនអាចភ្ជាប់ទៅ ${widget.api.baseUrl} បានទេ។ សូមពិនិត្យអាសយដ្ឋាន និងការតភ្ជាប់បណ្ដាញ។ '
        'នៅលើ iPhone សូមភ្ជាប់ Wi-Fi ដូចគ្នា ហើយអនុញ្ញាតកម្មវិធីនេះនៅក្នុង '
        'ការកំណត់ > ឯកជនភាព និងសុវត្ថិភាព > បណ្ដាញមូលដ្ឋាន។',
      );
    } on TimeoutException {
      _setLoadError(
        'សំណើទៅ ${widget.api.baseUrl} អស់ពេល។ សូមពិនិត្យអាសយដ្ឋានម៉ាស៊ីនមេ និងបណ្ដាញ រួចសាកល្បងម្ដងទៀត។',
      );
    } on http.ClientException catch (error) {
      final details = error.message.toLowerCase();
      if (details.contains('cleartext') ||
          details.contains('not permitted') ||
          details.contains('network security policy')) {
        _setLoadError(
          'Android បានរារាំងការតភ្ជាប់ HTTP នេះ។ សូមប្រើ HTTPS ឬបើក cleartext traffic '
          'ក្នុង Android manifest សម្រាប់ debug ប៉ុណ្ណោះ។',
        );
      } else {
        _setLoadError(
          'សំណើ HTTP មិនអាចទៅដល់ ${widget.api.baseUrl} បានទេ។ សូមពិនិត្យអាសយដ្ឋាន និងការតភ្ជាប់បណ្ដាញ។',
        );
      }
    } on Object {
      _setLoadError(
        'មិនអាចផ្ទុកបញ្ជីបុគ្គលិកពី ${widget.api.baseUrl} បានទេ។ '
        'សូមពិនិត្យអាសយដ្ឋាន API, API key និងការតភ្ជាប់បណ្ដាញ។',
      );
    }
  }

  void _setLoadError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _isLoading = false;
    });
  }

  List<Object?> _employeeRows(Object? response) {
    if (response is List) return response.cast<Object?>();
    if (response is Map<String, dynamic>) {
      final rows =
          response['content'] ?? response['employees'] ?? response['items'];
      if (rows is List) return rows.cast<Object?>();
    }
    throw const FormatException('Employee list was not a JSON array.');
  }

  Future<Uint8List?> _loadProfilePhoto(Employee employee) async {
    try {
      return await widget.api.employeeAngleImage(
        employee.employeeCode,
        'straight',
      );
    } on HrmApiException catch (error) {
      if (error.statusCode != 404) {
        debugPrint(
          'Could not load straight-angle profile photo for '
          '${employee.employeeCode}: $error',
        );
      }
      return null;
    } on Object catch (error, stackTrace) {
      debugPrint(
        'Could not load straight-angle profile photo for '
        '${employee.employeeCode}: $error\n$stackTrace',
      );
      return null;
    }
  }

  Widget _buildEmployeeAvatar(Employee employee) {
    final firstLetter = employee.displayName.isEmpty
        ? '?'
        : employee.displayName.characters.first.toUpperCase();
    if (!employee.hasPhoto) {
      return CircleAvatar(
        radius: 26,
        backgroundColor: const Color(0xFFE9EEFF),
        child: Text(
          firstLetter,
          style: const TextStyle(
            color: Color(0xFF315CDB),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final future = _profilePhotoRequests.putIfAbsent(
      employee.employeeCode,
      () => _loadProfilePhoto(employee),
    );
    return FutureBuilder<Uint8List?>(
      future: future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null) {
          return CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFE9EEFF),
            backgroundImage: MemoryImage(bytes),
          );
        }
        return CircleAvatar(
          radius: 26,
          backgroundColor: const Color(0xFFE9EEFF),
          child: snapshot.connectionState == ConnectionState.waiting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  firstLetter,
                  style: const TextStyle(
                    color: Color(0xFF315CDB),
                    fontWeight: FontWeight.w700,
                  ),
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.selectionOnly ? 'ជ្រើសរើសបុគ្គលិក' : 'បញ្ជីបុគ្គលិក',
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _loadEmployees(),
              decoration: InputDecoration(
                hintText: 'ស្វែងរកបុគ្គលិក',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? IconButton(
                        tooltip: 'ស្វែងរក',
                        onPressed: _loadEmployees,
                        icon: const Icon(Icons.arrow_forward),
                      )
                    : IconButton(
                        tooltip: 'លុបពាក្យស្វែងរក',
                        onPressed: () {
                          _searchController.clear();
                          _loadEmployees();
                        },
                        icon: const Icon(Icons.close),
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE3E7F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE3E7F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFF315CDB),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          if (widget.selectionOnly) _buildEmployeeFilter(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildEmployeeFilter() {
    final registeredCount = _employees.where(_isRegistered).length;
    final notRegisteredCount = _employees.length - registeredCount;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          _filterChip(_EmployeeFilter.all, 'ទាំងអស់ (${_employees.length})'),
          const SizedBox(width: 8),
          _filterChip(
            _EmployeeFilter.registered,
            'បានបន្ថែម ($registeredCount)',
          ),
          const SizedBox(width: 8),
          _filterChip(
            _EmployeeFilter.notRegistered,
            'មិនទាន់បន្ថែម ($notRegisteredCount)',
          ),
        ],
      ),
    );
  }

  Widget _filterChip(_EmployeeFilter filter, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _employeeFilter == filter,
      onSelected: (_) => setState(() => _employeeFilter = filter),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage case final message?) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 44),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadEmployees,
                icon: const Icon(Icons.refresh),
                label: const Text('សាកល្បងម្ដងទៀត'),
              ),
            ],
          ),
        ),
      );
    }
    final employees = _filteredEmployees;
    if (employees.isEmpty) {
      if (_employees.isNotEmpty) {
        return Center(
          child: Text(
            _employeeFilter == _EmployeeFilter.registered
                ? 'មិនមានបុគ្គលិកដែលបានបន្ថែមទេ។'
                : 'បុគ្គលិកទាំងអស់ត្រូវបានបន្ថែមរួចហើយ។',
          ),
        );
      }
      return const Center(child: Text('រកមិនឃើញបុគ្គលិកដែលកំពុងបម្រើការទេ។'));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: employees.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final employee = employees[index];
        final isRegistered = _isRegistered(employee);
        return Card(
          key: Key('employee-${employee.employeeCode}'),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              if (widget.selectionOnly) {
                Navigator.of(context).pop(employee);
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      EnrollmentScreen(api: widget.api, employee: employee),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  _buildEmployeeAvatar(employee),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (employee.firstName.isNotEmpty &&
                            employee.lastName.isNotEmpty)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                employee.firstName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                employee.lastName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          )
                        else
                          Text(
                            employee.displayName.isEmpty
                                ? employee.employeeCode
                                : employee.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        const SizedBox(height: 4),
                        Text(
                          employee.departmentName.isEmpty
                              ? employee.employeeCode
                              : '${employee.employeeCode} · ${employee.departmentName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        Flexible(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _buildEnrollmentStatus(employee.faceEnrolled),
                              if (widget.selectionOnly)
                                _buildRegisteredStatus(isRegistered),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: Color(0xFF7C8498)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnrollmentStatus(bool faceEnrolled) {
    final color = faceEnrolled
        ? const Color(0xFF17834A)
        : const Color(0xFF986300);
    final backgroundColor = faceEnrolled
        ? const Color(0xFFE7F6ED)
        : const Color(0xFFFFF4D6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            faceEnrolled ? Icons.check_circle : Icons.pending_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            faceEnrolled ? 'បានចុះឈ្មោះមុខរួចហើយ' : 'មិនទាន់ចុះឈ្មោះមុខ',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisteredStatus(bool isRegistered) {
    final color = isRegistered
        ? const Color(0xFF315CDB)
        : const Color(0xFF687386);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isRegistered ? const Color(0xFFE9EEFF) : const Color(0xFFF1F3F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isRegistered ? Icons.person : Icons.person_add_alt_1,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            isRegistered ? 'បានបន្ថែមក្នុងកម្មវិធី' : 'មិនទាន់បន្ថែម',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

enum _EmployeeFilter { all, registered, notRegistered }
