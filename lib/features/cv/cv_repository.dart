import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../core/providers.dart';
import 'cv_validator.dart';

/// One uploaded CV (details only — the file itself is in Cloud Storage).
class CvRecord {
  CvRecord({
    required this.id,
    required this.fileName,
    required this.sizeBytes,
    required this.status,
    required this.storedInCloud,
    this.uploadedAt,
  });

  final String id;
  final String fileName;
  final int sizeBytes;

  /// uploaded → processing → parsed (or failed). Parsing comes in the next step.
  final String status;
  final bool storedInCloud;
  final DateTime? uploadedAt;

  factory CvRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return CvRecord(
      id: d.id,
      fileName: m['fileName'] as String? ?? 'CV',
      sizeBytes: (m['sizeBytes'] as num?)?.toInt() ?? 0,
      status: m['status'] as String? ?? 'uploaded',
      storedInCloud: m['storedInCloud'] as bool? ?? false,
      uploadedAt: (m['uploadedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class CvUploadException implements Exception {
  CvUploadException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CvRepository {
  CvRepository(this._db, this._storage, this._validator);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final CvValidator _validator;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('resumes');

  /// The user's current CV, or null if none uploaded yet.
  Stream<CvRecord?> watchCurrent(String uid) => _col(uid)
      .where('isCurrent', isEqualTo: true)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : CvRecord.fromDoc(s.docs.first));

  /// Validates and uploads a CV. [onProgress] receives 0.0–1.0.
  /// The new CV replaces the previous one (old file is deleted).
  Future<CvRecord> upload({
    required String uid,
    required String fileName,
    required Uint8List bytes,
    void Function(double progress)? onProgress,
  }) async {
    final check = _validator.check(fileName, bytes);
    if (!check.isValid) throw CvUploadException(check.error!);

    final doc = _col(uid).doc();
    final ext = check.type == CvFileType.pdf ? 'pdf' : 'docx';
    final path = 'users/$uid/cv/${doc.id}.$ext';

    if (AppConfig.uploadCvToCloud) {
      try {
        final task = _storage.ref(path).putData(bytes, SettableMetadata(contentType: check.mimeType));
        final sub = task.snapshotEvents.listen((s) {
          if (s.totalBytes > 0) onProgress?.call(s.bytesTransferred / s.totalBytes);
        });
        await task;
        await sub.cancel();
      } on FirebaseException catch (e) {
        throw CvUploadException(switch (e.code) {
          'unauthorized' => 'Upload was blocked by storage rules. Check guide step 9.',
          'retry-limit-exceeded' || 'canceled' => 'Upload stopped — please check your internet and try again.',
          'quota-exceeded' => 'Storage limit reached. Please contact support.',
          _ => 'Upload failed (${e.code}). Please try again.',
        });
      }
    } else {
      onProgress?.call(1);
    }

    final previous = await _col(uid).where('isCurrent', isEqualTo: true).get();
    final batch = _db.batch();
    for (final old in previous.docs) {
      batch.update(old.reference, {'isCurrent': false});
    }
    batch.set(doc, {
      'fileName': fileName,
      'sizeBytes': bytes.length,
      'mimeType': check.mimeType,
      'storagePath': AppConfig.uploadCvToCloud ? path : null,
      'storedInCloud': AppConfig.uploadCvToCloud,
      'status': 'uploaded',
      'isCurrent': true,
      'uploadedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    // Remove older files so only the latest CV is kept.
    for (final old in previous.docs) {
      await _deleteDocAndFile(old);
    }

    return CvRecord(
      id: doc.id,
      fileName: fileName,
      sizeBytes: bytes.length,
      status: 'uploaded',
      storedInCloud: AppConfig.uploadCvToCloud,
      uploadedAt: DateTime.now(),
    );
  }

  /// Permanently deletes every CV file and record for this user.
  Future<void> deleteAll(String uid) async {
    final all = await _col(uid).get();
    for (final d in all.docs) {
      await _deleteDocAndFile(d);
    }
  }

  Future<void> _deleteDocAndFile(DocumentSnapshot<Map<String, dynamic>> d) async {
    final path = d.data()?['storagePath'] as String?;
    if (path != null) {
      try {
        await _storage.ref(path).delete();
      } on FirebaseException catch (e) {
        if (e.code != 'object-not-found') rethrow;
      }
    }
    await d.reference.delete();
  }
}

final cvRepositoryProvider = Provider<CvRepository>(
  (ref) => CvRepository(ref.watch(firestoreProvider), ref.watch(storageProvider), const CvValidator()),
);

/// Current CV of the signed-in user.
final currentCvProvider = StreamProvider<CvRecord?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(cvRepositoryProvider).watchCurrent(user.uid);
});
