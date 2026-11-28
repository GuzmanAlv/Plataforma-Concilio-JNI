import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient?>((ref) => null);
final startupErrorProvider = Provider<String?>((ref) => null);

final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client?.auth.onAuthStateChange ?? const Stream.empty();
});

/// A token refresh does not change data ownership. Recompute protected data
/// only when the account (or its anonymous status) actually changes.
final authIdentityProvider = Provider<String?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ref.watch(
    authStateProvider.select((state) {
      final user =
          state.asData?.value.session?.user ?? client?.auth.currentUser;
      return user == null ? null : '${user.id}:${user.isAnonymous}';
    }),
  );
});
