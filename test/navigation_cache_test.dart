import 'dart:convert';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:concilio_jni_dreamrs/core/providers/request_cache.dart';
import 'package:concilio_jni_dreamrs/core/supabase/supabase_providers.dart';
import 'package:concilio_jni_dreamrs/core/domain/civil_date.dart';
import 'package:concilio_jni_dreamrs/core/domain/council_period.dart';
import 'package:concilio_jni_dreamrs/features/members/application/members_providers.dart';
import 'package:concilio_jni_dreamrs/features/treasury/application/treasury_providers.dart';
import 'package:concilio_jni_dreamrs/features/attendance/application/attendance_sheet_provider.dart';
import 'package:concilio_jni_dreamrs/features/groups/domain/group.dart';

Future<T> visit<T>(
  ProviderContainer container,
  FutureProvider<T> provider,
) async {
  final subscription = container.listen(provider, (_, _) {});
  try {
    return await container.read(provider.future);
  } finally {
    subscription.close();
    await container.pump();
  }
}

void main() {
  test('Token refresh keeps identity stable; sign out clears it', () async {
    final events = StreamController<AuthState>();
    final container = ProviderContainer(
      overrides: [authStateProvider.overrideWith((ref) => events.stream)],
    );
    final identities = <String?>[];
    final subscription = container.listen(
      authIdentityProvider,
      (_, next) => identities.add(next),
    );
    addTearDown(() async {
      subscription.close();
      container.dispose();
      await events.close();
    });
    final user = User.fromJson({
      'id': 'test-account',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'aud': 'authenticated',
      'created_at': '2026-01-01T00:00:00Z',
    })!;
    events.add(
      AuthState(
        AuthChangeEvent.signedIn,
        Session(accessToken: 'first', tokenType: 'bearer', user: user),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    expect(identities.length, 1);
    events.add(
      AuthState(
        AuthChangeEvent.tokenRefreshed,
        Session(accessToken: 'second', tokenType: 'bearer', user: user),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    expect(
      identities.length,
      1,
      reason: 'Token renewal must not reload every module.',
    );
    events.add(const AuthState(AuthChangeEvent.signedOut, null));
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    expect(identities.last, isNull);
    expect(identities.length, 2);
  });
  test(
    'Returning to members and treasury reuses successful requests; invalidation and identity clear data',
    () async {
      final calls = <String, int>{};
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public',
        httpClient: MockClient((request) async {
          final table = request.url.pathSegments.last;
          calls.update(table, (n) => n + 1, ifAbsent: () => 1);
          final Object data = table == 'resumen_caja'
              ? {
                  'saldo_inicial': 462.06,
                  'ingresos_brutos': 0,
                  'aportes_distrito': 0,
                  'colaboraciones': 0,
                  'ingresos_netos': 0,
                  'egresos': 0,
                  'saldo_actual': 462.06,
                }
              : [];
          return http.Response(
            jsonEncode(data),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(client),
          authIdentityProvider.overrideWithValue('account-a'),
        ],
      );
      addTearDown(container.dispose);
      final range = (
        start: CouncilPeriod.official.start,
        end: CouncilPeriod.official.end,
      );
      Future<void> navigate() async {
        await visit(container, memberDirectoryProvider);
        await visit(container, cashSummaryProvider);
        await visit(container, cashEvolutionProvider(range));
        await visit(container, treasuryMovementsProvider);
      }

      await navigate();
      expect(calls.values.reduce((a, b) => a + b), 6);
      final first = Map<String, int>.of(calls);
      await navigate();
      expect(
        calls,
        first,
        reason: 'Warm navigation must issue zero extra network requests.',
      );
      container.invalidate(memberDirectoryProvider);
      await visit(container, memberDirectoryProvider);
      expect(calls['integrantes'], 2);
      expect(calls['membresias_grupo'], 2);
      container.updateOverrides([
        supabaseClientProvider.overrideWithValue(client),
        authIdentityProvider.overrideWithValue('account-b'),
      ]);
      await container.pump();
      await visit(container, memberDirectoryProvider);
      expect(
        calls['integrantes'],
        3,
        reason: 'Never reuse the previous account cache.',
      );
    },
  );

  test(
    'Four Saturday groups share a directory but reload session marks',
    () async {
      final calls = <String, int>{};
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public',
        httpClient: MockClient((request) async {
          final table = request.url.pathSegments.last;
          calls.update(table, (n) => n + 1, ifAbsent: () => 1);
          return http.Response(
            '[]',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);
      final date = CivilDate(2026, 11, 28);
      for (final group in GroupId.values) {
        await visit(
          container,
          attendanceSheetProvider((date: date, group: group)),
        );
      }
      expect(calls['integrantes'], 1);
      expect(calls['membresias_grupo'], 1);
      expect(calls['asistencia_sesiones'], 4);
      await visit(
        container,
        attendanceSheetProvider((date: date, group: GroupId.amarillo)),
      );
      expect(
        calls['asistencia_sesiones'],
        5,
        reason: 'Do not cache editable marks.',
      );
      container.invalidate(attendanceRosterProvider);
      await visit(
        container,
        attendanceSheetProvider((date: date, group: GroupId.verde)),
      );
      expect(calls['integrantes'], 2);
    },
  );

  test(
    'Successful cache expires and does not survive explicit invalidation',
    () async {
      var reads = 0;
      final provider = FutureProvider.autoDispose<int>((ref) async {
        reads++;
        ref.cacheSuccess(duration: const Duration(milliseconds: 30));
        return reads;
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(await visit(container, provider), 1);
      expect(await visit(container, provider), 1);
      await Future<void>.delayed(const Duration(milliseconds: 70));
      await container.pump();
      expect(await visit(container, provider), 2);
      container.invalidate(provider);
      expect(await visit(container, provider), 3);
    },
  );
}
