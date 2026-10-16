import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import 'cv_parser.dart';

/// CV text plus whether part of it was read from pictures (OCR).
class ExtractedText {
  const ExtractedText(this.text, {this.usedOcr = false});
  final String text;
  final bool usedOcr;
}

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

  /// Like [extract], but if the PDF's text layer is missing contact details or headings
  /// (some PDF tools turn them into pictures), it also reads the pages with on-phone OCR.
  Future<ExtractedText> extractSmart(String fileName, Uint8List bytes) async {
    final text = await extract(fileName, bytes);
    if (!fileName.toLowerCase().endsWith('.pdf') || !_looksIncomplete(text)) return ExtractedText(text);
    try {
      final ocr = await _ocrPdf(bytes);
      if (ocr.trim().length < 40) return ExtractedText(text);
      // OCR first: its top lines usually hold the name and contact details.
      return ExtractedText('$ocr\n${CvParser.textLayerMarker}\n$text', usedOcr: true);
    } catch (_) {
      return ExtractedText(text);
    }
  }

  static bool _looksIncomplete(String text) {
    final t = text.toLowerCase();
    final hasEmail = RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+').hasMatch(text);
    final hasPhone = RegExp(r'[6-9]\d{4}[\s-]?\d{5}').hasMatch(text);
    final headings = ['experience', 'employment', 'education', 'skills', 'summary', 'profile']
        .where((h) => CvParser.containsWord(t, h))
        .length;
    return text.trim().length < 300 || !hasEmail || !hasPhone || headings < 3;
  }

  Future<String> _ocrPdf(Uint8List bytes) async {
    final doc = await PdfDocument.openData(bytes);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final dir = await getTemporaryDirectory();
    final out = StringBuffer();
    try {
      for (final page in doc.pages.take(3)) {
        const scale = 2.2; // ~160 dpi: sharp enough for small fonts
        final w = (page.width * scale).round();
        final h = (page.height * scale).round();
        final img = await page.render(fullWidth: w.toDouble(), fullHeight: h.toDouble(), backgroundColor: 0xFFFFFFFF);
        if (img == null) continue;
        final uiImage = await img.createImage();
        img.dispose();
        final png = await uiImage.toByteData(format: ui.ImageByteFormat.png);
        uiImage.dispose();
        if (png == null) continue;
        final file = File('${dir.path}/cv_ocr_${page.pageNumber}.png');
        await file.writeAsBytes(png.buffer.asUint8List());
        final result = await recognizer.processImage(InputImage.fromFilePath(file.path));
        for (final block in result.blocks) {
          out.writeln(block.text);
        }
        try {
          await file.delete();
        } catch (_) {}
      }
    } finally {
      await recognizer.close();
      await doc.dispose();
    }
    return out.toString();
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
