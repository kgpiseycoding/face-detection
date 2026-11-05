import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import 'face_enrollment.dart';
import 'face_identity_service.dart';
import 'face_store.dart';


abstract final class AppTokens {
  static const brand = Color(0xFF315CDB);
  static const brandLight = Color(0xFFE9EEFF);
  static const brandDark = Color(0xFF233F9E);
  static const surface = Color(0xFFF7F8FC);
  static const surfaceElevated = Colors.white;
  static const outline = Color(0xFFE3E7F0);
  static const success = Color(0xFF16865B);
  static const warning = Color(0xFFAA6900);
  static const danger = Color(0xFFB42318);
  static const textPrimary = Color(0xFF171B2C);
  static const textSecondary = Color(0xFF596176);
  static const textTertiary = Color(0xFF7C8498);

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;

  static const rSm = 8.0;
  static const rMd = 12.0;
  static const rLg = 16.0;
  static const rXl = 24.0;
  static const rPill = 999.0;

  static const shadowSm = [
    BoxShadow(color: Color(0x0C18213D), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const shadowMd = [
    BoxShadow(color: Color(0x1018213D), blurRadius: 18, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x0618213D), blurRadius: 3, offset: Offset(0, 1)),
  ];
  static const shadowLg = [
    BoxShadow(color: Color(0x1418213D), blurRadius: 28, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x0818213D), blurRadius: 5, offset: Offset(0, 2)),
  ];
  static const brandGradient = LinearGradient(
    colors: [Color(0xFF5478F4), brand, Color(0xFF2949B5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
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
          primaryContainer: AppTokens.brandLight,
          onPrimaryContainer: AppTokens.brandDark,
          secondary: AppTokens.brandDark,
          surface: AppTokens.surfaceElevated,
          error: AppTokens.danger,
        );
    final baseText = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
    ).textTheme;

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppTokens.surface,
      useMaterial3: true,
      textTheme: baseText.copyWith(
        displayLarge: baseText.displayLarge?.copyWith(
          color: AppTokens.textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
        ),
        headlineLarge: baseText.headlineLarge?.copyWith(
          color: AppTokens.textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
        headlineMedium: baseText.headlineMedium?.copyWith(
          color: AppTokens.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: baseText.headlineSmall?.copyWith(
          color: AppTokens.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          color: AppTokens.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          color: AppTokens.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseText.bodyLarge?.copyWith(
          color: AppTokens.textSecondary,
          height: 1.5,
        ),
        bodyMedium: baseText.bodyMedium?.copyWith(
          color: AppTokens.textSecondary,
          height: 1.45,
        ),
        bodySmall: baseText.bodySmall?.copyWith(
          color: AppTokens.textTertiary,
          height: 1.4,
        ),
        labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppTokens.surface,
        foregroundColor: AppTokens.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppTokens.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
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
        shadowColor: const Color(0x1018213D),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.xl,
            vertical: AppTokens.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.rMd),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 48),
          foregroundColor: AppTokens.brand,
          side: const BorderSide(color: AppTokens.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.rMd),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTokens.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.lg,
          vertical: AppTokens.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.rMd),
          borderSide: const BorderSide(color: AppTokens.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.rMd),
          borderSide: const BorderSide(color: AppTokens.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.rMd),
          borderSide: const BorderSide(color: AppTokens.brand, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.rMd),
          borderSide: const BorderSide(color: AppTokens.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.rMd),
          borderSide: const BorderSide(color: AppTokens.danger, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF252A38),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.rMd),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppTokens.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.rXl),
        ),
        titleTextStyle: const TextStyle(
          color: AppTokens.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(
          color: AppTokens.textSecondary,
          fontSize: 15,
          height: 1.5,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppTokens.outline,
        thickness: 1,
        space: 1,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// REUSABLE COMPONENTS
// ═══════════════════════════════════════════════════════════
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppTokens.brandGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: AppTokens.shadowSm,
      ),
      child: Icon(
        Icons.face_retouching_natural,
        color: Colors.white,
        size: size * 0.58,
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.icon,
    this.color = AppTokens.textSecondary,
    this.backgroundColor = AppTokens.surface,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.md,
        vertical: AppTokens.sm,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppTokens.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppTokens.sm),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.imageFile, this.size = 52});

  final String name;
  final File? imageFile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppTokens.brandGradient,
        shape: BoxShape.circle,
        boxShadow: AppTokens.shadowSm,
      ),
      clipBehavior: Clip.antiAlias,
      child: imageFile == null
          ? Center(
              child: Text(
                initial,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : Image.file(
              imageFile!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.38,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.tint = AppTokens.brandLight,
    this.iconColor = AppTokens.brand,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color tint;
  final Color iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.lg),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(AppTokens.rLg),
        border: Border.all(color: iconColor.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: AppTokens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTokens.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppTokens.xs),
                Text(body, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppTokens.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.color,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: IconTheme(
              data: IconThemeData(color: color),
              child: Center(child: icon),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle case final subtitle?) ...[
                const SizedBox(height: AppTokens.xs),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key, FaceStore? store, FaceIdentityService? identityService})
    : store = store ?? LocalFaceStore(),
      identityService = identityService ?? LocalFaceIdentityService();

  final FaceStore store;
  final FaceIdentityService identityService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Detection',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: UserListScreen(store: store, identityService: identityService),
    );
  }
}

