import 'dart:convert';

/// Public client configuration, embedded at compile time. Never use service_role.
class AppEnvironment {
  const AppEnvironment({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
  });

  const AppEnvironment.fromDefines()
    : supabaseUrl = const String.fromEnvironment('SUPABASE_URL'),
      supabasePublishableKey = const String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
      );

  final String supabaseUrl;
  final String supabasePublishableKey;

  bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  void validate() {
    if (supabaseUrl.isEmpty && supabasePublishableKey.isEmpty) return;
    final uri = Uri.tryParse(supabaseUrl);
    if (!isConfigured ||
        uri == null ||
        !uri.hasAuthority ||
        !['https', 'http'].contains(uri.scheme)) {
      throw const FormatException('Configura URL y clave pública juntas.');
    }
    if (!_isPublicKey(supabasePublishableKey)) {
      throw const FormatException('La clave debe ser pública.');
    }
  }

  static bool _isPublicKey(String value) {
    if (value.startsWith('sb_publishable_') && value.length > 20) return true;
    try {
      final parts = value.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return payload is Map<String, dynamic> && payload['role'] == 'anon';
    } catch (_) {
      return false;
    }
  }
}
