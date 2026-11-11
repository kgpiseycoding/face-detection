import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import 'api/hrm_face_api.dart';
import 'config/app_config.dart';
import 'constants/face_angles.dart';
import 'face_enrollment.dart';
import 'face_identity_service.dart';
import 'face_store.dart';
import 'models/employee.dart';
import 'screens/employee_list_screen.dart';
import 'screens/enrollment_screen.dart' as hrm;

abstract final class AppTokens {
  static const brand = Color(0xFF2C5BDE);
  static const brandLight = Color(0xFFE9EEFF);
  static const brandDark = Color(0xFF1E3A8A);

  static const surface = Color(0xFFF8F9FC);
  static const surfaceElevated = Colors.white;
  static const outline = Color(0xFFE5E7EB);

  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);

  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF4B5563);
  static const textTertiary = Color(0xFF9CA3AF);

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  static const rSm = 8.0;
  static const rMd = 12.0;
  static const rLg = 20.0;
  static const rPill = 999.0;
}

abstract final class AppTheme {
  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppTokens.brand,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppTokens.brand,
          onPrimary: Colors.white,
          surface: AppTokens.surfaceElevated,
          error: AppTokens.danger,
        );

    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final t = base.textTheme;

    return base.copyWith(
      scaffoldBackgroundColor: AppTokens.surface,
      textTheme: t.copyWith(
        titleLarge: t.titleLarge?.copyWith(
          color: AppTokens.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
        titleMedium: t.titleMedium?.copyWith(
          color: AppTokens.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        bodyLarge: t.bodyLarge?.copyWith(
          color: AppTokens.textSecondary,
          fontSize: 15,
          height: 1.4,
        ),
        bodyMedium: t.bodyMedium?.copyWith(
          color: AppTokens.textSecondary,
          fontSize: 14,
          height: 1.4,
        ),
        bodySmall: t.bodySmall?.copyWith(
          color: AppTokens.textTertiary,
          fontSize: 13,
        ),
        labelLarge: t.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppTokens.surface,
        foregroundColor: AppTokens.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppTokens.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppTokens.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.rLg),
          side: const BorderSide(color: AppTokens.outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppTokens.brand,
          foregroundColor: Colors.white,
          minimumSize: const Size(44, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.rMd),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppTokens.brand,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTokens.textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.rMd),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (subtitle case final subtitle?) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({
    super.key,
    FaceStore? store,
    FaceIdentityService? identityService,
    HrmFaceApi? api,
  }) : store = store ?? LocalFaceStore(),
       identityService = identityService ?? LocalFaceIdentityService(),
       api =
           api ??
           HrmFaceApi(baseUrl: AppConfig.baseUrl, apiKey: AppConfig.apiKey);

  final FaceStore store;
  final FaceIdentityService identityService;
  final HrmFaceApi api;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SV Face ID',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('km'),
      supportedLocales: const [Locale('km')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: UserListScreen(
        store: store,
        identityService: identityService,
        api: api,
      ),
    );
  }
}

class UserListScreen extends StatefulWidget {
  const UserListScreen({
    super.key,
    required this.store,
    required this.identityService,
    required this.api,
  });
  final FaceStore store;
  final FaceIdentityService identityService;
  final HrmFaceApi api;

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  List<RegisteredUser> _users = const [];
  bool _isLoading = true;
  String? _error;
  String? _recognitionError;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final users = await widget.store.listUsers();
      String? recognitionError;
      try {
        await widget.identityService.prepare(users);
      } catch (e) {
        debugPrint('Face recognition init failed: $e');
        recognitionError = e.toString();
      }
      if (!mounted) return;
      setState(() {
        _users = users;
        _recognitionError = recognitionError;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Could not load users: $e');
      if (!mounted) return;
      setState(() {
        _error = 'សូមពិនិត្យទិន្នន័យក្នុងទូរស័ព្ទ ហើយសាកល្បងម្ដងទៀត។';
        _isLoading = false;
      });
    }
  }

  Future<void> _addUser() async {
    print('Adding user...' + widget.api.baseUrl);
    final registeredEmployeeCodes = _users
        .map((user) => user.employeeCode?.trim().toUpperCase())
        .whereType<String>()
        .where((code) => code.isNotEmpty)
        .toSet();
    final employee = await Navigator.of(context).push<Employee>(
      MaterialPageRoute(
        builder: (_) => AddUserScreen(
          api: widget.api,
          registeredEmployeeCodes: registeredEmployeeCodes,
        ),
      ),
    );
    if (!mounted || employee == null) return;

    try {
      final users = await widget.store.listUsers();
      final employeeCode = employee.employeeCode.trim().toUpperCase();
      RegisteredUser? existingUser;
      for (final user in users) {
        if (user.employeeCode?.trim().toUpperCase() == employeeCode) {
          existingUser = user;
          break;
        }
      }

      if (existingUser != null) {
        setState(() => _users = users);
        await _openHrmEnrollment(employee, existingUser);
        return;
      }

      final name = employee.displayName.isEmpty
          ? employee.employeeCode
          : employee.displayName;
      final user = await widget.store.createUser(
        name,
        employeeCode: employee.employeeCode,
      );
      if (!mounted) return;
      setState(() {
        _users = [
          ..._users,
          user,
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      });
      await _openHrmEnrollment(employee, user);
    } catch (e) {
      debugPrint('Add user failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('មិនអាចបន្ថែមបុគ្គលិកបានទេ។')),
      );
    }
  }

  Future<void> _openHrmEnrollment(
    Employee employee,
    RegisteredUser user,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => hrm.EnrollmentScreen(
          api: widget.api,
          employee: employee,
          store: widget.store,
          userId: user.id,
        ),
      ),
    );
    await _refreshUsers();
  }

  Future<void> _enrollUser(RegisteredUser user) async {
    final code = user.employeeCode;
    if (code != null && code.isNotEmpty) {
      await _openHrmEnrollment(
        Employee(
          employeeCode: code,
          firstName: user.name,
          lastName: '',
          departmentName: '',
        ),
        user,
      );
      return;
    }

    if (_recognitionError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('មិនអាចប្រើការស្គាល់មុខបានទេ។')),
      );
      return;
    }
    final enrolled = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EnrollmentScreen(
          store: widget.store,
          identityService: widget.identityService,
          user: user,
        ),
      ),
    );
    if (enrolled == true && mounted) await _loadUsers();
  }

  Future<void> _viewUserPhotos(RegisteredUser user) async {
    if (!user.hasFacePhotos) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => EnrolledFacePhotosScreen(user: user)),
    );
  }

  Future<void> _refreshUsers() async {
    final users = await widget.store.listUsers();
    if (!mounted) return;
    setState(() => _users = users);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _isLoading || _error != null
          ? null
          : FloatingActionButton(
              onPressed: _addUser,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, size: 28),
            ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppTokens.danger),
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadUsers,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
                  children: [
                    const SectionHeader(
                      title: 'បុគ្គលិក',
                      subtitle: 'មានប្រវត្តិរូបរក្សាទុកក្នុងទូរស័ព្ទនេះ',
                    ),
                    const SizedBox(height: 16),
                    if (_users.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTokens.surfaceElevated,
                          borderRadius: BorderRadius.circular(AppTokens.rLg),
                          border: Border.all(color: AppTokens.outline),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.people_outline,
                              size: 48,
                              color: AppTokens.brand,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'មិនទាន់មានបុគ្គលិកទេ',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'ស្វែងរក និងជ្រើសរើសបុគ្គលិកពី HRM ដើម្បីចាប់ផ្ដើមចុះឈ្មោះមុខ។',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTokens.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _addUser,
                              icon: const Icon(Icons.person_add_alt_1),
                              label: const Text('បន្ថែមបុគ្គលិក'),
                            ),
                          ],
                        ),
                      ),
                    if (_users.isEmpty) const SizedBox(height: 16),
                    if (_recognitionError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTokens.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'មិនអាចចាប់ផ្ដើមការស្គាល់មុខបានទេ។',
                          style: TextStyle(color: AppTokens.warning),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    for (var i = 0; i < _users.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: i == _users.length - 1 ? 0 : 12,
                        ),
                        child: _UserTile(
                          user: _users[i],
                          onTap: _users[i].employeeCode != null
                              ? () => _enrollUser(_users[i])
                              : _users[i].faceEnrolled
                              ? () => _viewUserPhotos(_users[i])
                              : null,
                          onViewPhotos: () => _viewUserPhotos(_users[i]),
                          onEnroll: () => _enrollUser(_users[i]),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.onTap,
    required this.onViewPhotos,
    required this.onEnroll,
  });
  final RegisteredUser user;
  final VoidCallback? onTap;
  final VoidCallback onViewPhotos;
  final VoidCallback onEnroll;

  @override
  Widget build(BuildContext context) {
    final enrolled = user.faceEnrolled;
    final hrmImageCount = faceAngleKeys
        .where((angle) => user.hrmFaceImagePaths[angle]?.isNotEmpty == true)
        .length;
    final hasHrm = hrmImageCount > 0;
    final hrmComplete = hrmImageCount == faceAngleKeys.length;
    final statusLabel = enrolled
        ? 'បានរក្សាទុក'
        : hasHrm
        ? hrmComplete
              ? 'រួចរាល់ (${faceAngleKeys.length}/${faceAngleKeys.length})'
              : 'មិនទាន់គ្រប់ ($hrmImageCount/${faceAngleKeys.length})'
        : 'មិនទាន់មាន';
    final statusColor = enrolled
        ? AppTokens.success
        : hasHrm
        ? hrmComplete
              ? AppTokens.success
              : AppTokens.brand
        : AppTokens.textSecondary;
    final statusBackground = enrolled || (hasHrm && hrmComplete)
        ? const Color(0xFFE6F5EE)
        : hasHrm
        ? const Color(0xFFE9EEFF)
        : const Color(0xFFF1F5F9);

    final imageFile = user.faceImagePaths.isNotEmpty
        ? File(user.faceImagePaths.first)
        : hasHrm
        ? File(
            user.hrmFaceImagePaths[faceAngleKeys.first] ??
                user.hrmFaceImagePaths.values.first,
          )
        : null;

    final initial = user.name.trim().isEmpty
        ? '?'
        : user.name.trim()[0].toUpperCase();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AppTokens.brand, // Solid Blue as requested
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                child: imageFile == null
                    ? Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : Image.file(
                        imageFile,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              // Name & Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusBackground,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            enrolled
                                ? Icons.check
                                : hasHrm
                                ? hrmComplete
                                      ? Icons.cloud_done_outlined
                                      : Icons.cloud_sync_outlined
                                : Icons.face_outlined,
                            size: 14,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: statusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Actions
              if (user.hasFacePhotos)
                IconButton(
                  onPressed: onViewPhotos,
                  icon: const Icon(
                    Icons.photo_library_outlined,
                    color: AppTokens.textSecondary,
                    size: 22,
                  ),
                ),
              IconButton(
                onPressed: onEnroll,
                icon: const Icon(
                  Icons.face_retouching_natural,
                  color: AppTokens.brand,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddUserScreen extends StatelessWidget {
  const AddUserScreen({
    super.key,
    required this.api,
    this.registeredEmployeeCodes = const {},
  });
  final HrmFaceApi api;
  final Set<String> registeredEmployeeCodes;

  @override
  Widget build(BuildContext context) {
    return EmployeeListScreen(
      api: api,
      selectionOnly: true,
      registeredEmployeeCodes: registeredEmployeeCodes,
    );
  }
}

class EnrollmentScreen extends StatefulWidget {
  const EnrollmentScreen({
    super.key,
    required this.store,
    required this.identityService,
    required this.user,
  });
  final FaceStore store;
  final FaceIdentityService identityService;
  final RegisteredUser user;

  @override
  State<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen> {
  final Map<FaceEnrollmentStep, XFile> _samples = {};
  late final String _sessionId = widget.identityService
      .createEnrollmentSession();

  Future<void> _saveSample(XFile image, FaceEnrollmentStep step) async {
    await widget.identityService.addEnrollmentSample(
      sessionId: _sessionId,
      user: widget.user,
      imagePath: image.path,
      sampleIndex: step.index,
    );
    final previous = _samples[step];
    _samples[step] = image;
    if (previous != null && previous.path != image.path) {
      await _deleteTemp(previous.path);
    }
    if (step != FaceEnrollmentStep.turnLeft) return;
    final ordered = [for (final s in FaceEnrollmentStep.values) _samples[s]!];
    final enrolledUser = await widget.store.enrollUser(widget.user.id, ordered);
    await widget.identityService.completeEnrollment(
      sessionId: _sessionId,
      user: enrolledUser,
    );
    for (final s in ordered) {
      await _deleteTemp(s.path);
    }
  }

  Future<void> _deleteTemp(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  @override
  void dispose() {
    unawaited(
      widget.identityService.cancelEnrollment(_sessionId).catchError((e) {
        debugPrint('Could not clear enrollment: $e');
      }),
    );
    for (final s in _samples.values) {
      unawaited(
        _deleteTemp(s.path).catchError((e) {
          debugPrint('Could not remove temp photo: $e');
        }),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FaceScanScreen(
      title: 'ចុះឈ្មោះមុខ',
      onCaptured: _saveSample,
      completedButtonLabel: 'បញ្ចប់',
      onCompleted: () => Navigator.of(context).pop(true),
    );
  }
}

class EnrolledFacePhotosScreen extends StatefulWidget {
  const EnrolledFacePhotosScreen({super.key, required this.user});
  final RegisteredUser user;

  @override
  State<EnrolledFacePhotosScreen> createState() =>
      _EnrolledFacePhotosScreenState();
}

class _EnrolledFacePhotosScreenState extends State<EnrolledFacePhotosScreen> {
  static const _legacyLabels = [
    'មើលត្រង់ទៅកាមេរ៉ា',
    'ព្រិចភ្នែក',
    'បែរក្បាលទៅខាងឆ្វេង',
    'បែរក្បាលទៅខាងស្តាំ',
  ];
  static const _labels = [
    'មើលត្រង់ទៅកាមេរ៉ា',
    'ព្រិចភ្នែកទាំងពីរមួយភ្លែត',
    'បែរក្បាលទៅខាងឆ្វេង',
    'បែរក្បាលទៅខាងស្តាំ',
    'ងើយចង្កាឡើងលើ',
    'បន្ទាបចង្កាចុះក្រោម',
  ];
  bool _isSharing = false;

  String _label(int i) {
    final list = widget.user.faceImagePaths.length == 4
        ? _legacyLabels
        : _labels;
    return i < list.length ? list[i] : 'រូបថត ${i + 1}';
  }

  Future<void> _share() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ចែករំលែករូបថតមុខ?'),
        content: const Text('រូបថតមុខនឹងត្រូវផ្ញើចេញ។ រូបថតមុខជាព័ត៌មានឯកជន។'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('បោះបង់'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('បន្ត'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _isSharing = true);
    try {
      final paths = widget.user.faceImagePaths;
      await SharePlus.instance.share(
        ShareParams(
          files: [for (final p in paths) XFile(p)],
          title: 'រូបថតមុខ ${widget.user.name}',
        ),
      );
    } catch (e) {
      debugPrint('Share failed: $e');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Collect only HRM images if they exist, otherwise local images
    final hrmPhotos = [
      for (final a in faceAngleKeys)
        if (widget.user.hrmFaceImagePaths[a] case final p?) (a, p),
    ];

    final localPhotos = [
      for (var i = 0; i < widget.user.faceImagePaths.length; i++)
        (_label(i), widget.user.faceImagePaths[i]),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('រូបថតមុខរបស់ ${widget.user.name}'),
        centerTitle: true,
        actions: [
          if (widget.user.faceImagePaths.isNotEmpty)
            IconButton(
              onPressed: _isSharing ? null : _share,
              icon: _isSharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share_outlined),
            ),
        ],
      ),
      body: !widget.user.hasFacePhotos
          ? const Center(child: Text('មិនមានរូបថតមុខសម្រាប់បុគ្គលិកនេះទេ។'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (hrmPhotos.isNotEmpty) ...[
                  _PhotoGrid(
                    photos: [
                      for (var i = 0; i < hrmPhotos.length; i++)
                        (
                          faceAngleLabelsKm[hrmPhotos[i].$1] ?? hrmPhotos[i].$1,
                          hrmPhotos[i].$2,
                          i + 1,
                        ),
                    ],
                    source: 'hrm',
                    userId: widget.user.id,
                  ),
                  const SizedBox(height: 24),
                ],
                if (localPhotos.isNotEmpty) ...[
                  if (hrmPhotos.isEmpty)
                    SectionHeader(
                      title: 'រូបថតចុះឈ្មោះមុខ',
                      subtitle: 'រូបភាព ${localPhotos.length} សន្លឹក',
                    ),
                  if (hrmPhotos.isEmpty) const SizedBox(height: 16),
                  _PhotoGrid(
                    photos: [
                      for (var i = 0; i < localPhotos.length; i++)
                        (localPhotos[i].$1, localPhotos[i].$2, i + 1),
                    ],
                    source: 'local',
                    userId: widget.user.id,
                  ),
                ],
              ],
            ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.photos,
    required this.source,
    required this.userId,
  });
  // (Label, FilePath, Index)
  final List<(String, String, int)> photos;
  final String source;
  final String userId;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9, // Matches the screenshot exactly
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final (label, path, number) = photos[index];
        final image = File(path);
        final heroTag = '$userId-$source-$index';

        return Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              16,
            ), // Rounded corners like the screenshot
            side: const BorderSide(color: AppTokens.outline),
          ),
          child: InkWell(
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) =>
                    _PhotoDetail(image: image, label: label, heroTag: heroTag),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: heroTag,
                        child: Image.file(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(
                            color: AppTokens.brandLight,
                            child: Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: AppTokens.brand,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // The Blue Number Badge
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: AppTokens.brand,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$number',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Bottom Text Section
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 8,
                  ),
                  child: Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTokens.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PhotoDetail extends StatelessWidget {
  const _PhotoDetail({
    required this.image,
    required this.label,
    required this.heroTag,
  });
  final File image;
  final String label;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Hero(
                tag: heroTag,
                child: Image.file(
                  image,
                  errorBuilder: (_, __, ___) => const Text(
                    'រូបថតមិនមាន',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xE6000000)],
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// FACE SCAN (camera)
// ═══════════════════════════════════════════════════════════
typedef _CaptureHandler = Future<void> Function(
  XFile image,
  FaceEnrollmentStep step,
);

class _FaceScanScreen extends StatefulWidget {
  const _FaceScanScreen({
    required this.title,
    required this.onCaptured,
    required this.completedButtonLabel,
    this.onCompleted,
  });
  final String title;
  final _CaptureHandler onCaptured;
  final String completedButtonLabel;
  final VoidCallback? onCompleted;

  @override
  State<_FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<_FaceScanScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  CameraLensDirection? _lensDirection;
  String _status = 'កំពុងចាប់ផ្តើមកាមេរ៉ា...';
  bool _permDenied = false;
  bool _permBlocked = false;
  bool _switching = false;
  bool _complete = false;
  bool _failed = false;
  int _step = 1;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      await _initCamera();
      return;
    }
    if (status.isDenied || status.isRestricted || status.isLimited) {
      final requested = await Permission.camera.request();
      if (requested.isGranted) {
        await _initCamera();
        return;
      }
      if (!mounted) return;
      if (requested.isPermanentlyDenied) {
        _setDenied();
        return;
      }
    }
    if (!mounted) return;
    if (status.isPermanentlyDenied) {
      _setDenied();
      return;
    }
    setState(() {
      _permDenied = false;
      _permBlocked = true;
      _status = 'មិនបានអនុញ្ញាតឱ្យប្រើកាមេរ៉ា។';
    });
  }

  void _setDenied() => setState(() {
    _permDenied = true;
    _permBlocked = true;
    _status = 'ការអនុញ្ញាតត្រូវបានបិទ។ សូមបើកក្នុងការកំណត់។';
  });

  Future<void> _initCamera({CameraLensDirection? lens}) async {
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      _cameras = cameras;
      if (cameras.isEmpty) {
        if (mounted) setState(() => _status = 'មិនមានកាមេរ៉ា។');
        return;
      }
      final selected = cameras.firstWhere(
        (c) => c.lensDirection == (lens ?? CameraLensDirection.front),
        orElse: () => cameras.first,
      );
      controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _lensDirection = selected.lensDirection;
        _permBlocked = false;
        _permDenied = false;
        _status = 'សូមដាក់មុខនៅកណ្ដាលរង្វង់។';
      });
    } catch (e) {
      await controller?.dispose();
      if (!mounted) return;
      debugPrint('Camera init failed: $e');
      setState(() => _status = 'មិនអាចចាប់ផ្ដើមកាមេរ៉ា។');
    }
  }

  Future<void> _switchCamera() async {
    if (_switching) return;
    final next = _lensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    final matches = _cameras.where((c) => c.lensDirection == next);
    if (matches.isEmpty) return;
    final previous = _controller;
    setState(() {
      _switching = true;
      _controller = null;
      _status = 'កំពុងប្តូរកាមេរ៉ា...';
      _gen++;
    });
    try {
      if (previous?.value.isStreamingImages ?? false) {
        await previous!.stopImageStream();
      }
      await previous?.dispose();
      await _initCamera(lens: matches.first.lensDirection);
    } catch (e) {
      debugPrint('Switch failed: $e');
      if (mounted) setState(() => _status = 'មិនអាចប្ដូរកាមេរ៉ា។');
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Future<void> _requestPermission() async {
    final result = await Permission.camera.request();
    if (!mounted) return;
    if (result.isGranted) {
      await _initCamera();
      return;
    }
    setState(() {
      _permDenied = result.isPermanentlyDenied;
      _permBlocked = !result.isGranted;
      _status = result.isPermanentlyDenied
          ? 'ការអនុញ្ញាតត្រូវបានបិទ។ សូមបើកក្នុងការកំណត់។'
          : 'មិនបានអនុញ្ញាតឱ្យប្រើកាមេរ៉ា។';
    });
  }

  Future<void> _handleCapture(XFile image, FaceEnrollmentStep step) async {
    if (!mounted) return;
    setState(() {
      _status = step.next == null
          ? 'កំពុងរក្សាទុក...'
          : 'កំពុងរក្សាទុកជំហាន ${step.number}...';
      _failed = false;
    });
    try {
      await widget.onCaptured(image, step);
      if (!mounted) return;
      setState(() {
        if (step.next == null) {
          _status = 'រក្សាទុករួចរាល់។';
          _complete = true;
        } else {
          _status = 'បន្ទាប់៖ ${step.next!.instruction}';
          _step = step.next!.number;
        }
      });
    } catch (e) {
      debugPrint('Capture failed: $e');
      if (!mounted) return;
      setState(() {
        _status = 'មិនអាចរក្សាទុកបានទេ។';
        _failed = true;
      });
      rethrow;
    }
  }

  void _retry() => setState(() {
    _status = 'សូមដាក់មុខនៅកណ្ដាលរង្វង់។';
    _failed = false;
    _step = 1;
    _gen++;
  });

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  bool get _hasBothCameras =>
      _cameras.any((c) => c.lensDirection == CameraLensDirection.front) &&
      _cameras.any((c) => c.lensDirection == CameraLensDirection.back);

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final blocked = controller == null && (_permBlocked || _permDenied);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white, size: 22),
        actions: [
          if (_hasBothCameras)
            IconButton(
              onPressed: _switching ? null : _switchCamera,
              icon: const Icon(Icons.flip_camera_ios_outlined),
              color: Colors.white,
            ),
        ],
      ),
      body: controller == null
          ? Center(
              child: blocked
                  ? _PermissionState(
                      permanentlyDenied: _permDenied,
                      onAllow: _requestPermission,
                      onOpenSettings: openAppSettings,
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 16),
                        Text(
                          _status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                FaceEnrollmentWidget(
                  key: ValueKey(_gen),
                  controller: controller,
                  initialStep: FaceEnrollmentStep.values[_step - 1],
                  onCaptured: _handleCapture,
                  onCompleted: () {},
                  onError: (e) {
                    debugPrint('Recognition error: $e');
                    if (mounted) {
                      setState(() {
                        _status = 'មានបញ្ហាក្នុងការស្គាល់មុខ។';
                        _failed = true;
                      });
                    }
                  },
                ),
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.05),
                        radius: 0.9,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.45),
                        ],
                        stops: const [0.5, 1],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: controller == null
            ? const SizedBox.shrink()
            : _ScanBar(
                step: _step,
                status: _status,
                complete: _complete,
                failed: _failed,
                completedLabel: widget.completedButtonLabel,
                onCompleted: widget.onCompleted,
                onRetry: _retry,
                stepTitle: (i) => FaceEnrollmentStep.values[i - 1].instruction,
              ),
      ),
    );
  }
}

class _ScanBar extends StatelessWidget {
  const _ScanBar({
    required this.step,
    required this.status,
    required this.complete,
    required this.failed,
    required this.completedLabel,
    required this.onCompleted,
    required this.onRetry,
    required this.stepTitle,
  });

  final int step;
  final String status;
  final bool complete;
  final bool failed;
  final String completedLabel;
  final VoidCallback? onCompleted;
  final VoidCallback onRetry;
  final String Function(int) stepTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var i = 1; i <= FaceEnrollmentStep.total; i++)
                Expanded(
                  child: Container(
                    height: 3,
                    margin: EdgeInsets.only(
                      right: i == FaceEnrollmentStep.total ? 0 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: i <= step
                          ? AppTokens.brand
                          : Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            complete
                ? status
                : 'ជំហាន $step / ${FaceEnrollmentStep.total} · ${stepTitle(step)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 13.5,
            ),
          ),
          if (failed) ...[
            const SizedBox(height: 8),
            Text(
              status,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
            ),
          ],
          if (complete || failed) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: complete ? (onCompleted ?? onRetry) : onRetry,
              child: Text(complete ? completedLabel : 'ព្យាយាមម្តងទៀត'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PermissionState extends StatelessWidget {
  const _PermissionState({
    required this.permanentlyDenied,
    required this.onAllow,
    required this.onOpenSettings,
  });
  final bool permanentlyDenied;
  final VoidCallback onAllow;
  final Future<void> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.camera_alt_outlined,
            size: 40,
            color: Colors.white.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            permanentlyDenied
                ? 'ត្រូវការការអនុញ្ញាតកាមេរ៉ា'
                : 'ត្រូវការកាមេរ៉ា',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            permanentlyDenied
                ? 'សូមបើកការអនុញ្ញាតប្រើកាមេរ៉ាក្នុងការកំណត់។'
                : 'សូមអនុញ្ញាតឱ្យប្រើកាមេរ៉ាដើម្បីថតរូបមុខ។',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => permanentlyDenied ? onOpenSettings() : onAllow(),
            icon: Icon(
              permanentlyDenied ? Icons.settings_outlined : Icons.camera_alt,
              size: 18,
            ),
            label: Text(permanentlyDenied ? 'បើកការកំណត់' : 'អនុញ្ញាត'),
          ),
        ],
      ),
    );
  }
}
