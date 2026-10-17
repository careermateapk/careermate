import 'dart:convert';
import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Gets the text of a job post without copying it by hand.
class PostReader {
  /// Reads the link preview (title + description) that a page offers for sharing — the same thing
  /// WhatsApp shows under a link. Works for public posts; posts behind a login return nothing.
  static Future<String> fromLink(String url) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..userAgent = 'CareerMate-LinkPreview/1.0';
    try {
      var uri = Uri.parse(url.trim());
      HttpClientResponse? res;
      for (var i = 0; i < 6; i++) {
        final req = await client.getUrl(uri).timeout(const Duration(seconds: 10));
        req.followRedirects = false;
        req.headers.set(HttpHeaders.acceptHeader, 'text/html');
        res = await req.close().timeout(const Duration(seconds: 10));
        if (res.isRedirect || (res.statusCode >= 300 && res.statusCode < 400)) {
          final loc = res.headers.value(HttpHeaders.locationHeader);
          await res.drain<void>();
          if (loc == null) break;
          uri = uri.resolve(loc);
          // Stop at login walls instead of trying to get around them.
          if (uri.path.contains('login') || uri.path.contains('authwall') || uri.path.contains('checkpoint')) return '';
          continue;
        }
        break;
      }
      if (res == null || res.statusCode != 200) return '';
      final bytes = <int>[];
      await for (final chunk in res) {
        bytes.addAll(chunk);
        if (bytes.length > 1500000) break;
      }
      final html = utf8.decode(bytes, allowMalformed: true);
      String meta(String key) {
        final re = RegExp('<meta[^>]+(?:property|name)=["\']$key["\'][^>]*>', caseSensitive: false);
        final tag = re.firstMatch(html)?.group(0) ?? '';
        return _unescape(RegExp('content=["\']([^"\']*)["\']', caseSensitive: false).firstMatch(tag)?.group(1) ?? '');
      }

      final title = meta('og:title').isNotEmpty ? meta('og:title') : _unescape(RegExp(r'<title>(.*?)</title>', dotAll: true).firstMatch(html)?.group(1) ?? '');
      final desc = meta('og:description').isNotEmpty ? meta('og:description') : meta('description');
      final text = [title, desc].where((s) => s.trim().isNotEmpty).join('\n');
      if (text.toLowerCase().contains('sign in') && desc.length < 60) return '';
      return text.trim().isEmpty ? '' : '$text\n${uri.toString()}';
    } catch (_) {
      return '';
    } finally {
      client.close(force: true);
    }
  }

  /// Reads the text in a screenshot of a post (on the phone, free).
  static Future<String> fromImage(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(path));
      return result.blocks.map((b) => b.text).join('\n');
    } finally {
      await recognizer.close();
    }
  }

  static String _unescape(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&#x27;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ')
      .replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m[1]!)))
      .trim();
}
