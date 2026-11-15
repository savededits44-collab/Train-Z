import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Centralized helper for contacting the official TRAIN Z Support Team.
class SupportEmailHelper {
  SupportEmailHelper._();

  /// The official support email address for TRAIN Z.
  static const String officialSupportEmail = 'trainzsupport@gmail.com';

  /// The official branding name for the support team.
  static const String officialSupportIdentity = 'TRAIN Z Support Team';

  /// Constructs the standard mailto: URI prefilled with the official support email.
  static Uri buildSupportEmailUri({
    String subject = 'TRAIN Z Support Request',
    String body = '',
  }) {
    final Map<String, String> queryParameters = {
      'subject': subject,
      if (body.isNotEmpty) 'body': body,
    };

    return Uri(
      scheme: 'mailto',
      path: officialSupportEmail,
      query: Uri(queryParameters: queryParameters).query,
    );
  }

  /// Opens the user's default email client with [officialSupportEmail] prefilled.
  /// If no email client is available, it gracefully copies the address to the clipboard
  /// and notifies the user via SnackBar.
  static Future<bool> launchSupportEmail({
    BuildContext? context,
    String subject = 'TRAIN Z Support Request',
    String body = '',
  }) async {
    final emailUri = buildSupportEmailUri(subject: subject, body: body);
    final messenger = context != null ? ScaffoldMessenger.maybeOf(context) : null;

    try {
      final launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        await Clipboard.setData(const ClipboardData(text: officialSupportEmail));
        messenger?.showSnackBar(
          const SnackBar(
            content: Text(
              'No email application detected. trainzsupport@gmail.com copied to clipboard.',
              style: TextStyle(fontFamily: 'Outfit', fontSize: 13),
            ),
            backgroundColor: Color(0xFF111111),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      return launched;
    } catch (_) {
      await Clipboard.setData(const ClipboardData(text: officialSupportEmail));
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'trainzsupport@gmail.com copied to clipboard.',
            style: TextStyle(fontFamily: 'Outfit', fontSize: 13),
          ),
          backgroundColor: Color(0xFF111111),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
  }
}
