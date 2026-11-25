import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient?>((ref) => null);
final startupErrorProvider = Provider<String?>((ref) => null);

final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client?.auth.onAuthStateChange ?? const Stream.empty();
});

/// Rebuilt on sign-in/sign-out so cached data cannot survive another session.
final profileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  ref.watch(authStateProvider);
  final client = ref.watch(supabaseClientProvider);
  final user = client?.auth.currentUser;
  if (client == null || user == null) return null;
  return client.from('perfiles').select().eq('user_id', user.id).maybeSingle();
});
