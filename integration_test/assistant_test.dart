import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kech_app/core/local_store.dart';
import 'package:kech_app/features/assistant/assistant_service.dart';
import 'package:kech_app/features/expenses/model.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Consulta local con respuesta simulada de OpenRouter', (
    tester,
  ) async {
    await initializeDateFormatting('es_MX');
    LocalStore.instance.enterDemo();
    final mock = MockClient((request) async {
      expect(request.url.host, 'openrouter.ai');
      expect(request.headers['Authorization'], 'Bearer clave-ficticia');
      expect(request.body, isNot(contains('Tienda ficticia')));
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'tool_calls': [
                  {
                    'function': {
                      'name': 'consultar_gastos',
                      'arguments': jsonEncode({
                        'periodo': 'hoy',
                        'metodo': 'todos',
                        'vista': 'total',
                        'categoria': 'todas',
                      }),
                    },
                  },
                ],
              },
            },
          ],
        }),
        200,
      );
    });
    final service = AssistantService(client: mock);
    try {
      final today = DateTime(2026, 11, 20);
      final expenses = [
        Expense(
          cents: 12500,
          concept: 'Compra',
          date: today,
          merchant: 'Tienda ficticia',
          category: 'Otros',
          payment: 'Efectivo',
          reference: '',
        ),
      ];
      final result = await service.send(
        [
          {'role': 'user', 'content': '¿Cuánto gasté hoy?'},
        ],
        expenses,
        now: today,
        apiKey: 'clave-ficticia',
      );
      expect(result.text, contains('125.00'));
    } finally {
      service.close();
      LocalStore.instance.logout();
    }
  });
}
