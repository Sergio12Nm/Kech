import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kech_app/features/assistant/guided_expense.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_MX'));
  test('Pregunta dato por dato, valida y entrega borrador sin guardar', () {
    final flow = GuidedExpense();
    expect(flow.start().text, contains('monto total'));
    expect(flow.answer('-20').text, contains('mayor a cero'));
    expect(flow.answer('120.50').text, contains('comercio'));
    expect(flow.answer('Tienda local').text, contains('fecha'));
    expect(flow.answer('31/02/2026').text, contains('no es válida'));
    expect(flow.answer('ayer',now:DateTime(2026,11,20)).text, contains('categoría'));
    expect(flow.answer('6').text, contains('método'));
    expect(flow.answer('Tarjeta').text, contains('no distingue'));
    expect(flow.answer('1').text, contains('concepto'));
    expect(flow.answer('sí').text, contains('referencia'));
    final result = flow.answer('A-123');
    expect(result.draft!.amount,'120.50');
    expect(result.draft!.category,'Otros');
    expect(result.draft!.date,DateTime(2026,11,19));
    expect(result.draft!.concept,'Compra');
    expect(result.draft!.reference,'A-123');
    expect(result.text,contains('no se ha guardado'));
    expect(flow.active,false);
  });
  test('Cancelar descarta el borrador', () {
    final flow=GuidedExpense(); flow.start(); flow.answer('10');
    expect(flow.answer('cancelar').draft,isNull);
    expect(flow.active,false);
    flow.start(); expect(flow.answer('abc').text,contains('importe'));
  });
}
