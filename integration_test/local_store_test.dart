import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kech_app/core/local_store.dart';
import 'package:kech_app/features/expenses/model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Cuentas locales, contraseña y gastos persisten separados', (tester) async {
    final store = LocalStore.instance;
    final suffix = DateTime.now().microsecondsSinceEpoch.toString();
    final emailA = 'prueba_a_$suffix@ejemplo.mx', emailB = 'prueba_b_$suffix@ejemplo.mx';
    Future<void> register(String email) => store.register(name: 'Prueba', surname: 'Local', email: email, username: '', password: 'Prueba1234', business: false, businessName: '');
    try {
      await register(emailA); await register(emailB);
      final db = await store.database;
      final row = (await db.query('users', where: 'email = ?', whereArgs: [emailA])).single;
      expect(row['hash'], isNot(equals(Uint8List.fromList(utf8.encode('Prueba1234')))));
      expect(await store.login(emailA, 'incorrecta'), false);
      expect(await store.login(emailA, 'Prueba1234'), true);
      final idA = store.session.value!;
      await store.saveExpense(idA, Expense(cents: 1250, concept: 'Compra', date: DateTime(2026, 1, 2), merchant: 'Tienda', category: 'Otros', payment: 'Desconocido', reference: '', image: Uint8List.fromList([1,2,3]), recognizedText: 'Texto de prueba'));
      store.logout();
      expect(await store.login(emailB, 'Prueba1234'), true);
      expect(await store.loadExpenses(store.session.value!), isEmpty);
      store.logout();
      expect(await store.login(emailA, 'Prueba1234'), true);
      final loaded = await store.loadExpenses(store.session.value!);
      expect(loaded.single.cents, 1250);
      expect(loaded.single.image, [1,2,3]);
      expect(loaded.single.recognizedText, 'Texto de prueba');
    } finally {
      store.logout();
      final db = await store.database;
      await db.delete('users', where: 'email IN (?, ?)', whereArgs: [emailA, emailB]);
    }
  });
}
