import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../api/hrm_api_exception.dart';
import '../api/hrm_face_api.dart';
import '../constants/face_angles.dart';
import '../face_store.dart';
import '../models/employee.dart';
import '../models/face_angle_info.dart';
import '../services/image_preparer.dart';
import 'camera_capture_screen.dart';

/// Central blue palette for this screen.
class _BluePalette {
  static const Color primary = Color(0xFF1E6FD9);
  static const Color primaryDark = Color(0xFF0F4C9E);
  static const Color primaryLight = Color(0xFF4A90E2);
  static const Color surface = Color(0xFFF5F8FD);
  static const Color success = Color(0xFF1E6FD9); // blue replaces green
  static const Color warning = Color(0xFFE8A33D);
  static const Color danger = Color(0xFFD9534F);
}

class EnrollmentScreen extends StatefulWidget {
  const EnrollmentScreen({
    super.key,
    required this.api,
    required this.employee,
    this.store,
    this.userId,
  });

  final HrmFaceApi api;
  final Employee employee;
  final FaceStore? store;
  final String? userId;

  @override
  State<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen> {
  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------
  Set<String> _saved = {};
  Set<String> _missing = faceAngleKeys.toSet();
  Map<String, String> _verificationStatuses = {};
  Map<String, String> _cachedImagePaths = {};
  String? _loadingAngle;
  bool _isLoading = true;
  bool _isSyncingImages = false;
  bool _isBatchUploading = false;
  int _batchUploadIndex = 0;
  bool _blockedByApiError = false;
  String? _loadError;
  String? _imageSyncError;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _loadSavedAngles();
  }

  Future<void> _loadSavedAngles({bool returnToMainWhenComplete = false}) async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final response = await widget.api.employeeAngles(
        widget.employee.employeeCode,
      );
      if (response is! Map<String, dynamic>) {
        throw const FormatException('Saved angle response is not an object.');
      }

      final angles = _angleKeys(response['angles']);
      final verificationStatuses = _angleStatuses(response['angles']);
      final missingValue = response['missing'];
      late final Set<String> missing;
      if (missingValue is List) {
        missing = _angleKeys(missingValue);
        angles
          ..clear()
          ..addAll(faceAngleKeys.where((angle) => !missing.contains(angle)));
      } else {
        missing = faceAngleKeys
            .where((angle) => !angles.contains(angle))
            .toSet();
      }

