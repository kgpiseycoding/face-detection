import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'face_identity_service.dart';
import 'face_store.dart';

class VerifyFaceScreen extends StatefulWidget {
  const VerifyFaceScreen({
    super.key,
    required this.identityService,
    required this.users,
  });

  final FaceIdentityService identityService;
  final List<RegisteredUser> users;

  @override
  State<VerifyFaceScreen> createState() => _VerifyFaceScreenState();
}

class _VerifyFaceScreenState extends State<VerifyFaceScreen> {
  CameraController? _controller;
  bool _isChecking = false;
  String _status = 'Starting camera...';
  Color _statusColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    CameraController? controller;
    try {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        throw StateError(
          permission.isPermanentlyDenied
              ? 'Camera permission is disabled. Enable it in Settings.'
              : 'Camera permission is required to verify a face.',
        );
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('No camera is available.');
      final front = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _status = 'Center one face, then tap Verify face.';
      });
    } catch (error) {
      await controller?.dispose();
      if (!mounted) return;
      setState(() {
        _status = '$error';
        _statusColor = Colors.orangeAccent;
      });
    }
  }

  Future<void> _verifyFace() async {
    final controller = _controller;
    if (controller == null || _isChecking) return;

    XFile? photo;
    setState(() {
      _isChecking = true;
      _status = 'Checking the face on this phone...';
      _statusColor = Colors.white;
    });

    try {
      photo = await controller.takePicture();
      final userId = await widget.identityService.recognizeImage(photo.path);
      if (!mounted) return;
      final matches = userId == null
          ? const <RegisteredUser>[]
          : widget.users.where((user) => user.id == userId).toList();
      final matchedUser = matches.isEmpty ? null : matches.first;
      setState(() {
        _status = matchedUser == null
            ? 'Unknown person — no enrolled face matched.'
            : 'Matched: ${matchedUser.name}';
        _statusColor = matchedUser == null
            ? Colors.orangeAccent
            : Colors.greenAccent;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = '$error';
        _statusColor = Colors.orangeAccent;
      });
    } finally {
      String? cleanupError;
      if (photo != null) {
        try {
          final file = File(photo.path);
          if (await file.exists()) await file.delete();
        } catch (error) {
          cleanupError = 'Could not remove temporary photo: $error';
        }
      }
      if (mounted) {
        setState(() {
          _isChecking = false;
          if (cleanupError != null) {
            _status = cleanupError;
            _statusColor = Colors.orangeAccent;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Verify face'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: controller == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _statusColor, fontSize: 18),
                ),
              ),
            )
          : Column(
              children: [
                Expanded(child: CameraPreview(controller)),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _statusColor, fontSize: 17),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'One face at a time. Matching runs locally and can be wrong; '
                        'do not use it as the only security check.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _isChecking ? null : _verifyFace,
                        icon: _isChecking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.fact_check_outlined),
                        label: const Text('Verify face'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
