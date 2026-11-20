import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/local_store.dart';
import '../../shared/ui.dart';
import '../expenses/model.dart';
import 'assistant_service.dart';
import 'guided_expense.dart';
import 'voice_service.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});
  @override
  ConsumerState<AssistantScreen> createState() => _AssistantState();
}

class _ChatMessage {
  const _ChatMessage(this.text, {this.user = false, this.draft});
  final String text;
  final bool user;
  final AssistantDraft? draft;
}

class _AssistantState extends ConsumerState<AssistantScreen>
    with WidgetsBindingObserver {
  final input = TextEditingController();
  final apiKey = TextEditingController();
  final service = AssistantService();
  final guided = GuidedExpense();
  final voice = VoiceService();
  bool listening = false, startingMic = false, readAloud = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      voice.stop();
      if (mounted) setState(() => listening = false);
    }
  }

  Future<void> read(String text) async {
    if (!readAloud) return;
    try {
      await voice.speak(text);
    } catch (_) {
      if (mounted) {
        notice(
          context,
          'No se pudo reproducir voz. Revisa el motor de texto a voz y las voces en español.',
        );
      }
    }
  }

  Future<void> microphone() async {
    if (startingMic) return;
    if (listening) {
      await voice.stopListening();
      if (mounted) setState(() => listening = false);
      return;
    }
    setState(() => startingMic = true);
    final previous = input.text.trim();
    try {
      await voice.listen(
        onText: (text) {
          if (mounted) {
            final value = [previous, text].where((e) => e.isNotEmpty).join(' ');
            input.value = TextEditingValue(
              text: value,
              selection: TextSelection.collapsed(offset: value.length),
            );
          }
        },
        onListening: (value) {
          if (mounted) setState(() => listening = value);
        },
        onError: (error) {
          if (mounted) notice(context, error);
        },
      );
    } catch (_) {
      if (mounted) {
        notice(
          context,
          'No se pudo iniciar el micrófono. Revisa los permisos del teléfono.',
        );
      }
    } finally {
      if (mounted) setState(() => startingMic = false);
    }
  }

  final List<_ChatMessage> messages = [];
  final List<Map<String, String>> history = [];
  bool loading = false, consent = false;
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    voice.dispose();
    input.dispose();
    apiKey.dispose();
    service.close();
    super.dispose();
  }

  Future<void> send(String value) async {
    final text = value.trim();
    if (text.isEmpty || loading) return;
    await voice.stop();
    if (!mounted) return;
    setState(() => listening = false);
    if (guided.active ||
        RegExp(
          r'\b(?:registrar|registra|anotar|anota|agregar|agrega|nuevo gasto)\b',
          caseSensitive: false,
        ).hasMatch(text)) {
      final reply = guided.active ? guided.answer(text) : guided.start();
      setState(() {
        messages.add(_ChatMessage(text, user: true));
        messages.add(_ChatMessage(reply.text, draft: reply.draft));
        input.clear();
      });
      read(reply.text);
      return;
    }
    if (!LocalStore.instance.demo || LocalStore.instance.session.value != -1) {
      notice(
        context,
        'Para registrar un gasto escribe «registrar gasto». La conversación con OpenRouter solo admite demostración con datos ficticios.',
      );
      return;
    }
    if (!consent) {
      notice(
        context,
        'Confirma que usarás únicamente datos ficticios para continuar.',
      );
      return;
    }
    if (text.length > 1500) {
      notice(context, 'La consulta es demasiado larga.');
      return;
    }
    setState(() {
      messages.add(_ChatMessage(text, user: true));
      input.clear();
      loading = true;
    });
    final outgoing = [
      ...history,
      {'role': 'user', 'content': text},
    ];
    try {
      final reply = await service.send(
        outgoing.length > 10
            ? outgoing.sublist(outgoing.length - 10)
            : outgoing,
        ref.read(expensesProvider),
        apiKey: apiKey.text,
      );
      if (!mounted || !LocalStore.instance.demo) return;
      history.add({'role': 'user', 'content': text});
      if (reply.fromModel) {
        history.add({'role': 'assistant', 'content': reply.text});
      }
      if (history.length > 8) history.removeRange(0, history.length - 8);
      final effectiveReply = reply.draft != null ? guided.start() : reply;
      setState(
        () => messages.add(
          _ChatMessage(
            effectiveReply.fromModel
                ? 'Respuesta de IA sin consultar registros:\n${effectiveReply.text}'
                : effectiveReply.text,
            draft: effectiveReply.draft,
          ),
        ),
      );
      read(effectiveReply.text);
    } catch (e) {
      if (mounted) {
        setState(
          () => messages.add(
            _ChatMessage(
              e is StateError ? e.message.toString() : 'No se pudo procesar la consulta. Revisa la conexión e inténtalo de nuevo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = true;
    return Shell(
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
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Leer respuestas en voz alta'),
                  value: readAloud,
                  onChanged: (value) {
                    setState(() => readAloud = value);
                    if (!value) voice.stopSpeaking();
                  },
                ),
                TextButton.icon(
                  onPressed: () => voice.stopSpeaking(),
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Detener voz'),
                ),
                const Panel(
                  child: Text(
                    'Registro guiado local: escribe «registrar gasto». Te preguntaré un dato a la vez y podrás revisar antes de guardar.',
                  ),
                ),
                if (LocalStore.instance.demo) ...[
                  TextField(
                    controller: apiKey,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Clave API de OpenRouter',
                      helperText: 'Solo en memoria mientras esta pantalla esté abierta.',
                    ),
                  ),
                  const Gap(),
                  const Text(
                    'Demostración: escribe solo datos ficticios. Tus mensajes se enviarán a OpenRouter y NVIDIA para procesarlos; el proveedor puede registrarlos y usarlos para mejorar sus servicios. No incluyas datos personales ni financieros reales.',
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: consent,
                    onChanged: loading
                        ? null
                        : (v) => setState(() => consent = v ?? false),
                    title: const Text(
                      'Acepto enviar únicamente datos ficticios',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
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
                      ActionChip(
                        label: Text(s),
                        onPressed: loading ? null : () => send(s),
                      ),
                  ],
                ),
                const Gap(),
                for (final m in messages)
                  Align(
                    alignment: m.user
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Panel(
                        color: m.user ? blue : Colors.white,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.text,
                              style: TextStyle(
                                color: m.user ? Colors.white : ink,
                              ),
                            ),
                            if (!m.user)
                              IconButton(
                                tooltip: 'Escuchar respuesta',
                                onPressed: () async {
                                  try {
                                    await voice.speak(m.text);
                                  } catch (_) {
                                    if (context.mounted) {
                                      notice(
                                        context,
                                        'No hay una voz en español disponible.',
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.volume_up_outlined),
                              ),
                            if (m.draft != null) ...[
                              const Gap(),
                              FilledButton.tonal(
                                onPressed: () async {
                                  await voice.stop();
                                  if (context.mounted) {
                                    context.push('/gasto', extra: m.draft);
                                  }
                                },
                                child: const Text('REVISAR FORMULARIO'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                if (loading) const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
          if (enabled)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: listening ? 'Detener dictado' : 'Dictar mensaje',
                      onPressed: loading || startingMic ? null : microphone,
                      icon: Icon(listening ? Icons.mic : Icons.mic_none),
                      style: IconButton.styleFrom(
                        foregroundColor: listening ? Colors.red : green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: input,
                        onSubmitted: send,
                        decoration: InputDecoration(
                          hintText: listening
                              ? 'Escuchando… revisa y envía'
                              : 'Escribe «registrar gasto»...',
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
}
