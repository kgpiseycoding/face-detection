import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class RegisteredUser {
  const RegisteredUser({
    required this.id,
    required this.name,
    this.faceImagePaths = const [],
    this.createdAt,
    this.createdBy,
  });

  final String id;
  final String name;
  final List<String> faceImagePaths;
  final DateTime? createdAt;
  final String? createdBy;

  bool get faceEnrolled => faceImagePaths.isNotEmpty;

  factory RegisteredUser.fromMap(Map<String, Object?> row) {
    final storedPaths = row['face_image_paths'] as String?;
    final legacyPath = row['face_image_path'] as String?;
    return RegisteredUser(
      id: row['id']! as String,
      name: row['name']! as String,
      faceImagePaths: storedPaths == null
          ? (legacyPath == null ? const [] : [legacyPath])
          : (jsonDecode(storedPaths) as List<dynamic>).cast<String>(),
      createdAt: row['created_at'] == null
          ? null
          : DateTime.parse(row['created_at']! as String).toUtc(),
      createdBy: row['created_by'] as String?,
    );
  }
}

class StoredFaceSample {
  const StoredFaceSample({
    required this.userId,
    required this.sampleIndex,
    required this.pose,
    required this.imageData,
    required this.createdAt,
    this.createdBy,
  });

  final String userId;
  final int sampleIndex;
  final String pose;
  final Uint8List imageData;
  final DateTime createdAt;
  final String? createdBy;

  factory StoredFaceSample.fromMap(Map<String, Object?> row) {
    return StoredFaceSample(
      userId: row['user_id']! as String,
      sampleIndex: row['sample_index']! as int,
      pose: row['pose']! as String,
      imageData: row['image']! as Uint8List,
      createdAt: DateTime.parse(row['created_at']! as String).toUtc(),
      createdBy: row['created_by'] as String?,
    );
  }
}

abstract interface class FaceStore {
  Future<List<RegisteredUser>> listUsers();
  Future<RegisteredUser> createUser(String name);
  Future<RegisteredUser> enrollUser(String userId, List<XFile> images);
}

class LocalFaceStore implements FaceStore {
  static const _poseNames = [
    'front',
    'blink',
    'look_up',
    'look_down',
    'turn_right',
    'turn_left',
  ];
  static const _legacyPoseNames = [
    'front',
    'blink',
    'turn_first_side',
    'turn_other_side',
  ];

