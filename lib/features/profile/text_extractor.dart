import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pdfrx/pdfrx.dart';

class TextExtractionException implements Exception {
  TextExtractionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Reads the plain text of a PDF or DOCX CV, on the phone.
class TextExtractor {
  const TextExtractor();

  Future<String> extract(String fileName, Uint8List bytes) async {
    final ext = fileName.toLowerCase().split('.').last;
    try {
      return ext == 'pdf' ? await _pdf(bytes) : _docx(bytes);
    } on TextExtractionException {
      rethrow;
    } catch (_) {
      throw TextExtractionException('We could not read the text in this file. Try saving it again as PDF.');
    }
  }

  Future<String> _pdf(Uint8List bytes) async {
    final doc = await PdfDocument.openData(bytes);
    try {
      final out = StringBuffer();
      for (final page in doc.pages) {
        final t = await page.loadText();
        out.writeln(t?.fullText ?? '');
      }
      return out.toString();
    } finally {
      await doc.dispose();
    }
  }

  String _docx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? docXml;
    for (final f in archive) {
      if (f.isFile && f.name == 'word/document.xml') docXml = f;
    }
    if (docXml == null) throw TextExtractionException('This DOCX has no readable text.');
    final xml = utf8.decode(docXml.readBytes() ?? const [], allowMalformed: true);
    // Paragraphs and line breaks become new lines; tabs become spaces.
    final withBreaks = xml
        .replaceAll(RegExp(r'</w:p>'), '\n')
        .replaceAll(RegExp(r'<w:br[^>]*/>'), '\n')
        .replaceAll(RegExp(r'<w:tab[^>]*/>'), ' ');
    final text = withBreaks.replaceAll(RegExp(r'<[^>]+>'), '');
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }
}
