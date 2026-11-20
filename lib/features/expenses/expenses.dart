import 'package:material_ui/material_ui.dart';

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/ui.dart';
import '../../core/local_store.dart';
import '../receipts/ocr_service.dart';
import '../assistant/assistant_service.dart';
import 'model.dart';

class ExpenseForm extends ConsumerStatefulWidget {
  const ExpenseForm({super.key, this.image, this.draft, this.assistantDraft});
  final Uint8List? image;
  final ReceiptDraft? draft;
  final AssistantDraft? assistantDraft;
  @override
  ConsumerState<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends ConsumerState<ExpenseForm> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController(),
      concept = TextEditingController(),
      merchant = TextEditingController(),
      reference = TextEditingController();
  final parts = {for (final p in payments.take(5)) p: TextEditingController()};
  DateTime date = DateTime.now();
  String? category = categories.first;
  String payment = 'Desconocido';
  bool saving = false;
  bool dateConfirmed = true;
  @override
  void initState() {
    super.initState();
    concept.text = 'Compra';
    final suggested = widget.assistantDraft;
    if (suggested != null) {
      dateConfirmed = false;
      if (suggested.date != null) date = suggested.date!;
      amount.text = suggested.amount;
      concept.text = suggested.concept.isEmpty ? 'Compra' : suggested.concept;
      merchant.text = suggested.merchant;
      reference.text = suggested.reference;
      category = suggested.category;
      payment = suggested.payment;
    }
    final draft = widget.draft;
    if (draft != null) {
      amount.text = draft.total ?? '';
      merchant.text = draft.merchant ?? '';
      reference.text = draft.reference ?? '';
      if (draft.date != null) date = draft.date!;
      payment = draft.payment ?? 'Desconocido';
      category = draft.category;
    }
  }

