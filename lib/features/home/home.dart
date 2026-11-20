import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/ui.dart';
import '../../core/local_store.dart';
import '../expenses/model.dart';
import '../expenses/expenses.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(expensesProvider);
    final now = DateTime.now();
    final today = items
        .where(
          (e) =>
              e.date.year == now.year &&
              e.date.month == now.month &&
              e.date.day == now.day,
        )
        .fold<int>(0, (a, e) => a + e.cents);
    return Shell(
      title: 'Inicio',
      index: 0,
      body: PageBody(
        children: [
          Text(
            LocalStore.instance.demo
                ? 'Modo demostración · Datos temporales y ficticios'
                : 'Tus gastos guardados en este dispositivo',
            style: TextStyle(color: green, fontWeight: FontWeight.bold),
          ),
          const Gap(),
          InkWell(
            onTap: () => context.go('/asistente'),
            child: const Panel(
              color: Color(0xffe7eefc),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(0xffbcebd5),
                    child: Icon(Icons.smart_toy_outlined, color: green),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'ASISTENTE\n¡Hola! Soy Chequi, ¿en qué te puedo ayudar?',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Gap(),
          Row(
            children: [
              Expanded(
                child: Panel(
                  color: const Color(0xffdff3e9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.payments_outlined, color: green),
                      const Gap(),
                      const Text('Gastos del día'),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          money(today),
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Panel(
                  color: const Color(0xffe7eefc),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.receipt_long_outlined, color: blue),
                      const Gap(),
                      const Text('Tickets registrados'),
                      Text(
                        '${items.where((e) => e.image != null).length}',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Gap(24),
          _action(
            context,
            Icons.camera_alt_outlined,
            'Escanear nuevo ticket',
            'Captura una fotografía de tu comprobante.',
            '/escanear',
          ),
          const Gap(),
          _action(
            context,
            Icons.edit_note,
            'Registrar gasto manualmente',
            'Agrega un gasto sin fotografía.',
            '/gasto',
          ),
          const Gap(24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Actividad reciente',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/registros'),
                child: const Text('Ver todos'),
              ),
            ],
          ),
          if (items.isEmpty)
            const Panel(child: Text('Todavía no hay gastos en esta sesión.'))
          else
            ...items.take(3).map((e) => ExpenseTile(expense: e)),
        ],
      ),
    );
  }

  Widget _action(
    BuildContext c,
    IconData icon,
    String title,
    String subtitle,
    String route,
  ) => InkWell(
    onTap: () => c.push(route),
    child: Panel(
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: const Color(0xffd8f0e5),
            child: Icon(icon, color: green),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                Text(subtitle),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward, color: blue),
        ],
      ),
    ),
  );
}
