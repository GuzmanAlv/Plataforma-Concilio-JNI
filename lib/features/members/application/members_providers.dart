import '../../../core/providers/request_cache.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../data/supabase_members_repository.dart';

final memberDirectoryProvider =
    FutureProvider.autoDispose<List<MemberDirectoryEntry>>((ref) async {
      ref.watch(authIdentityProvider);
      final client = ref.watch(supabaseClientProvider);
      if (client == null) return [];
      final data = await SupabaseMembersRepository(client).loadDirectory();
      ref.cacheSuccess();
      return data;
    });