  @override
  void dispose() {
    for (final c in [amount, concept, merchant, reference, ...parts.values]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Registrar gasto')),
    body: Form(
      key: form,
      child: PageBody(
        children: [
          Panel(
            color: Color(0xffe7eefc),
            child: Text(
              widget.image == null
                  ? 'Nuevo comprobante\nIngresa el importe y los detalles de la compra.'
                  : 'Revisa y confirma los datos. Las sugerencias OCR pueden contener errores; los campos faltantes requieren captura manual.',
            ),
          ),
          const Gap(),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MONTO TOTAL · MXN',
                  style: TextStyle(fontWeight: FontWeight.bold, color: blue),
                ),
                const Gap(),
                LabeledField(
                  label: 'Monto total',
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    final n = parseCents(v ?? '');
                    return n == null || n <= 0
                        ? 'Introduce un importe válido mayor a cero'
                        : null;
                  },
                ),
              ],
            ),
          ),
          const Gap(),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detalles del movimiento',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Gap(),
                LabeledField(
                  label: 'Concepto del gasto',
                  controller: concept,
                  validator: requiredText,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    dateConfirmed ? 'Fecha' : 'Fecha: selecciona y confirma',
                  ),
                  subtitle: Text(
                    dateConfirmed
                        ? dateLabel(date)
                        : (widget.assistantDraft?.date == null
                              ? 'Sin identificar'
                              : '${dateLabel(date)} · sugerida'),
                  ),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) {
                      setState(() {
                        date = d;
                        dateConfirmed = true;
                      });
                    }
                  },
                ),
                const Gap(),
                LabeledField(
                  label: 'Comercio o proveedor',
                  controller: merchant,
                  validator: requiredText,
                ),
                LabeledField(
                  label: 'Referencia del comprobante (opcional)',
                  controller: reference,
                ),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: InputDecoration(
                    labelText: 'Categoría',
                    helperText: widget.draft != null
                        ? (widget.draft!.category == null
                              ? 'Sin sugerencia: selecciona una categoría'
                              : 'Sugerencia basada en productos; verifica')
                        : null,
                  ),
                  validator: (value) =>
                      value == null ? 'Selecciona una categoría' : null,
                  items: categories
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => category = v!),
                ),
              ],
            ),
          ),
          const Gap(),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Método de pago',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Gap(),
                DropdownButtonFormField<String>(
                  initialValue: payment,
                  decoration: const InputDecoration(
                    labelText: 'Método de pago',
                  ),
                  items: payments
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => payment = v!),
                ),
                if (payment == 'Pago mixto') ...[
                  const Gap(),
                  const Text('Desglosa el importe por método:'),
                  const Gap(),
                  for (final entry in parts.entries)
                    LabeledField(
                      label: entry.key,
                      controller: entry.value,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (v) =>
                          v != null &&
                              v.trim().isNotEmpty &&
                              parseCents(v) == null
                          ? 'Importe inválido'
                          : null,
                    ),
                ],
              ],
            ),
          ),
          const Gap(),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    if (!form.currentState!.validate()) return;
                    if (!dateConfirmed) {
                      notice(
                        context,
                        'Selecciona y confirma la fecha del gasto.',
                      );
                      return;
                    }
                    final total = parseCents(amount.text)!;
                    final breakdown = <String, int>{};
                    if (payment == 'Pago mixto') {
                      for (final e in parts.entries) {
                        final n = parseCents(e.value.text) ?? 0;
                        if (n > 0) breakdown[e.key] = n;
                      }
                      if (breakdown.length < 2 ||
                          breakdown.values.fold<int>(0, (a, b) => a + b) !=
                              total) {
                        notice(
                          context,
                          'Usa al menos dos métodos y asegúrate de que sumen el total.',
                        );
                        return;
                      }
                    }
                    setState(() => saving = true);
                    try {
                      await ref
                          .read(expensesProvider.notifier)
                          .add(
                            Expense(
                              cents: total,
                              concept: concept.text.trim(),
                              merchant: merchant.text.trim(),
                              date: date,
                              category: category!,
                              payment: payment,
                              reference: reference.text.trim(),
                              parts: breakdown,
                              image: widget.image,
                              recognizedText: widget.draft?.text,
                              suggestedTotal: widget.draft?.total,
                              suggestedDate: widget.draft?.date,
                              suggestedPayment: widget.draft?.payment,
                              suggestedMerchant: widget.draft?.merchant,
                              suggestedReference: widget.draft?.reference,
                              suggestedCategory: widget.draft?.category,
                            ),
                          );
                    } catch (_) {
                      if (context.mounted) {
                        setState(() => saving = false);
                        notice(
                          context,
                          'No se pudo guardar el gasto. Inténtalo de nuevo.',
                        );
                      }
                      return;
                    }
                    if (!context.mounted) return;
                    context.go('/registros');
                    notice(
                      context,
                      LocalStore.instance.demo
                          ? 'Gasto guardado en la sesión de demostración.'
                          : 'Gasto guardado en este dispositivo.',
                    );
                  },
            child: const Text('GUARDAR GASTO'),
          ),
          const Gap(8),
          OutlinedButton(
            onPressed: () => context.go('/inicio'),
            child: const Text('CANCELAR'),
          ),
        ],
      ),
    ),
  );
}

