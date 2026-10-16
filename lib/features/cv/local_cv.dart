import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/providers.dart';

/// Keeps a copy of the user's CV inside the app on this phone, so it can be
/// attached to emails without uploading it anywhere.
class LocalCv {
  LocalCv(this._ref);
  final Ref _ref;

  Future<void> save(String fileName, Uint8List bytes) async {
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/cv');
    if (dir.existsSync()) {
      for (final f in dir.listSync()) {
        if (f is File) f.deleteSync();
      }
    } else {
      dir.createSync(recursive: true);
    }
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_');
    final file = File('${dir.path}/$safe');
    await file.writeAsBytes(bytes, flush: true);
    final prefs = _ref.read(prefsProvider);
    await prefs.setString(PrefKeys.localCvPath, file.path);
    await prefs.setString(PrefKeys.localCvName, safe);
  }

  /// Path of the saved CV, or null if there is none on this phone.
  String? get path {
    final p = _ref.read(prefsProvider).getString(PrefKeys.localCvPath);
    return (p != null && File(p).existsSync()) ? p : null;
  }

  String? get name => path == null ? null : _ref.read(prefsProvider).getString(PrefKeys.localCvName);

  Future<void> delete() async {
    final p = path;
    if (p != null) await File(p).delete();
    final prefs = _ref.read(prefsProvider);
    await prefs.remove(PrefKeys.localCvPath);
    await prefs.remove(PrefKeys.localCvName);
  }
}

final localCvProvider = Provider<LocalCv>((ref) => LocalCv(ref));
