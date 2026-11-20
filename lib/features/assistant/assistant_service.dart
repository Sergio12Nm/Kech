import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../expenses/model.dart';
import '../../core/local_store.dart';
import '../../shared/ui.dart';

class AssistantDraft {
  const AssistantDraft({
    required this.amount,
    required this.concept,
    required this.merchant,
    required this.category,
    required this.payment,
    this.date,
    this.reference = '',
  });
  final String amount, concept, merchant, payment;
  final String? category;
  final DateTime? date;
  final String reference;
}

class AssistantReply {
  const AssistantReply(this.text, {this.draft, this.fromModel = false});
  final String text;
  final AssistantDraft? draft;
  final bool fromModel;
}

class AssistantService {
  static final _uri = Uri.https('openrouter.ai', '/api/v1/chat/completions');
  static const _system =
      'Eres Chequi, asistente en español para una demostración con datos ficticios. Para consultar gastos usa consultar_gastos. Para registrar usa preparar_gasto: no guardes ni inventes campos. Una tarjeta sin especificar es Desconocido. Nunca calcules ni inventes saldos. Responde brevemente si no se solicita una función.';
  static const _tools = [
    {
      'type': 'function',
      'function': {
        'name': 'consultar_gastos',
        'description': 'Consulta registros ficticios de la sesión activa.',
        'parameters': {
          'type': 'object',
          'properties': {
            'periodo': {
              'type': 'string',
              'enum': ['hoy', 'semana', 'mes', 'todos'],
            },
            'metodo': {
              'type': 'string',
              'enum': [
                'todos',
                'efectivo',
                'tarjeta',
                'debito',
                'credito',
                'transferencia',
              ],
            },
            'vista': {
              'type': 'string',
              'enum': ['total', 'ultimos'],
            },
            'categoria': {
              'type': 'string',
              'enum': [
                'todas',
                'Alimentos',
                'Insumos',
                'Transporte',
                'Servicios',
                'Operación',
                'Otros',
              ],
            },
          },
          'required': ['periodo', 'metodo', 'vista', 'categoria'],
          'additionalProperties': false,
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'preparar_gasto',
        'description': 'Abre un formulario editable sin guardar.',
        'parameters': {
          'type': 'object',
          'properties': {
            'monto': {
              'type': 'string',
              'description': 'Importe decimal sin símbolo o vacío si falta.',
            },
            'concepto': {'type': 'string'},
            'comercio': {'type': 'string'},
            'fecha': {
              'type': 'string',
              'description': 'Fecha explícita AAAA-MM-DD o vacío si falta.',
            },
            'categoria': {
              'type': 'string',
              'enum': [
                'Alimentos',
                'Insumos',
                'Transporte',
                'Servicios',
                'Operación',
                'Otros',
                '',
              ],
            },
            'metodo': {
              'type': 'string',
              'enum': [
                'Efectivo',
                'Tarjeta de débito',
                'Tarjeta de crédito',
                'Transferencia',
                'Billetera digital',
                'Desconocido',
              ],
            },
          },
          'required': [
            'monto',
            'concepto',
            'comercio',
            'fecha',
            'categoria',
            'metodo',
          ],
          'additionalProperties': false,
        },
      },
    },
  ];
  final http.Client client;
  AssistantService({http.Client? client}) : client = client ?? http.Client();
  void close() => client.close();
  Future<AssistantReply> send(
    List<Map<String, String>> messages,
    List<Expense> expenses, {
    DateTime? now,
    String apiKey = '',
  }) async {
    if (!kDebugMode ||
        !LocalStore.instance.demo ||
        LocalStore.instance.session.value != -1) {
      throw StateError(
        'Chequi solo está disponible con datos ficticios en modo demostración.',
      );
    }
    if (apiKey.trim().isEmpty) {
      throw StateError('Introduce tu clave de OpenRouter.');
    }
    final response = await client
        .post(
          _uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${apiKey.trim()}',
          },
          body: jsonEncode({
            'model': 'nvidia/nemotron-3.5-lightning:free',
            'messages': [
              {'role': 'system', 'content': _system},
              ...messages,
            ],
            'tools': _tools,
            'tool_choice': 'auto',
            'reasoning': {'enabled': false},
            'max_tokens': 600,
          }),
        )
        .timeout(const Duration(seconds: 55));
    if (response.statusCode != 200) {
      throw StateError(
        response.statusCode == 401 || response.statusCode == 403
            ? 'La clave de OpenRouter no es válida o no tiene acceso al modelo.'
            : response.statusCode == 429
            ? 'El proveedor alcanzó su límite de solicitudes. Inténtalo más tarde.'
            : 'OpenRouter no pudo procesar la solicitud. Inténtalo de nuevo.',
      );
    }
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Respuesta inválida');
    }
    final choices = data['choices'];
    if (choices is! List ||
        choices.isEmpty ||
        choices.first is! Map ||
        choices.first['message'] is! Map) {
      throw const FormatException('Respuesta incompleta');
    }
    final message = choices.first['message'] as Map;
    final calls = message['tool_calls'];
    if (calls != null && calls is! List) {
      throw const FormatException('Funciones inválidas');
    }
    if (calls is List && calls.isNotEmpty) {
      if (calls.length != 1 ||
          calls.first is! Map ||
          calls.first['function'] is! Map) {
        throw const FormatException('Función inválida');
      }
      final function = calls.first['function'] as Map;
      final raw = function['arguments'];
      if (raw is! String || raw.length > 3000) {
        throw const FormatException('Argumentos inválidos');
      }
      final args = jsonDecode(raw);
      if (args is! Map<String, dynamic>) {
        throw const FormatException('Argumentos inválidos');
      }
      if (function['name'] == 'consultar_gastos') {
        return summarizeExpenses(expenses, args, now ?? DateTime.now());
      }
      if (function['name'] == 'preparar_gasto') return prepareExpense(args);
      throw const FormatException('Función desconocida');
    }
    final text = message['content'];
    if (text is! String || text.trim().isEmpty) {
      throw const FormatException('Respuesta vacía');
    }
    if (RegExp(r'\d|\$').hasMatch(text)) {
      return const AssistantReply(
        'Puedo consultar los gastos de la sesión o preparar un registro. Indícame qué necesitas.',
      );
    }
    return AssistantReply(text.trim(), fromModel: true);
  }
}

