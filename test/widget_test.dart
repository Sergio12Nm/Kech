import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kech_app/app/app.dart';
import 'package:kech_app/features/expenses/model.dart';

void main() {
  test(
    'Convierte importes exactos a centavos y rechaza entradas inválidas',
    () {
      expect(parseCents('450.05'), 45005);
      expect(parseCents('1,2'), 120);
      expect(parseCents('-2'), isNull);
      expect(parseCents('1.234'), isNull);
      expect(parseCents('texto'), isNull);
    },
  );
  testWidgets('Navega y registra un gasto de demostración', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: KechApp()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Entrar en modo demostración'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Entrar en modo demostración'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Modo demostración'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Registrar gasto manualmente'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Registrar gasto manualmente'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Monto total'),
      '120.50',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Concepto del gasto'),
      'Prueba',
    );
    await tester.scrollUntilVisible(
      find.text('Comercio o proveedor'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Comercio o proveedor'),
      'Tienda ficticia',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('GUARDAR GASTO'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GUARDAR GASTO'));
    await tester.pumpAndSettle();
    expect(find.text('Tienda ficticia'), findsOneWidget);
    expect(find.textContaining('120.50'), findsWidgets);
    await tester.tap(find.text('Asistente').last);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Servicio pendiente de integración'),
      findsOneWidget,
    );
    await tester.tap(find.text('Inicio').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Modo demostración'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
