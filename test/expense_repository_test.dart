import 'dart:async';
import 'dart:convert';
import 'package:concilio_jni_dreamrs/core/domain/civil_date.dart';
import 'package:concilio_jni_dreamrs/core/domain/money.dart';
import 'package:concilio_jni_dreamrs/features/treasury/data/supabase_treasury_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'Retry after committed INSERT with lost response does not duplicate expense',
    () async {
      Map<String, dynamic>? persisted;
      var inserts = 0;
      final client = SupabaseClient(
        'https://test.supabase.co',
        'test-public-key',
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode(persisted == null ? [] : [persisted]),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.method == 'POST') {
            inserts++;
            persisted = jsonDecode(request.body) as Map<String, dynamic>;
            throw TimeoutException('Response lost after server commit');
          }
          fail('Unexpected method ${request.method}');
        }),
      );
      addTearDown(client.dispose);
      final repository = SupabaseTreasuryRepository(client);
      Future<dynamic> save() => repository.createExpense(
        id: '00000000-0000-4000-8000-000000000010',
        date: CivilDate(2026, 11, 26),
        amount: Money.parse('12.50'),
        name: 'Materiales',
        concept: 'Cartulinas',
      );
      await expectLater(save(), throwsA(isA<TimeoutException>()));
      final recovered = await save();
      expect(inserts, 1);
      expect(recovered.amount.cents, 1250);
      expect(recovered.name, 'Materiales');
      expect(recovered.receiptPath, isNull);
    },
  );
}