AssistantReply summarizeExpenses(
  List<Expense> expenses,
  Map<String, dynamic> args,
  DateTime now,
) {
  const periods = {'hoy', 'semana', 'mes', 'todos'};
  const methods = {
    'todos',
    'efectivo',
    'tarjeta',
    'debito',
    'credito',
    'transferencia',
  };
  const views = {'total', 'ultimos'};
  final period = args['periodo'], method = args['metodo'], view = args['vista'];
  final category = args['categoria'] ?? 'todas';
  if (!periods.contains(period) ||
      !methods.contains(method) ||
      !views.contains(view) ||
      (category != 'todas' && !categories.contains(category))) {
    throw const FormatException('Filtros inválidos');
  }
  final today = DateTime(now.year, now.month, now.day);
  final DateTime? start = switch (period) {
    'hoy' => today,
    'semana' => today.subtract(Duration(days: today.weekday - 1)),
    'mes' => DateTime(now.year, now.month),
    _ => null,
  };
  final end = today.add(const Duration(days: 1));
  final names = switch (method) {
    'efectivo' => ['Efectivo'],
    'debito' => ['Tarjeta de débito'],
    'credito' => ['Tarjeta de crédito'],
    'tarjeta' => ['Tarjeta de débito', 'Tarjeta de crédito'],
    'transferencia' => ['Transferencia'],
    _ => <String>[],
  };
  final rows =
      expenses
          .where(
            (e) =>
                (start == null ||
                    (!e.date.isBefore(start) && e.date.isBefore(end))) &&
                (category == 'todas' || e.category == category) &&
                (method == 'todos' ||
                    names.contains(e.payment) ||
                    (e.payment == 'Pago mixto' &&
                        names.any((n) => (e.parts[n] ?? 0) > 0))),
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
  final label = start == null
      ? 'todos los registros'
      : '${dateLabel(start)} al ${dateLabel(today)}';
  if (view == 'ultimos') {
    if (rows.isEmpty) return AssistantReply('No hay gastos para $label.');
    return AssistantReply(
      'Últimos gastos ($label):\n${rows.take(5).map((e) => '${dateLabel(e.date)} · ${e.merchant} · ${money(e.cents)} MXN · ${e.payment}').join('\n')}',
    );
  }
  final sum = rows.fold<int>(
    0,
    (a, e) =>
        a +
        (method != 'todos' && e.payment == 'Pago mixto'
            ? names.fold<int>(0, (v, n) => v + (e.parts[n] ?? 0))
            : e.cents),
  );
  return AssistantReply(
    'Gastos registrados ($label): ${money(sum)} MXN · ${rows.length} movimientos${method == 'todos' ? '' : ' · filtro: $method'}${category == 'todas' ? '' : ' · categoría: $category'}. El método de pago no confirma la liquidación.',
  );
}

AssistantReply prepareExpense(Map<String, dynamic> args) {
  String field(String key) {
    final v = args[key];
    if (v is! String || v.length > 120) {
      throw const FormatException('Campo inválido');
    }
    return v.trim();
  }

  final amount = field('monto'),
      concept = field('concepto'),
      merchant = field('comercio'),
      category = field('categoria'),
      payment = field('metodo');
  final dateText = args['fecha'] == null ? '' : field('fecha');
  DateTime? date;
  if (dateText.isNotEmpty) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateText)) {
      throw const FormatException('Fecha inválida');
    }
    date = DateTime.tryParse(dateText);
    if (date == null ||
        date.toIso8601String().substring(0, 10) != dateText ||
        date.year < 2000 ||
        date.year > 2100) {
      throw const FormatException('Fecha inválida');
    }
  }
  if (amount.isNotEmpty &&
      (parseCents(amount) == null || parseCents(amount)! <= 0)) {
    throw const FormatException('Importe inválido');
  }
  if (category.isNotEmpty && !categories.contains(category)) {
    throw const FormatException('Categoría inválida');
  }
  if (!payments.contains(payment) || payment == 'Pago mixto') {
    throw const FormatException('Método inválido');
  }
  return AssistantReply(
    'Preparé el formulario. Revisa los datos y confirma al guardar.',
    draft: AssistantDraft(
      amount: amount,
      concept: concept,
      merchant: merchant,
      category: category.isEmpty ? null : category,
      payment: payment,
      date: date,
    ),
  );
}
