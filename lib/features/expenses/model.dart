import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  });
  final int cents;
  final String concept, merchant, category, payment, reference;
  final DateTime date;
  final Map<String, int> parts;
}

class ExpenseStore extends Notifier<List<Expense>> {
  @override
  List<Expense> build() => [];
  void add(Expense expense) => state = [expense, ...state];
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
