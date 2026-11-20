import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kech_app/app/app.dart';
import 'package:kech_app/features/expenses/model.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:kech_app/features/receipts/ocr_service.dart';
import 'package:kech_app/core/local_store.dart';

void main() {
  test('Clasifica productos con cautela y deja sin clasificar mezclas', () {
    final food = extractReceipt(
      Uint8List(0),
      'FRUTERÍA\n3 x Limón por kilo \$181.14\n4 x Jícama \$114.52\n3 x Piña miel \$73.02\nGRAN TOTAL \$368.68',
    );
    expect(food.products, ['Limón por kilo', 'Jícama', 'Piña miel']);
    expect(food.category, 'Alimentos');
    final supplies = extractReceipt(
      Uint8List(0),
      'MERCERÍA\n2 x Estambre azul \$41.94\n1 x Cierre metálico \$50.55',
    );
    expect(supplies.category, 'Insumos');
    expect(classifyProducts(['Limón', 'Estambre']), isNull);
    expect(classifyProducts(['Limón', 'Producto desconocido']), isNull);
    expect(classifyProducts([]), isNull);
  });
  test('Identifica los dos tickets de ejemplo y conserva conflictos', () {
    final a = extractReceipt(
      Uint8List(0),
      'MERCERÍA EL TEJOCOTE\nFolio K05-00059\nFecha 16/04/2025 18:49\n2 x Estambre azul \$41.94\nTOTAL A PAGAR \$92.49\nForma de pago: Efectivo\nRecibido \$100.00\nCambio \$7.51',
    );
    expect(a.merchant, 'MERCERÍA EL TEJOCOTE');
    expect(a.reference, 'K05-00059');
    expect(a.total, '92.49');
    expect(a.date, DateTime(2025, 4, 16));
    expect(a.payment, 'Efectivo');
    final b = extractReceipt(
      Uint8List(0),
      'FRUTERÍA DEL ARRAYÁN\nFolio K06-00067\nFecha 02/11/2026 07:47\nGRAN TOTAL \$368.68\nTARJETA DÉBITO',
    );
    expect(b.merchant, 'FRUTERÍA DEL ARRAYÁN');
    expect(b.reference, 'K06-00067');
    expect(b.total, '368.68');
    expect(b.date, DateTime(2026, 11, 2));
    expect(b.payment, 'Tarjeta de débito');
    final conflict = extractReceipt(
      Uint8List(0),
      'TICKET\nTOTAL 10.00\nGRAN TOTAL 20.00\nForma de pago: tarjeta\nFolio A-1\nFolio B-2',
    );
    expect(conflict.merchant, isNull);
    expect(conflict.total, isNull);
    expect(conflict.payment, isNull);
    expect(conflict.reference, isNull);
  });
  test('El OCR conserva incertidumbre ante importes y pagos ambiguos', () {
    final image = Uint8List(0);
    final ambiguous = extractReceipt(
      image,
      'TOTAL: 100.00\nTOTAL: 120.00\nForma de pago: Tarjeta\nFecha: 31/02/2026',
    );
    expect(ambiguous.total, isNull);
    expect(ambiguous.date, isNull);
    expect(ambiguous.payment, isNull);
    final clear = extractReceipt(
      image,
      'TOTAL A PAGAR: \$120.00\nFecha: 18/11/2026\nMétodo de pago: tarjeta de débito',
    );
    expect(clear.total, '120.00');
    expect(clear.date, DateTime(2026, 11, 18));
    expect(clear.payment, 'Tarjeta de débito');
  });
  test('El texto OCR no conserva datos sensibles de tarjeta', () {
    final sanitized = redactSensitiveText(
      'Tarjeta 1234 5678 9012 3456\nCVV: 123\nNIP: 4321',
    );
    expect(sanitized, isNot(contains('1234 5678 9012 3456')));
    expect(sanitized, isNot(contains('CVV: 123')));
    expect(sanitized, isNot(contains('NIP: 4321')));
  });
  testWidgets('La fotografía no crea un gasto sin confirmación', (
    tester,
  ) async {
    LocalStore.instance.enterDemo();
    addTearDown(LocalStore.instance.logout);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KechApp()),
    );
    final image = (await rootBundle.load('assets/kech_logo.jpeg')).buffer
        .asUint8List();
    router.go('/revisar', extra: image);
    await tester.pumpAndSettle();
    expect(container.read(expensesProvider), isEmpty);
    expect(find.textContaining('No se pudo reconocer'), findsOneWidget);
    await tester.ensureVisible(find.text('REVISAR Y REGISTRAR GASTO'));
    await tester.tap(find.text('REVISAR Y REGISTRAR GASTO'));
    await tester.pumpAndSettle();
    expect(container.read(expensesProvider), isEmpty);
    expect(find.textContaining('Revisa y confirma los datos'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Concepto del gasto'),
          )
          .controller!
          .text,
      'Compra',
    );
  });
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
    router.go('/');
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
    expect(find.byTooltip('Dictar mensaje'), findsOneWidget);
    expect(
      tester.getCenter(find.byTooltip('Dictar mensaje')).dx,
      lessThan(tester.getCenter(find.byTooltip('Enviar')).dx),
    );
    expect(
      find.textContaining('Demostración: escribe solo datos ficticios'),
      findsOneWidget,
    );
    await tester.tap(find.text('Inicio').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Modo demostración'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