  Database? _database;
  final Random _random = Random.secure();

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null) return existing;

    final databasePath = await getDatabasesPath();
    final database = await openDatabase(
      '$databasePath/face_detection.db',
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL COLLATE NOCASE UNIQUE,
            face_image_paths TEXT,
            created_at TEXT NOT NULL,
            created_by TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE face_samples (
            user_id TEXT NOT NULL,
            sample_index INTEGER NOT NULL,
            pose TEXT NOT NULL,
            image BLOB NOT NULL,
            created_at TEXT NOT NULL,
            created_by TEXT,
            PRIMARY KEY (user_id, sample_index),
            FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE users ADD COLUMN face_image_paths TEXT',
          );
          final legacyRows = await db.query(
            'users',
            columns: ['id', 'face_image_path'],
            where: 'face_image_path IS NOT NULL',
          );
          for (final row in legacyRows) {
            await db.update(
              'users',
              {
                'face_image_paths': jsonEncode([row['face_image_path']]),
              },
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          }
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE users ADD COLUMN created_at TEXT');
          await db.execute('ALTER TABLE users ADD COLUMN created_by TEXT');
          final storedAt = DateTime.now().toUtc().toIso8601String();
          await db.execute('''
            CREATE TABLE face_samples (
              user_id TEXT NOT NULL,
              sample_index INTEGER NOT NULL,
              pose TEXT NOT NULL,
              image BLOB NOT NULL,
              created_at TEXT NOT NULL,
              created_by TEXT,
              PRIMARY KEY (user_id, sample_index),
              FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
            )
          ''');
          final existingUsers = await db.query(
            'users',
            columns: ['id', 'face_image_paths'],
          );
          for (final existingUser in existingUsers) {
            final encodedPaths = existingUser['face_image_paths'] as String?;
            if (encodedPaths == null) continue;
            final paths = (jsonDecode(encodedPaths) as List<dynamic>)
                .cast<String>();
            for (var index = 0; index < paths.length; index++) {
              final file = File(paths[index]);
              if (!await file.exists()) continue;
              await db.insert('face_samples', {
                'user_id': existingUser['id'],
                'sample_index': index,
                'pose': index < _legacyPoseNames.length
                    ? _legacyPoseNames[index]
                    : 'sample_${index + 1}',
                'image': await file.readAsBytes(),
                'created_at': storedAt,
              });
            }
          }
        }
      },
    );
    _database = database;
    return database;
  }

  @override
  Future<List<RegisteredUser>> listUsers() async {
    final rows = await (await _db).query(
      'users',
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(RegisteredUser.fromMap).toList(growable: false);
  }

  @override
  Future<RegisteredUser> createUser(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Name cannot be blank');
    }

    final createdAt = DateTime.now().toUtc();
    final user = RegisteredUser(
      id: _newId(),
      name: trimmedName,
      createdAt: createdAt,
    );
    await (await _db).insert('users', {
      'id': user.id,
      'name': user.name,
      'created_at': createdAt.toIso8601String(),
    });
    return user;
  }

  Future<List<StoredFaceSample>> getFaceSamples(String userId) async {
    final rows = await (await _db).query(
      'face_samples',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'sample_index',
    );
    return rows.map(StoredFaceSample.fromMap).toList(growable: false);
  }

  @override
  Future<RegisteredUser> enrollUser(String userId, List<XFile> images) async {
    if (images.length != _poseNames.length) {
      throw ArgumentError.value(
        images.length,
        'images',
        'Expected six face samples',
      );
    }

    final database = await _db;
    final rows = await database.query(
      'users',
      columns: ['id', 'name', 'face_image_paths', 'created_at', 'created_by'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('User not found');

    final user = RegisteredUser.fromMap(rows.first);
    final supportDirectory = await getApplicationSupportDirectory();
    final facesDirectory = Directory('${supportDirectory.path}/enrolled_faces');
    await facesDirectory.create(recursive: true);

    final imagePaths = <String>[];
    final imageData = <Uint8List>[];
    try {
      for (final image in images) {
        final bytes = await image.readAsBytes();
        imageData.add(bytes);
        final imagePath = '${facesDirectory.path}/$userId-${_newId()}.jpg';
        imagePaths.add(imagePath);
        await File(imagePath).writeAsBytes(bytes, flush: true);
      }

      final createdAt = DateTime.now().toUtc().toIso8601String();
      await database.transaction((transaction) async {
        final updatedCount = await transaction.update(
          'users',
          {'face_image_paths': jsonEncode(imagePaths)},
          where: 'id = ?',
          whereArgs: [userId],
        );
        if (updatedCount != 1) {
          throw StateError('Could not save face enrollment');
        }
        await transaction.delete(
          'face_samples',
          where: 'user_id = ?',
          whereArgs: [userId],
        );
        for (var index = 0; index < imageData.length; index++) {
          await transaction.insert('face_samples', {
            'user_id': userId,
            'sample_index': index,
            'pose': _poseNames[index],
            'image': imageData[index],
            'created_at': createdAt,
          });
        }
      });
    } catch (_) {
      for (final imagePath in imagePaths) {
        final imageFile = File(imagePath);
        if (await imageFile.exists()) await imageFile.delete();
      }
      rethrow;
    }

    for (final previousPath in user.faceImagePaths) {
      if (!imagePaths.contains(previousPath)) {
        final previousImage = File(previousPath);
        if (await previousImage.exists()) await previousImage.delete();
      }
    }

    return RegisteredUser(
      id: user.id,
      name: user.name,
      faceImagePaths: imagePaths,
      createdAt: user.createdAt,
      createdBy: user.createdBy,
    );
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  String _newId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
