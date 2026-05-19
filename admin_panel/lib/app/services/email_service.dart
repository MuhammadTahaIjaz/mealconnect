import 'dart:convert';
import 'package:http/http.dart' as http;

/// EmailJS integration for sending approval/rejection emails to parents.
///
/// Setup (takes ~5 minutes, completely free):
/// 1. Go to https://www.emailjs.com and create a free account.
/// 2. Click "Add New Service" → choose Gmail → connect your Gmail account.
///    Copy the Service ID (looks like "service_xxxxxxx").
/// 3. Click "Email Templates" → "Create New Template".
///    Set Subject: "MealConnect — Account Update"
///    Set Body (plain text or HTML):
///      Hi {{to_name}},
///      {{message}}
///      — MealConnect Team
///    Save. Copy the Template ID (looks like "template_xxxxxxx").
/// 4. Go to Account → General → copy your Public Key.
/// 5. Replace the three constants below with your real values.
class EmailService {
  static const _serviceId = 'service_nyf61xm'; // e.g. 'service_abc123'
  static const _templateId = 'template_3nay1vn'; // e.g. 'template_xyz789'
  static const _publicKey = '6vVeAAiaLo07aLt8A'; // e.g. 'user_AbCdEfGhIj'

  static Future<void> sendParentStatusEmail({
    required String email,
    required String name,
    required String status, // 'approved' or 'rejected'
  }) async {

    final message = status == 'approved'
        ? 'Your MealConnect parent account has been approved. '
              'Open the app and sign in to continue.'
        : 'Your MealConnect account request was not approved. '
              'Please contact the school admin for more information.';

    try {
      await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': _serviceId,
          'template_id': _templateId,
          'user_id': _publicKey,
          'template_params': {
            'to_name': name,
            'to_email': email,
            'message': message,
          },
        }),
      );
    } catch (_) {
      // Email failure is silent — the Firestore notification is already saved.
    }
  }
}