class UserListScreen extends StatefulWidget {
  const UserListScreen({
    super.key,
    required this.store,
    required this.identityService,
  });

  final FaceStore store;
  final FaceIdentityService identityService;

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
      } catch (error) {
        debugPrint('Face recognition initialization failed: $error');
        recognitionError = error.toString();
      }
      if (!mounted) return;
      setState(() {
        _users = users;
        _recognitionError = recognitionError;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addUser() async {
    final name = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const AddUserScreen()));
    if (!mounted || name == null) return;

    try {
      final user = await widget.store.createUser(name);
      if (!mounted) return;
      setState(() {
        _users = [..._users, user]
          ..sort(
            (first, second) =>
                first.name.toLowerCase().compareTo(second.name.toLowerCase()),
          );
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not add user: $error')));
    }
  }

  Future<void> _enrollUser(RegisteredUser user) async {
    if (_recognitionError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Face recognition is unavailable. See the status message for details.',
          ),
        ),
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
    if (!user.faceEnrolled) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => EnrolledFacePhotosScreen(user: user)),
    );
  }

  Future<void> _showRecognitionErrorDetails() async {
    final error = _recognitionError;
    if (error == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Face recognition details'),
        content: SingleChildScrollView(child: SelectableText(error)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No AppBar to remove the huge empty gap at the top
      floatingActionButton: _users.isEmpty && !_isLoading
          ? null
          : FloatingActionButton(
              onPressed: _addUser,
              tooltip: 'Add user',
              backgroundColor: AppTokens.brand,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              child: const Icon(Icons.add),
            ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _LoadError(message: _error!, onRetry: _loadUsers)
            : RefreshIndicator(
                onRefresh: _loadUsers,
                child: _users.isEmpty
                    ? CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _EmptyUsersState(onAddUser: _addUser),
                          ),
                        ],
                      )
                    : CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                              AppTokens.xl,
                              AppTokens.xxl, // Breathing room from top edge
                              AppTokens.xl,
                              // Bottom space so FAB doesn't cover last card
                              AppTokens.xxxl + AppTokens.xxl, 
                            ),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                SectionHeader(
                                  title: 'People',
                                  subtitle:
                                      '${_users.length} ${_users.length == 1 ? 'profile' : 'profiles'} stored on this device',
                                ),
                                const SizedBox(height: AppTokens.lg),
                                if (_recognitionError != null) ...[
                                  InfoCard(
                                    icon: Icons.warning_amber_rounded,
                                    title: 'Face recognition couldn’t start.',
                                    body:
                                        'Rebuild and reinstall the app, then try again.',
                                    tint: const Color(0xFFFFF3DF),
                                    iconColor: AppTokens.warning,
                                    trailing: AppIconButton(
                                      tooltip: 'Try again',
                                      onPressed: _loadUsers,
                                      icon: const Icon(Icons.refresh),
                                      color: AppTokens.warning,
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        top: AppTokens.xs,
                                      ),
                                      child: TextButton(
                                        onPressed:
                                            _showRecognitionErrorDetails,
                                        child:
                                            const Text('Technical details'),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppTokens.md),
                                ],
                                for (
                                  var index = 0;
                                  index < _users.length;
                                  index++
                                )
                                  Padding(
                                    padding: EdgeInsets.only(
                                      bottom: index == _users.length - 1
                                          ? 0
                                          : AppTokens.md,
                                    ),
                                    child: _UserCard(
                                      user: _users[index],
                                      onTap: _users[index].faceEnrolled
                                          ? () =>
                                              _viewUserPhotos(_users[index])
                                          : null,
                                      onViewPhotos: () =>
                                          _viewUserPhotos(_users[index]),
                                      onEnroll: () =>
                                          _enrollUser(_users[index]),
                                    ),
                                  ),
                              ]),
                            ),
                          ),
                        ],
                      ),
              ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.md),
          child: Row(
            children: [
              Avatar(
                name: user.name,
                imageFile: user.faceImagePaths.isEmpty
                    ? null
                    : File(user.faceImagePaths.first),
              ),
              const SizedBox(width: AppTokens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppTokens.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: StatusChip(
                        label: enrolled ? 'Face enrolled' : 'Face not saved',
                        icon: enrolled
                            ? Icons.check_circle_outline
                            : Icons.face_outlined,
                        color: enrolled
                            ? AppTokens.success
                            : AppTokens.textSecondary,
                        backgroundColor: enrolled
                            ? const Color(0xFFE6F5EE)
                            : AppTokens.surface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.sm),
              if (enrolled)
                AppIconButton(
                  tooltip: 'View ${user.name} face photos',
                  onPressed: onViewPhotos,
                  icon: const Icon(Icons.photo_library_outlined, size: 20),
                ),
              AppIconButton(
                tooltip: enrolled
                    ? 'Re-enroll ${user.name}'
                    : 'Enroll ${user.name}',
                onPressed: onEnroll,
                icon: const Icon(Icons.face_retouching_natural, size: 20),
                color: AppTokens.brand,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyUsersState extends StatelessWidget {
  const _EmptyUsersState({required this.onAddUser});

  final VoidCallback onAddUser;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: const BoxDecoration(
                color: AppTokens.brandLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline,
                size: 48,
                color: AppTokens.brand,
              ),
            ),
            const SizedBox(height: AppTokens.xl),
            Text(
              'No users yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppTokens.sm),
            Text(
              'Add a person to create a profile and save their face on this phone.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppTokens.xl),
            FilledButton.icon(
              onPressed: onAddUser,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add user'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.xl),
        child: InfoCard(
          icon: Icons.storage_outlined,
          title: 'Could not load users saved on this phone.',
          body: message,
          tint: const Color(0xFFFFECEA),
          iconColor: AppTokens.danger,
          trailing: FilledButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ),
      ),
    );
  }
}

class AddUserScreen extends StatefulWidget {
  const AddUserScreen({super.key});

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveUser() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_nameController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add user')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.xl,
            AppTokens.xl,
            AppTokens.xl,
            AppTokens.xxl,
          ),
          children: [
            Center(child: BrandMark(size: 76)),
            const SizedBox(height: AppTokens.xl),
            Text(
              'Create a user',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppTokens.sm),
            Text(
              'Enter their name, then capture six face photos on this phone.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppTokens.xxl),
            Text(
              'PERSON DETAILS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTokens.textTertiary,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppTokens.sm),
            TextFormField(
              key: const Key('user-name-field'),
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Alex Morgan',
                prefixIcon: Icon(Icons.person_outline),
                helperText: 'Use the name you want to see in face matches.',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter a name to create this profile.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _saveUser(),
            ),
            const SizedBox(height: AppTokens.lg),
            const InfoCard(
              icon: Icons.photo_camera_outlined,
              title: '6 face photos required',
              body:
                  'Looking forward, blinking, and turning to both sides. Photos stay on this phone.',
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.xl,
            AppTokens.md,
            AppTokens.xl,
            AppTokens.lg,
          ),
          child: FilledButton.icon(
            onPressed: _saveUser,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Save user'),
          ),
        ),
      ),
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

class EnrolledFacePhotosScreen extends StatefulWidget {
  const EnrolledFacePhotosScreen({super.key, required this.user});

  final RegisteredUser user;

  @override
  State<EnrolledFacePhotosScreen> createState() =>
      _EnrolledFacePhotosScreenState();
}

class _EnrolledFacePhotosScreenState extends State<EnrolledFacePhotosScreen> {
  static const _legacySampleLabels = [
    'Facing camera',
    'Blink sample',
    'Turned to one side',
    'Turned to the other side',
  ];
  static const _sampleLabels = [
    'Facing camera',
    'Blink sample',
    'Looking up',
    'Looking down',
    'Turned right',
    'Turned left',
  ];
  bool _isSharing = false;

  String _sampleLabel(int index) {
    final labels = widget.user.faceImagePaths.length == 4
        ? _legacySampleLabels
        : _sampleLabels;
    return index < labels.length ? labels[index] : 'Face sample ${index + 1}';
  }

  String _safeFilePart(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  Future<void> _sharePhotos() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share face photos?'),
        content: Text(
          'This will send ${widget.user.faceImagePaths.length} face photos '
          'outside this app to the app you choose. Face photos are sensitive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSharing = true);
    try {
      final paths = widget.user.faceImagePaths;
      final missingPaths = <String>[];
      for (final path in paths) {
        if (!await File(path).exists()) missingPaths.add(path);
      }
      if (missingPaths.isNotEmpty) {
        throw FileSystemException(
          'Some saved face photos are missing',
          missingPaths.first,
        );
      }

      final fileNames = [
        for (var index = 0; index < paths.length; index++)
          '${_safeFilePart(widget.user.name)}-'
              '${_safeFilePart(_sampleLabel(index))}.jpg',
      ];
      await SharePlus.instance.share(
        ShareParams(
          files: [for (final path in paths) XFile(path)],
          fileNameOverrides: fileNames,
          title: '${widget.user.name} face photos',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share face photos: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.user.name} face photos'),
        actions: [
          AppIconButton(
            tooltip: 'Share face photos',
            onPressed: _isSharing ? null : _sharePhotos,
            icon: _isSharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share_outlined),
          ),
          const SizedBox(width: AppTokens.sm),
        ],
      ),
      body: widget.user.faceImagePaths.isEmpty
          ? const Center(
              child: InfoCard(
                icon: Icons.photo_outlined,
                title: 'No face photos saved for this user.',
                body: 'Enroll this person to save their six camera samples.',
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.xl,
                    AppTokens.lg,
                    AppTokens.xl,
                    AppTokens.xl,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      SectionHeader(
                        title: 'Enrollment photos',
                        subtitle:
                            '${widget.user.faceImagePaths.length} local samples',
                      ),
                      const SizedBox(height: AppTokens.lg),
                    ]),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.xl,
                    0,
                    AppTokens.xl,
                    AppTokens.xxl,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: AppTokens.md,
                          mainAxisSpacing: AppTokens.md,
                          childAspectRatio: 1.1,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final label = _sampleLabel(index);
                      final image = File(widget.user.faceImagePaths[index]);
                      final heroTag = '${widget.user.id}-face-photo-$index';
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => _FacePhotoDetailScreen(
                                image: image,
                                label: label,
                                heroTag: heroTag,
                              ),
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
                                        errorBuilder:
                                            (
                                              context,
                                              error,
                                              stackTrace,
                                            ) => const ColoredBox(
                                              color: AppTokens.brandLight,
                                              child: Center(
                                                child: Icon(
                                                  Icons.broken_image_outlined,
                                                  size: 40,
                                                  color: AppTokens.brand,
                                                ),
                                              ),
                                            ),
                                      ),
                                    ),
                                    Positioned(
                                      top: AppTokens.sm,
                                      left: AppTokens.sm,
                                      child: Container(
                                        width: 30,
                                        height: 30,
                                        alignment: Alignment.center,
                                        decoration: const BoxDecoration(
                                          color: AppTokens.brand,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(AppTokens.md),
                                child: Text(
                                  label,
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }, childCount: widget.user.faceImagePaths.length),
                  ),
                ),
              ],
            ),
    );
  }
}