      if (!mounted) return;
      setState(() {
        _saved = angles;
        _missing = missing;
        _verificationStatuses = verificationStatuses;
        _isLoading = false;
        _blockedByApiError = false;
      });
      await _syncImages(angles);
      if (returnToMainWhenComplete &&
          mounted &&
          angles.length == faceAngleKeys.length &&
          missing.isEmpty) {
        Navigator.of(context).pop(true);
      }
    } on HrmApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.userMessage;
        _isLoading = false;
        _blockedByApiError = _isBlockingStatus(error.statusCode);
      });
    } on Object catch (error, stackTrace) {
      debugPrint('Could not load HRM face angles: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _loadError =
            'មិនអាចផ្ទុកទិន្នន័យមុខមូគពីប្រព័ន្ធបានទេ។ '
            'សូមព្យាយាមម្តងទៀត។';
        _isLoading = false;
      });
    }
  }

  Future<void> _syncImages(Set<String> angles) async {
    final store = widget.store;
    final userId = widget.userId;
    if (!mounted || store == null || userId == null) return;

    setState(() {
      _isSyncingImages = true;
      _imageSyncError = null;
    });
    try {
      final users = await store.listUsers();
      for (final user in users) {
        if (user.id == userId) {
          if (mounted) {
            setState(() => _cachedImagePaths = user.hrmFaceImagePaths);
          }
          break;
        }
      }
      final savedAngles = faceAngleKeys.where(angles.contains).toList();
      final downloadedImages = await Future.wait(
        savedAngles.map(
          (angle) => widget.api.employeeAngleImage(
            widget.employee.employeeCode,
            angle,
          ),
        ),
      );
      final images = <String, Uint8List>{
        for (var index = 0; index < savedAngles.length; index++)
          savedAngles[index]: downloadedImages[index],
      };
      final user = await store.saveHrmFaceImages(
        userId,
        images,
        replaceExisting: true,
      );
      if (mounted) {
        setState(() => _cachedImagePaths = user.hrmFaceImagePaths);
      }
    } on HrmApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _imageSyncError =
            'មិនអាចទាញយករូបភាពមុខពីប្រព័ន្ធបានទេ៖ ${error.userMessage}';
      });
    } on Object catch (error, stackTrace) {
      debugPrint(
        'Could not download or save HRM face-angle images: $error\n$stackTrace',
      );
      if (!mounted) return;
      setState(() {
        _imageSyncError =
            'មិនអាចទាញយក ឬរក្សាទុករូបភាពមុខបានទេ។ សូមព្យាយាមម្តងទៀត។';
      });
    } finally {
      if (mounted) setState(() => _isSyncingImages = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Parsing helpers
  // ---------------------------------------------------------------------------
  Set<String> _angleKeys(Object? value) {
    if (value is! List) return {};
    return value
        .map((item) {
          if (item is String) return item;
          if (item is Map<String, dynamic>) {
            return FaceAngleInfo.fromJson(item).angle;
          }
          return '';
        })
        .where(faceAngleKeys.contains)
        .toSet();
  }

  Map<String, String> _angleStatuses(Object? value) {
    if (value is! List) return {};
    return {
      for (final item in value)
        if (item is Map<String, dynamic> &&
            item['angle'] is String &&
            item['verificationStatus'] is String)
          item['angle'] as String: item['verificationStatus'] as String,
    };
  }

  // ---------------------------------------------------------------------------
  // Capture single angle
  // ---------------------------------------------------------------------------
  Future<void> _captureAngle(String angle) async {
    if (_blockedByApiError || _loadingAngle != null || _isBatchUploading) {
      return;
    }
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CameraCaptureScreen(
          targetAngle: angle,
          employeeName: widget.employee.displayName,
        ),
      ),
    );
    if (!mounted || path == null) return;

    setState(() => _loadingAngle = angle);
    try {
      final jpeg = await ImagePreparer.prepareForUpload(path);
      await widget.api.uploadAngle(widget.employee.employeeCode, angle, jpeg);
      _showMessage(
        'បានបញ្ចូលរូបភាព ${faceAngleLabelsKm[angle] ?? angle} ទៅ HRM។',
      );
      final store = widget.store;
      final userId = widget.userId;
      if (store != null && userId != null) {
        try {
          final user = await store.saveHrmFaceImages(userId, {angle: jpeg});
          if (mounted) {
            setState(() => _cachedImagePaths = user.hrmFaceImagePaths);
          }
        } on Object catch (error, stackTrace) {
          debugPrint('Could not cache uploaded HRM image: $error\n$stackTrace');
          _showMessage(
            'បានបញ្ចូលទៅ HRM ប៉ុន្តែមិនអាចរក្សាទុករូបភាពក្នុងឧបករណ៍បានទេ។',
          );
        }
      }
      if (mounted) {
        await _loadSavedAngles(returnToMainWhenComplete: true);
      }
    } on HrmApiException catch (error) {
      if (!mounted) return;
      if (_isBlockingStatus(error.statusCode)) {
        setState(() => _blockedByApiError = true);
      }
      _showMessage(error.userMessage);
    } on Object {
      if (!mounted) return;
      _showMessage('មិនអាចបញ្ចូលរូបភាពបានទេ។ សូមព្យាយាមម្តងទៀត។');
    } finally {
      if (mounted) setState(() => _loadingAngle = null);
    }
  }

  // ---------------------------------------------------------------------------
  // Capture all angles
  // ---------------------------------------------------------------------------
  Future<void> _captureAllAngles() async {
    if (_blockedByApiError ||
        _loadingAngle != null ||
        _isBatchUploading ||
        _isSyncingImages) {
      return;
    }

    final paths = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => CameraCaptureScreen(
          targetAngle: faceAngleKeys.first,
          employeeName: widget.employee.displayName,
          autoCaptureAll: true,
        ),
      ),
    );
    if (!mounted || paths == null) return;
    if (paths.length != faceAngleKeys.length) {
      _showMessage(
        'ការថតរូបបានតែ ${paths.length} រូប ប៉ុន្តែត្រូវការ ${faceAngleKeys.length} រូប។ '
        'សូមព្យាយាមម្តងទៀត។',
      );
      return;
    }

    setState(() {
      _isBatchUploading = true;
      _batchUploadIndex = 0;
    });
    var uploaded = 0;
    var uploadCompleted = false;
    String? failedAngle;
    try {
      for (var index = 0; index < faceAngleKeys.length; index++) {
        final angle = faceAngleKeys[index];
        failedAngle = angle;
        setState(() => _batchUploadIndex = index + 1);
        final jpeg = await ImagePreparer.prepareForUpload(paths[index]);
        await widget.api.uploadAngle(widget.employee.employeeCode, angle, jpeg);
        uploaded++;

        final store = widget.store;
        final userId = widget.userId;
        if (store != null && userId != null) {
          final user = await store.saveHrmFaceImages(userId, {angle: jpeg});
          if (mounted) {
            setState(() => _cachedImagePaths = user.hrmFaceImagePaths);
          }
        }
      }
      uploadCompleted = true;
      _showMessage('បានបញ្ចូលរូបភាពទាំងអស់ទៅ HRM រួចរាល់។');
    } on HrmApiException catch (error) {
      if (_isBlockingStatus(error.statusCode)) {
        setState(() => _blockedByApiError = true);
      }
      _showMessage(
        'បានបញ្ចូល $uploaded ក្នុងចំណោម ${faceAngleKeys.length} រូប។ '
        '${faceAngleLabelsKm[failedAngle] ?? failedAngle} បរាជ័យ៖ '
        '${error.userMessage}',
      );
    } on Object catch (error, stackTrace) {
      debugPrint('Auto enrollment upload failed: $error\n$stackTrace');
      _showMessage(
        'បានបញ្ចូល $uploaded ក្នុងចំណោម ${faceAngleKeys.length} រូប។ '
        'មិនអាចបញ្ចូល ${faceAngleLabelsKm[failedAngle] ?? failedAngle} បានទេ។ '
        'សូមពិនិត្យការតភ្ជាប់ហើយព្យាយាមម្តងទៀត។',
      );
    } finally {
      if (mounted) {
        await _loadSavedAngles(returnToMainWhenComplete: uploadCompleted);
        if (mounted) {
          setState(() {
            _isBatchUploading = false;
            _batchUploadIndex = 0;
          });
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  bool _isBlockingStatus(int statusCode) =>
      statusCode == 401 || statusCode == 404 || statusCode == 503;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _BluePalette.primaryDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  Color _statusColor(String? status) => switch (status) {
    'matched' => _BluePalette.primary,
    'many_faces' => _BluePalette.warning,
    'profile_mismatch' => _BluePalette.danger,
    _ => Colors.grey,
  };

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = _blueTheme(Theme.of(context));
    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: _BluePalette.surface,
        appBar: AppBar(
          backgroundColor: _BluePalette.primary,
          foregroundColor: Colors.white,
          title: Text(
            widget.employee.displayName,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 2,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: _BluePalette.primary),
              )
            : _loadError != null
            ? _buildLoadError(theme)
            : _buildContent(theme),
      ),
    );
  }

  /// Apply the blue palette on top of the ambient theme.
  ThemeData _blueTheme(ThemeData base) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: _BluePalette.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: _BluePalette.primary,
          onPrimary: Colors.white,
          secondary: _BluePalette.primaryLight,
          surface: _BluePalette.surface,
        );
    return base.copyWith(
      colorScheme: scheme,
      snackBarTheme: base.snackBarTheme.copyWith(
        backgroundColor: _BluePalette.primaryDark,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Error state
  // ---------------------------------------------------------------------------
  Widget _buildLoadError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: _BluePalette.primary,
            ),
            const SizedBox(height: 16),
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadSavedAngles,
              icon: const Icon(Icons.refresh),
              label: const Text('ព្យាយាមម្តងទៀត'),
              style: FilledButton.styleFrom(
                backgroundColor: _BluePalette.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Main content
  // ---------------------------------------------------------------------------
  Widget _buildContent(ThemeData theme) {
    final capturedCount = _saved.length;
    final total = faceAngleKeys.length;
    final progress = total == 0 ? 0.0 : capturedCount / total;
    final isComplete = capturedCount == total;

    return RefreshIndicator(
      color: _BluePalette.primary,
      onRefresh: _loadSavedAngles,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildBatchButton(theme),
          if (_blockedByApiError) ...[
            const SizedBox(height: 16),
            _buildBlockedBanner(theme),
          ],
          if (_isSyncingImages) ...[
            const SizedBox(height: 16),
            _buildSyncIndicator(theme),
          ],
          if (_imageSyncError case final error?) ...[
            const SizedBox(height: 16),
            _buildSyncErrorCard(theme, error),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: _BluePalette.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'មុំមុខ',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _BluePalette.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final angle in faceAngleKeys) _buildAngleCard(theme, angle),
          if (isComplete) ...[
            const SizedBox(height: 8),
            _buildCompletionCard(theme),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Progress header
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Batch capture button
  // ---------------------------------------------------------------------------
  Widget _buildBatchButton(ThemeData theme) {
    final disabled =
        _blockedByApiError ||
        _loadingAngle != null ||
        _isBatchUploading ||
        _isSyncingImages;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: disabled ? null : _captureAllAngles,
        icon: _isBatchUploading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.auto_awesome),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            _isBatchUploading
                ? 'កំពុងបញ្ចូល $_batchUploadIndex ក្នុងចំណោម ${faceAngleKeys.length}...'
                : 'ថតរូបទាំង ៦ មុំដោយស្វ័យប្រវត្តិ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _BluePalette.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _BluePalette.primary.withOpacity(0.35),
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Blocked banner
  // ---------------------------------------------------------------------------
  Widget _buildBlockedBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _BluePalette.danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _BluePalette.danger.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline_rounded, color: _BluePalette.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'គណនីនេះត្រូវបានផ្អាកមិនអាចប្រើ HRM API បានទេ។ '
              'សូមទាក់ទងអ្នកគ្រប់គ្រងដើម្បីដោះស្រាយ។',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _BluePalette.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sync indicator
  // ---------------------------------------------------------------------------
  Widget _buildSyncIndicator(ThemeData theme) {
    return Row(
      children: [
        const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: _BluePalette.primary,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'កំពុងធ្វើសមកាលកម្មរូបភាពពី HRM...',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: _BluePalette.primaryDark,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Sync error card
  // ---------------------------------------------------------------------------
  Widget _buildSyncErrorCard(ThemeData theme, String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _BluePalette.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _BluePalette.warning.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: _BluePalette.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF7A5200),
              ),
            ),
          ),
          IconButton(
            tooltip: 'ទាញយករូបភាពម្តងទៀត',
            onPressed: _isSyncingImages ? null : () => _syncImages(_saved),
            icon: const Icon(Icons.refresh, color: _BluePalette.primary),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Angle card
  // ---------------------------------------------------------------------------
  Widget _buildAngleCard(ThemeData theme, String angle) {
    final saved = _saved.contains(angle) && !_missing.contains(angle);
    final isUploading = _loadingAngle == angle;
    final label = faceAngleLabelsKm[angle] ?? angle;
    final imagePath = _cachedImagePaths[angle];
    final verificationStatus = _verificationStatuses[angle];
    final statusColor = _statusColor(verificationStatus);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: saved
              ? _BluePalette.primary.withOpacity(0.45)
              : theme.colorScheme.outlineVariant,
          width: saved ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                _buildStatusIcon(saved, isUploading, statusColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _BluePalette.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildAngleActionButton(saved, isUploading, angle),
              ],
            ),
          ),
          if (imagePath != null) _buildAngleImage(imagePath),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(bool saved, bool isUploading, Color statusColor) {
    if (isUploading) {
      return const SizedBox.square(
        dimension: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: _BluePalette.primary,
        ),
      );
    }
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: saved
            ? _BluePalette.primary.withOpacity(0.12)
            : Colors.grey.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        saved ? Icons.check_rounded : Icons.face_outlined,
        color: saved ? _BluePalette.primary : Colors.grey,
        size: 22,
      ),
    );
  }

  Widget _buildAngleActionButton(bool saved, bool isUploading, String angle) {
    final disabled =
        _loadingAngle != null || _blockedByApiError || _isBatchUploading;

    if (saved) {
      return OutlinedButton(
        onPressed: disabled ? null : () => _captureAngle(angle),
        style: OutlinedButton.styleFrom(
          foregroundColor: _BluePalette.primary,
          side: BorderSide(
            color: _BluePalette.primary.withOpacity(0.5),
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
        child: const Text(
          'ថតឡើងវិញ',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }
    return FilledButton(
      onPressed: disabled ? null : () => _captureAngle(angle),
      style: FilledButton.styleFrom(
        backgroundColor: _BluePalette.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      child: isUploading
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text('ថតរូប', style: TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildAngleImage(String imagePath) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(imagePath),
          height: 150,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            height: 80,
            alignment: Alignment.center,
            color: _BluePalette.primary.withOpacity(0.05),
            child: const Text('មិនអាចបង្ហាញរូបភាពបានទេ'),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Completion card
  // ---------------------------------------------------------------------------
  Widget _buildCompletionCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _BluePalette.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _BluePalette.primary.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _BluePalette.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: _BluePalette.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'បានចុះឈ្មោះមុខទាំងអស់ដោយជោគជ័យ',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: _BluePalette.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
