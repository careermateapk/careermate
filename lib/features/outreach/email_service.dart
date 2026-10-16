import 'dart:io';

import 'package:flutter_email_sender/flutter_email_sender.dart';

/// Opens the phone's email app (Gmail etc.) with everything filled in.
/// The user reviews and presses Send there; nothing is sent automatically.
class EmailService {
  EmailService._();

  /// Returns null when the email app opened, otherwise a message to show.
  static Future<String?> compose({
    required String to,
    required String subject,
    required String body,
    String? attachmentPath,
  }) async {
    try {
      final caps = await FlutterEmailSender.getCapabilities();
      if (!caps.canSend) return 'No email app found. Install or set up Gmail and try again.';
      final attach = attachmentPath != null && caps.supportsAttachments && File(attachmentPath).existsSync();
      await FlutterEmailSender.send(Email(
        recipients: to.trim().isEmpty ? const [] : [to.trim()],
        subject: subject,
        body: body,
        attachmentPaths: attach ? [attachmentPath] : null,
        isHTML: false,
      ));
      return null;
    } on FlutterEmailSenderNotAvailableException {
      return 'No email app found. Install or set up Gmail and try again.';
    } catch (e) {
      return 'Could not open your email app ($e).';
    }
  }
}