class _FacePhotoDetailScreen extends StatelessWidget {
  const _FacePhotoDetailScreen({
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
        title: const Text('Photo detail'),
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
                  errorBuilder: (context, error, stackTrace) => const Padding(
                    padding: EdgeInsets.all(AppTokens.xl),
                    child: Text(
                      'This photo is unavailable on this phone.',
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppTokens.xl,
                AppTokens.xxl,
                AppTokens.xl,
                AppTokens.xxl,
              ),
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
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
    final previousSample = _samples[step];
    _samples[step] = image;
    if (previousSample != null && previousSample.path != image.path) {
      await _deleteTemporaryPhoto(previousSample.path);
    }
    if (step != FaceEnrollmentStep.turnLeft) return;
    final orderedSamples = [
      for (final enrollmentStep in FaceEnrollmentStep.values)
        _samples[enrollmentStep]!,
    ];
    final enrolledUser = await widget.store.enrollUser(
      widget.user.id,
      orderedSamples,
    );
    await widget.identityService.completeEnrollment(
      sessionId: _sessionId,
      user: enrolledUser,
    );
    for (final sample in orderedSamples) {
      await _deleteTemporaryPhoto(sample.path);
    }
  }

  Future<void> _deleteTemporaryPhoto(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  @override
  void dispose() {
    unawaited(
      widget.identityService.cancelEnrollment(_sessionId).catchError((error) {
        debugPrint('Could not clear temporary face enrollment: $error');
      }),
    );
    for (final sample in _samples.values) {
      unawaited(
        _deleteTemporaryPhoto(sample.path).catchError((error) {
          debugPrint('Could not remove temporary face photo: $error');
        }),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FaceScanScreen(
      title: '',
      onCaptured: _saveSample,
      completedButtonLabel: 'បញ្ចប់',
      onCompleted: () => Navigator.of(context).pop(true),
    );
  }
}

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
  bool _permissionPermanentlyDenied = false;
  bool _cameraPermissionBlocked = false;
  bool _isSwitchingCamera = false;
  bool _captureComplete = false;
  bool _captureFailed = false;
  int _currentStep = 1;
  int _scannerGeneration = 0;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      await _initializeCamera();
      return;
    }

    if (status.isDenied || status.isRestricted || status.isLimited) {
      final requested = await Permission.camera.request();
      if (requested.isGranted) {
        await _initializeCamera();
        return;
      }
      if (!mounted) return;
      if (requested.isPermanentlyDenied) {
        setState(() {
          _permissionPermanentlyDenied = true;
          _cameraPermissionBlocked = true;
          _status = 'ការអនុញ្ញាតប្រើកាមេរ៉ាត្រូវបានបិទជាអចិន្ត្រៃយ៍។ '
              'សូមបើកវានៅក្នុងការកំណត់។';
        });
        return;
      }
    }

    if (!mounted) return;
    if (status.isPermanentlyDenied) {
      setState(() {
        _permissionPermanentlyDenied = true;
        _cameraPermissionBlocked = true;
        _status = 'ការអនុញ្ញាតប្រើកាមេរ៉ាត្រូវបានបិទជាអចិន្ត្រៃយ៍។ '
            'សូមបើកវានៅក្នុងការកំណត់។';
      });
      return;
    }

    setState(() {
      _permissionPermanentlyDenied = false;
      _cameraPermissionBlocked = true;
      _status = 'មិនបានអនុញ្ញាតឱ្យប្រើកាមេរ៉ាទេ។';
    });
  }

  Future<void> _initializeCamera({CameraLensDirection? lensDirection}) async {
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      _cameras = cameras;
      if (cameras.isEmpty) {
        if (mounted) setState(() => _status = 'មិនមានកាមេរ៉ាទេ។');
        return;
      }

      final selectedCamera = cameras.firstWhere(
        (camera) =>
            camera.lensDirection ==
            (lensDirection ?? CameraLensDirection.front),
        orElse: () => cameras.first,
      );
      controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _lensDirection = selectedCamera.lensDirection;
        _cameraPermissionBlocked = false;
        _status = 'សូមដាក់មុខនៅកណ្ដាលរង្វង់។';
        _permissionPermanentlyDenied = false;
      });
    } catch (error) {
      await controller?.dispose();
      if (!mounted) return;
      setState(() => _status = 'មិនអាចចាប់ផ្តើមកាមេរ៉ាបានទេ៖ $error');
    }
  }

  Future<void> _switchCamera() async {
    if (_isSwitchingCamera) return;
    final nextDirection = _lensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    final matchingCameras = _cameras.where(
      (camera) => camera.lensDirection == nextDirection,
    );
    if (matchingCameras.isEmpty) return;
    final nextCamera = matchingCameras.first;

    final previousController = _controller;
    setState(() {
      _isSwitchingCamera = true;
      _controller = null;
      _status = 'កំពុងប្តូរកាមេរ៉ា...';
      _scannerGeneration++;
    });
    try {
      if (previousController?.value.isStreamingImages ?? false) {
        await previousController!.stopImageStream();
      }
      await previousController?.dispose();
      await _initializeCamera(lensDirection: nextCamera.lensDirection);
    } catch (error) {
      if (mounted) {
        setState(() => _status = 'មិនអាចប្តូរកាមេរ៉ាបានទេ៖ $error');
      }
    } finally {
      if (mounted) setState(() => _isSwitchingCamera = false);
    }
  }

  Future<void> _requestPermission() async {
    final result = await Permission.camera.request();
    if (!mounted) return;
    if (result.isGranted) {
      await _initializeCamera();
      return;
    }

    setState(() {
      _permissionPermanentlyDenied = result.isPermanentlyDenied;
      _cameraPermissionBlocked = !result.isGranted;
      _status = result.isPermanentlyDenied
          ? 'ការអនុញ្ញាតប្រើកាមេរ៉ាត្រូវបានបិទជាអចិន្ត្រៃយ៍។ '
                'សូមបើកវានៅក្នុងការកំណត់។'
          : 'មិនបានអនុញ្ញាតឱ្យប្រើកាមេរ៉ាទេ។';
    });
  }

  Future<void> _handleCapture(XFile image, FaceEnrollmentStep step) async {
    if (!mounted) return;
    setState(() {
      _status = step.next == null
          ? 'កំពុងរក្សាទុកការចុះឈ្មោះមុខក្នុងទូរស័ព្ទនេះ...'
          : 'កំពុងរក្សាទុកជំហាន ${step.number}...';
      _captureFailed = false;
    });
    try {
      await widget.onCaptured(image, step);
      if (!mounted) return;
      setState(() {
        if (step.next == null) {
          _status = 'ការចុះឈ្មោះមុខត្រូវបានរក្សាទុកក្នុងទូរស័ព្ទនេះ។';
          _captureComplete = true;
        } else {
          _status = 'បានរក្សាទុកជំហាន ${step.number}។ '
              'បន្ទាប់៖ ${step.next!.instruction}';
          _currentStep = step.next!.number;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = '$error';
        _captureFailed = true;
      });
      rethrow;
    }
  }

  void _retryCapture() {
    setState(() {
      _status = 'សូមដាក់មុខនៅកណ្ដាលរង្វង់។';
      _captureFailed = false;
      _currentStep = 1;
      _scannerGeneration++;
    });
  }

  Future<void> _openSettings() async {
    await openAppSettings();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final permissionBlocked =
        controller == null &&
        (_cameraPermissionBlocked || _permissionPermanentlyDenied);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (_cameras.any(
                (camera) => camera.lensDirection == CameraLensDirection.front,
              ) &&
              _cameras.any(
                (camera) => camera.lensDirection == CameraLensDirection.back,
              ))
            AppIconButton(
              tooltip: _lensDirection == CameraLensDirection.front
                  ? 'ប្តូរទៅកាមេរ៉ាខាងក្រោយ'
                  : 'ប្តូរទៅកាមេរ៉ាខាងមុខ',
              onPressed: _isSwitchingCamera ? null : _switchCamera,
              icon: const Icon(Icons.autorenew_rounded),
              color: Colors.white,
            ),
          const SizedBox(width: AppTokens.sm),
        ],
      ),
      body: controller == null
          ? Center(
              child: permissionBlocked
                  ? _CameraPermissionState(
                      permanentlyDenied: _permissionPermanentlyDenied,
                      onAllow: _requestPermission,
                      onOpenSettings: _openSettings,
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: AppTokens.lg),
                        Text(
                          _status,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                FaceEnrollmentWidget(
                  key: ValueKey(_scannerGeneration),
                  controller: controller,
                  initialStep: FaceEnrollmentStep.values[_currentStep - 1],
                  onCaptured: _handleCapture,
                  onCompleted: () {},
                  onError: (error) {
                    if (mounted) {
                      setState(() {
                        _status = 'កំហុសក្នុងការស្គាល់មុខ៖ $error';
                        _captureFailed = true;
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
                          Colors.black.withValues(alpha: 0.48),
                        ],
                        stops: const [0.48, 1],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: controller == null
            ? const SizedBox.shrink()
            : Container(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.xl,
                  AppTokens.lg,
                  AppTokens.xl,
                  AppTokens.lg,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xF20C1019),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppTokens.rXl),
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        for (
                          var index = 1;
                          index <= FaceEnrollmentStep.total;
                          index++
                        )
                          Expanded(
                            child: Container(
                              height: 5,
                              margin: EdgeInsets.only(
                                right: index == FaceEnrollmentStep.total
                                    ? 0
                                    : AppTokens.sm,
                              ),
                              decoration: BoxDecoration(
                                color: index <= _currentStep
                                    ? const Color(0xFF75E3B0)
                                    : Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(
                                  AppTokens.rPill,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.md),
                    Text(
                      _captureComplete
                          ? _status
                          : 'ជំហាន $_currentStep ក្នុង '
                                '${FaceEnrollmentStep.total} · '
                                '${_stepTitle(_currentStep)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_captureFailed) ...[
                      const SizedBox(height: AppTokens.sm),
                      Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFFFB4AB)),
                      ),
                    ],
                    if (_captureComplete || _captureFailed) ...[
                      const SizedBox(height: AppTokens.md),
                      FilledButton(
                        onPressed: _captureComplete
                            ? (widget.onCompleted ?? _retryCapture)
                            : _retryCapture,
                        child: Text(
                          _captureComplete
                              ? widget.completedButtonLabel
                              : 'ព្យាយាមម្តងទៀត',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  String _stepTitle(int step) =>
      FaceEnrollmentStep.values[step - 1].instruction;
}

class _CameraPermissionState extends StatelessWidget {
  const _CameraPermissionState({
    required this.permanentlyDenied,
    required this.onAllow,
    required this.onOpenSettings,
  });

  final bool permanentlyDenied;
  final VoidCallback onAllow;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTokens.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt_outlined,
              size: 44,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppTokens.xl),
          Text(
            permanentlyDenied
                ? 'អនុញ្ញាតឱ្យប្រើកាមេរ៉ានៅក្នុងការកំណត់'
                : 'ត្រូវការការអនុញ្ញាតប្រើកាមេរ៉ា',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppTokens.sm),
          Text(
            permanentlyDenied
                ? 'សូមអនុញ្ញាតឱ្យប្រើកាមេរ៉ានៅក្នុងការកំណត់ ដើម្បីថតរូបមុខ។'
                : 'សូមអនុញ្ញាតឱ្យប្រើកាមេរ៉ា ដើម្បីណែនាំការថត និងរក្សាទុករូបមុខទាំងប្រាំមួយក្នុងទូរស័ព្ទនេះ។',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: AppTokens.xl),
          FilledButton.icon(
            onPressed: permanentlyDenied ? onOpenSettings : onAllow,
            icon: Icon(
              permanentlyDenied ? Icons.settings_outlined : Icons.camera_alt,
            ),
            label: Text(
              permanentlyDenied ? 'បើកការកំណត់' : 'អនុញ្ញាតប្រើកាមេរ៉ា',
            ),
          ),
        ],
      ),
    );
  }
}