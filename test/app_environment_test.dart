import 'dart:convert';
import 'package:concilio_jni_dreamrs/core/config/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String jwt(String role) =>
      'header.${base64Url.encode(utf8.encode(jsonEncode({'role': role})))}.signature';
  test(
    'Preview works without configuration; partial settings are rejected',
    () {
      const empty = AppEnvironment(supabaseUrl: '', supabasePublishableKey: '');
      expect(empty.isConfigured, false);
      empty.validate();
      expect(
        () => const AppEnvironment(
          supabaseUrl: 'https://project.supabase.co',
          supabasePublishableKey: '',
        ).validate(),
        throwsFormatException,
      );
    },
  );
  test('Only public Supabase keys can be embedded in the app', () {
    for (final key in ['sb_publishable_example_public_key', jwt('anon')]) {
      AppEnvironment(
        supabaseUrl: 'https://project.supabase.co',
        supabasePublishableKey: key,
      ).validate();
    }
    for (final key in ['sb_secret_private', jwt('service_role'), 'malformed']) {
      expect(
        () => AppEnvironment(
          supabaseUrl: 'https://project.supabase.co',
          supabasePublishableKey: key,
        ).validate(),
        throwsFormatException,
      );
    }
  });
}