class ExpenseTile extends StatelessWidget {
  const ExpenseTile({super.key, required this.expense});
  final Expense expense;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Panel(
      padding: const EdgeInsets.all(12),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(
          backgroundColor: Color(0xffd8f0e5),
          child: Icon(Icons.receipt_long_outlined, color: green),
        ),
        title: Text(
          expense.merchant,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${expense.concept}\n${dateLabel(expense.date)} · ${expense.category}\n${expense.payment} · ${expense.image == null ? 'Manual' : 'Manual con foto'}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: Text(
          money(expense.cents),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onTap: () => showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Detalle del gasto'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Importe: ${money(expense.cents)} MXN'),
                  Text('Concepto: ${expense.concept}'),
                  Text('Comercio: ${expense.merchant}'),
                  Text('Fecha: ${dateLabel(expense.date)}'),
                  Text('Categoría: ${expense.category}'),
                  Text('Método: ${expense.payment}'),
                  for (final e in expense.parts.entries)
                    Text('${e.key}: ${money(e.value)}'),
                  Text(
                    'Referencia: ${expense.reference.isEmpty ? 'Sin referencia' : expense.reference}',
                  ),
                  Text(
                    'Origen: ${expense.image == null ? 'Manual' : 'Manual con foto'}',
                  ),
                  if (expense.image != null) ...[
                    const Gap(),
                    Image.memory(expense.image!, fit: BoxFit.contain),
                  ],
                  if (expense.recognizedText?.isNotEmpty ?? false) ...[
                    const Gap(),
                    const Text('Texto OCR original:'),
                    SelectableText(expense.recognizedText!),
                    Text(
                      'Categoría sugerida: ${expense.suggestedCategory ?? 'Sin identificar'}',
                    ),
                    Text(
                      'Comercio sugerido: ${expense.suggestedMerchant ?? 'Sin identificar'}',
                    ),
                    Text(
                      'Folio sugerido: ${expense.suggestedReference ?? 'Sin identificar'}',
                    ),
                    Text(
                      'Total sugerido: ${expense.suggestedTotal ?? 'Sin identificar'}',
                    ),
                    Text(
                      'Fecha sugerida: ${expense.suggestedDate == null ? 'Sin identificar' : dateLabel(expense.suggestedDate!)}',
                    ),
                    Text(
                      'Pago sugerido: ${expense.suggestedPayment ?? 'Desconocido'}',
                    ),
                    const Text(
                      'Los valores del gasto son los confirmados por el usuario.',
                    ),
                  ],
                  const Text('Estado de liquidación: No indicado'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class RecordsScreen extends ConsumerStatefulWidget {
  const RecordsScreen({super.key});
  @override
  ConsumerState<RecordsScreen> createState() => _RecordsState();
}

class _RecordsState extends ConsumerState<RecordsScreen> {
  String query = '', cat = 'Todas', pay = 'Todos';
  DateTimeRange? range;
  @override
  Widget build(BuildContext context) {
    final all = ref.watch(expensesProvider);
    final list = all
        .where(
          (e) =>
              ('${e.merchant} ${e.concept}'.toLowerCase().contains(
                query.toLowerCase(),
              )) &&
              (cat == 'Todas' || e.category == cat) &&
              (pay == 'Todos' || e.payment == pay) &&
              (range == null ||
                  (!e.date.isBefore(range!.start) &&
                      e.date.isBefore(
                        range!.end.add(const Duration(days: 1)),
                      ))),
        )
        .toList();
    final total = list.fold<int>(0, (a, e) => a + e.cents);
    return Shell(
      title: 'Registros',
      index: 1,
      body: PageBody(
        children: [
          Text(
            'Registros de gastos',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Gap(),
          TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar comercio o concepto',
            ),
          ),
          const Gap(),
          Panel(
            color: const Color(0xffe7eefc),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('RESUMEN DEL PERIODO SELECCIONADO'),
                const Gap(8),
                Text(
                  '${money(total)} MXN',
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${list.length} gastos${LocalStore.instance.demo ? ' · Demostración' : ''}',
                ),
              ],
            ),
          ),
          const Gap(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: Text(
                  range == null
                      ? 'Todas las fechas'
                      : '${dateLabel(range!.start)} – ${dateLabel(range!.end)}',
                ),
                onPressed: () async {
                  final r = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (r != null) setState(() => range = r);
                },
              ),
              if (range != null)
                ActionChip(
                  label: const Text('Limpiar fechas'),
                  onPressed: () => setState(() => range = null),
                ),
              DropdownButton<String>(
                value: cat,
                items: ['Todas', ...categories]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => cat = v!),
              ),
              DropdownButton<String>(
                value: pay,
                items: ['Todos', ...payments]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => pay = v!),
              ),
            ],
          ),
          const Gap(),
          const Text(
            'Últimos gastos',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
          ),
          const Gap(),
          if (list.isEmpty)
            const Panel(
              child: Text(
                'No hay gastos para mostrar. Registra uno para comenzar.',
              ),
            )
          else
            ...list.map((e) => ExpenseTile(expense: e)),
        ],
      ),
    );
  }
}
