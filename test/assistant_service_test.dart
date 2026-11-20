import 'package:flutter_test/flutter_test.dart';
import 'package:kech_app/features/assistant/assistant_service.dart';
import 'package:kech_app/features/expenses/model.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kech_app/core/local_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'dart:convert';

Expense expense(
  int cents,
  DateTime date,
  String payment, {
  Map<String, int> parts = const {},
}) => Expense(
  cents: cents,
  concept: 'Compra',
  date: date,
  merchant: 'Ejemplo ficticio',
  category: 'Otros',
  payment: payment,
  reference: '',
  parts: parts,
);

void main() {
  setUpAll(() async => initializeDateFormatting('es_MX'));
  test('Envía la clave por HTTPS y no envía los gastos locales', () async {
    LocalStore.instance.enterDemo();
    addTearDown(LocalStore.instance.logout);
    final service = AssistantService(
      client: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://openrouter.ai/api/v1/chat/completions',
        );
        expect(request.headers['Authorization'], 'Bearer clave-ficticia');
        expect(request.body, isNot(contains('Ejemplo ficticio')));
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
      }),
    );
    addTearDown(service.close);
    final now = DateTime(2026, 11, 20);
    final result = await service.send(
      [
        {'role': 'user', 'content': '¿Cuánto gasté hoy?'},
      ],
      [expense(12500, now, 'Efectivo')],
      now: now,
      apiKey: 'clave-ficticia',
    );
    expect(result.text, contains('125.00'));
  });
  test('Informa si la clave es rechazada', () async {
    LocalStore.instance.enterDemo();
    addTearDown(LocalStore.instance.logout);
    final service = AssistantService(
      client: MockClient((_) async => http.Response('{}', 401)),
    );
    addTearDown(service.close);
    await expectLater(
      service.send(
        [
          {'role': 'user', 'content': 'hola'},
        ],
        [],
        apiKey: 'clave-ficticia',
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'mensaje',
          contains('clave'),
        ),
      ),
    );
  });
  test('No permite enviar una cuenta local al servicio gratuito', () async {
    LocalStore.instance.logout();
    final service = AssistantService();
    addTearDown(service.close);
    await expectLater(
      service.send([
        {'role': 'user', 'content': 'consulta'},
      ], []),
      throwsStateError,
    );
  });
  test('Calcula tarjeta por partes y excluye fechas futuras', () {
    final now = DateTime(2026, 11, 20);
    final items = [
      expense(10000, now, 'Tarjeta de débito'),
      expense(
        30000,
        now,
        'Pago mixto',
        parts: {'Efectivo': 20000, 'Tarjeta de crédito': 10000},
      ),
      expense(90000, DateTime(2026, 11, 21), 'Tarjeta de crédito'),
    ];
    final result = summarizeExpenses(items, {
      'periodo': 'hoy',
      'metodo': 'tarjeta',
      'vista': 'total',
    }, now);
    expect(result.text, contains('200.00'));
    expect(result.text, contains('2 movimientos'));
    expect(result.text, contains('no confirma la liquidación'));
  });
  test('Rechaza filtros y datos de registro no válidos', () {
    expect(
      () => summarizeExpenses([], {
        'periodo': 'SQL',
        'metodo': 'todos',
        'vista': 'total',
      }, DateTime.now()),
      throwsFormatException,
    );
    expect(
      () => prepareExpense({
        'monto': '-1',
        'concepto': 'Compra',
        'comercio': '',
        'categoria': 'Otros',
        'metodo': 'Efectivo',
      }),
      throwsFormatException,
    );
    expect(
      () => prepareExpense({
        'monto': '200',
        'concepto': 'Compra',
        'comercio': '',
        'categoria': 'Otros',
        'metodo': 'Tarjeta',
      }),
      throwsFormatException,
    );
    final draft = prepareExpense({
      'monto': '250.00',
      'concepto': 'Compra',
      'comercio': 'Tienda ficticia',
      'categoria': 'Insumos',
      'metodo': 'Efectivo',
    }).draft!;
    expect(draft.amount, '250.00');
    expect(draft.merchant, 'Tienda ficticia');
  });
}
