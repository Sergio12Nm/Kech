import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:typed_data';

import '../../core/local_store.dart';

class Expense {
  const Expense({
    required this.cents,
    required this.concept,
    required this.date,
    required this.merchant,
    required this.category,
    required this.payment,
    required this.reference,
    this.parts = const {},
    this.image,
    this.recognizedText,
    this.suggestedTotal,
    this.suggestedDate,
    this.suggestedPayment,
    this.suggestedMerchant,
    this.suggestedReference,
    this.suggestedCategory,
  });
  final int cents;
  final String concept, merchant, category, payment, reference;
  final DateTime date;
  final Map<String, int> parts;
  final Uint8List? image;
  final String? recognizedText, suggestedTotal, suggestedPayment;
  final String? suggestedMerchant, suggestedReference;
  final String? suggestedCategory;
  final DateTime? suggestedDate;
}

class ExpenseStore extends Notifier<List<Expense>> {
  @override
  List<Expense> build() => [];
  Future<void> load(int userId) async {
    state = [];
    final items = await LocalStore.instance.loadExpenses(userId);
    if (LocalStore.instance.session.value == userId) state = items;
  }

  Future<void> add(Expense expense) async {
    final userId = LocalStore.instance.session.value;
    if (userId == null) throw StateError('Sesión cerrada');
    await LocalStore.instance.saveExpense(userId, expense);
    if (LocalStore.instance.session.value == userId) {
      state = [expense, ...state];
    }
  }

  void clear() => state = [];
}

final expensesProvider = NotifierProvider<ExpenseStore, List<Expense>>(
  ExpenseStore.new,
);
const categories = [
  'Alimentos',
  'Insumos',
  'Transporte',
  'Servicios',
  'Operación',
  'Otros',
];
const payments = [
  'Efectivo',
  'Tarjeta de débito',
  'Tarjeta de crédito',
  'Transferencia',
  'Billetera digital',
  'Pago mixto',
  'Desconocido',
];
int? parseCents(String input) {
  final s = input.trim();
  if (!RegExp(r'^\d+(?:[.,]\d{1,2})?$').hasMatch(s)) return null;
  final p = s.replaceAll(',', '.').split('.');
  final whole = int.tryParse(p[0]);
  if (whole == null || whole > 1000000000) return null;
  return whole * 100 + (p.length == 2 ? int.parse(p[1].padRight(2, '0')) : 0);
}
