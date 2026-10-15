import 'dart:convert';
import 'dart:typed_data';

import '../../config/app_config.dart';

enum CvFileType { pdf, docx }

class CvCheckResult {
  const CvCheckResult.ok(this.type) : error = null;
  const CvCheckResult.fail(this.error) : type = null;

  final CvFileType? type;
  final String? error;
  bool get isValid => error == null;

  String get mimeType => switch (type) {
        CvFileType.pdf => 'application/pdf',
        CvFileType.docx => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        null => 'application/octet-stream',
      };
}

/// Checks a CV before upload: extension, size, real file contents
/// (not just the name), corrupt files and password-protected PDFs.
class CvValidator {
  const CvValidator({this.maxBytes = AppConfig.maxCvBytes});

  final int maxBytes;

  CvCheckResult check(String fileName, Uint8List bytes) {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    if (!AppConfig.allowedCvExtensions.contains(ext)) {
      return const CvCheckResult.fail('Only PDF or DOCX files are supported.');
    }
    if (bytes.isEmpty) {
      return const CvCheckResult.fail('This file is empty.');
    }
    if (bytes.length > maxBytes) {
      final mb = (maxBytes / (1024 * 1024)).toStringAsFixed(0);
      return CvCheckResult.fail('File is too large. Maximum size is $mb MB.');
    }

    if (ext == 'pdf') {
      if (!_startsWith(bytes, const [0x25, 0x50, 0x44, 0x46, 0x2D])) {
        return const CvCheckResult.fail('This file is not a valid PDF. It may be corrupt or renamed.');
      }
      if (_containsAscii(bytes, '/Encrypt')) {
        return const CvCheckResult.fail('This PDF is password-protected. Please upload a version without a password.');
      }
      if (!_containsAscii(bytes, '%%EOF', fromEnd: 2048)) {
        return const CvCheckResult.fail('This PDF looks incomplete or corrupt. Please export it again.');
      }
      return const CvCheckResult.ok(CvFileType.pdf);
    }

    // DOCX files are ZIP archives that contain word/document.xml.
    if (!_startsWith(bytes, const [0x50, 0x4B, 0x03, 0x04])) {
      return const CvCheckResult.fail('This file is not a valid DOCX. Old .doc files are not supported — save as .docx or PDF.');
    }
    if (!_containsAscii(bytes, 'word/')) {
      return const CvCheckResult.fail('This DOCX looks corrupt or is not a Word document.');
    }
    return const CvCheckResult.ok(CvFileType.docx);
  }

  static bool _startsWith(Uint8List b, List<int> magic) {
    if (b.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (b[i] != magic[i]) return false;
    }
    return true;
  }

  static bool _containsAscii(Uint8List b, String needle, {int? fromEnd}) {
    final n = ascii.encode(needle);
    final start = (fromEnd == null || fromEnd >= b.length) ? 0 : b.length - fromEnd;
    outer:
    for (var i = start; i <= b.length - n.length; i++) {
      for (var j = 0; j < n.length; j++) {
        if (b[i + j] != n[j]) continue outer;
      }
      return true;
    }
    return false;
  }
}
