import '../expenses/model.dart';
import '../../shared/ui.dart';
import 'assistant_service.dart';

/// Registro local guiado. Nunca escribe en la base de datos.
class GuidedExpense {
  int? _step;
  String _amount = '',
      _merchant = '',
      _concept = 'Compra',
      _payment = 'Desconocido',
      _reference = '';
  String? _category;
  DateTime? _date;
  bool get active => _step != null;
  AssistantReply start() {
    _step = 0;
    _amount = '';
    _merchant = '';
    _concept = 'Compra';
    _payment = 'Desconocido';
    _reference = '';
    _category = null;
    _date = null;
    return const AssistantReply(
      'Vamos a registrar tu gasto paso a paso. Puedes escribir «cancelar» en cualquier momento.\n¿Cuál fue el monto total en MXN?',
    );
  }

  AssistantReply answer(String input, {DateTime? now}) {
    final value = input.trim();
    final lower = value.toLowerCase();
    if (lower == 'cancelar') {
      _step = null;
      return const AssistantReply(
        'Registro cancelado. No se guardó ningún gasto.',
      );
    }
    if (_step == null) return start();
    switch (_step!) {
      case 0:
        final amount = value.replaceFirst(RegExp(r'^\$\s*'), '');
        if ((parseCents(amount) ?? 0) <= 0) {
          return const AssistantReply(
            'Introduce un importe mayor a cero, por ejemplo 250.50. ¿Cuál fue el total?',
          );
        }
        _amount = amount;
        _step = 1;
        return const AssistantReply(
          '¿En qué comercio o con qué proveedor realizaste el gasto?',
        );
      case 1:
        if (value.isEmpty || value.length > 120) {
          return const AssistantReply(
            'Escribe el comercio o proveedor, con un máximo de 120 caracteres.',
          );
        }
        _merchant = value;
        _step = 2;
        return const AssistantReply(
          '¿En qué fecha fue? Escribe «hoy», «ayer» o una fecha DD/MM/AAAA.',
        );
      case 2:
        final current = now ?? DateTime.now();
        final today = DateTime(current.year, current.month, current.day);
        DateTime? date;
        if (lower == 'hoy') date = today;
        if (lower == 'ayer') date = today.subtract(const Duration(days: 1));
        final match = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$')
            .firstMatch(value);
        if (match != null) {
          final d = int.parse(match[1]!),
              m = int.parse(match[2]!),
              y = int.parse(match[3]!);
          final parsed = DateTime(y, m, d);
          if (parsed.day == d &&
              parsed.month == m &&
              parsed.year == y &&
              y >= 2000 &&
              y <= 2100) {
            date = parsed;
          }
        }
        if (date == null) {
          return const AssistantReply(
            'La fecha no es válida. Escribe DD/MM/AAAA, «hoy» o «ayer».',
          );
        }
        _date = date;
        _step = 3;
        return AssistantReply(
          '¿Qué categoría corresponde?\n${_options(categories)}',
        );
      case 3:
        final selection = _select(value, categories);
        if (selection == null) {
          return AssistantReply(
            'Elige el número o nombre de una categoría:\n${_options(categories)}',
          );
        }
        _category = selection;
        _step = 4;
        return AssistantReply(
          '¿Cuál fue el método de pago? Si no lo sabes, elige Desconocido.\n${_options(payments)}',
        );
      case 4:
        final selection = _select(value, payments);
        if (selection == null) {
          return AssistantReply(
            'Elige un método específico. «Tarjeta» por sí sola no distingue crédito o débito.\n${_options(payments)}',
          );
        }
        _payment = selection;
        _step = 5;
        return AssistantReply(
          '${selection == 'Pago mixto' ? 'El desglose se completará y validará en el formulario.\n' : ''}El concepto propuesto es «Compra». ¿Quieres conservarlo? Escribe «sí» o el concepto que prefieras.',
        );
      case 5:
        if (value.length > 120) {
          return const AssistantReply(
            'Escribe un concepto de hasta 120 caracteres.',
          );
        }
        _concept = ['si', 'sí', 'compra'].contains(lower) ? 'Compra' : value;
        _step = 6;
        return const AssistantReply(
          '¿Tienes folio o referencia del comprobante? Escríbelo o responde «omitir».',
        );
      case 6:
        if (value.length > 120) {
          return const AssistantReply(
            'Escribe una referencia de hasta 120 caracteres o «omitir».',
          );
        }
        _reference = ['omitir', 'no', 'ninguno'].contains(lower) ? '' : value;
        _step = null;
        return AssistantReply(
          'Revisa tu gasto:\nTotal: ${money(parseCents(_amount)!)} MXN\nComercio: $_merchant\nFecha: ${dateLabel(_date!)}\nCategoría: $_category\nMétodo: $_payment\nConcepto: $_concept\nReferencia: ${_reference.isEmpty ? 'Sin referencia' : _reference}\nAbre el formulario para corregir y confirmar. Aún no se ha guardado.',
          draft: AssistantDraft(
            amount: _amount,
            concept: _concept,
            merchant: _merchant,
            category: _category,
            payment: _payment,
            date: _date,
            reference: _reference,
          ),
        );
      default:
        return start();
    }
  }

  String _options(List<String> options) =>
      options.indexed.map((e) => '${e.$1 + 1}. ${e.$2}').join('\n');
  String? _select(String value, List<String> options) {
    final n = int.tryParse(value);
    if (n != null && n >= 1 && n <= options.length) return options[n - 1];
    for (final option in options) {
      if (option.toLowerCase() == value.toLowerCase()) return option;
    }
    return null;
  }
}
