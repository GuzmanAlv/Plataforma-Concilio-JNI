import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:concilio_jni_dreamrs/core/domain/civil_date.dart';
import 'package:concilio_jni_dreamrs/core/domain/money.dart';
import 'package:concilio_jni_dreamrs/features/treasury/data/supabase_treasury_repository.dart';

void main() {
  test(
    'Offerings upsert by date without writing generated amounts or replacing the row id',
    () async {
      var writes = 0;
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public',
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.queryParameters['on_conflict'], 'fecha');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body.keys, unorderedEquals(['fecha', 'monto_bruto']));
          expect(body['fecha'], '2026-11-28');
          writes++;
          final second = body['monto_bruto'] == '200.00';
          return http.Response(
            jsonEncode({
              'id': 'same-offering',
              'fecha': '2026-11-28',
              'monto_bruto': body['monto_bruto'],
              'aporte_distrito': second ? '20.00' : '10.00',
              'colaboracion_fija': '10.00',
              'monto_neto': second ? '170.00' : '80.00',
            }),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = SupabaseTreasuryRepository(client);
      final first = await repository.saveOffering(
        date: CivilDate(2026, 11, 28),
        gross: Money.parse('100'),
      );
      final corrected = await repository.saveOffering(
        date: CivilDate(2026, 11, 28),
        gross: Money.parse('200'),
      );
      expect(first.id, corrected.id);
      expect(writes, 2);
      expect(corrected.net.cents, 17000);
    },
  );
}
