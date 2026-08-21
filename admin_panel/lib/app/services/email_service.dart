import 'dart:js_interop';
import 'dart:js_interop_unsafe';

// Binds to the emailjs.send() function loaded from the SDK in index.html.
@JS('emailjs.send')
external JSPromise _emailJsSend(
  JSString serviceId,
  JSString templateId,
  JSObject templateParams,
);

class EmailService {
  static const _serviceId  = 'service_nyf61xm';
  static const _templateId = 'template_3nay1vn';

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
      // Build a JS object for the template params
      final params = JSObject();
      params.setProperty('to_name'.toJS,  name.toJS);
      params.setProperty('to_email'.toJS, email.toJS);
      params.setProperty('message'.toJS,  message.toJS);

      await _emailJsSend(
        _serviceId.toJS,
        _templateId.toJS,
        params,
      ).toDart;
    } catch (e) {
      // Email failure is silent; the in-app notification is already saved.
    }
  }
}
