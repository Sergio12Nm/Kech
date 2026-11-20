import 'package:material_ui/material_ui.dart';

import '../../shared/ui.dart';

abstract class AssistantService {
  Future<String?> send(String message);
}

class PendingAssistantService implements AssistantService {
  @override
  Future<String?> send(String message) async => null;
}

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});
  @override
  State<AssistantScreen> createState() => _AssistantState();
}

class _AssistantState extends State<AssistantScreen> {
  final input = TextEditingController();
  final List<String> messages = [];
  final AssistantService service = PendingAssistantService();
  bool loading = false;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> send(String value) async {
    final text = value.trim();
    if (text.isEmpty || loading) return;
    setState(() {
      messages.add(text);
      input.clear();
      loading = true;
    });
    await service.send(text);
    if (!mounted) return;
    setState(() => loading = false);
    notice(
      context,
      'Chequi aún no está conectado. No se ha realizado ningún análisis.',
    );
  }

  @override
  Widget build(BuildContext context) => Shell(
    title: 'Asistente',
    index: 2,
    body: Column(
      children: [
        Expanded(
          child: PageBody(
            children: [
              const Panel(
                color: Color(0xffe7eefc),
                child: Text(
                  '¡Hola! Soy Chequi, ¿en qué puedo ayudarte?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const Gap(),
              const Text(
                'Consultas sugeridas · Servicio pendiente de integración',
              ),
              const Gap(8),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in [
                    '¿Cuánto gasté hoy?',
                    'Muéstrame mis últimos gastos',
                    '¿Cuánto pagué con tarjeta?',
                    '¿Cuánto gasté esta semana?',
                    'Ayúdame a registrar un gasto',
                  ])
                    ActionChip(label: Text(s), onPressed: () => send(s)),
                ],
              ),
              const Gap(),
              for (final m in messages)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10, left: 30),
                    child: Panel(
                      color: blue,
                      child: Text(
                        m,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              if (loading) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    onSubmitted: send,
                    decoration: const InputDecoration(
                      hintText: 'Escribe una consulta a Chequi...',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: loading ? null : () => send(input.text),
                  icon: const Icon(Icons.send),
                  tooltip: 'Enviar',
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
