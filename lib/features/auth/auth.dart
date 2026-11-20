import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../shared/ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  bool hidden = true;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: PageBody(
        children: [
          const Gap(24),
          const Center(child: Brand(size: 90)),
          const Gap(),
          Text(
            'KECH',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Text('GESTOR DE GASTOS Y RECIBOS', textAlign: TextAlign.center),
          const Gap(30),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Iniciar sesión',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Gap(24),
                const LabeledField(label: 'Correo electrónico o usuario'),
                LabeledField(
                  label: 'Contraseña',
                  obscure: hidden,
                  suffix: IconButton(
                    onPressed: () => setState(() => hidden = !hidden),
                    icon: Icon(
                      hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/recuperar'),
                    child: const Text('Olvidé mi contraseña'),
                  ),
                ),
                const Gap(),
                FilledButton(
                  onPressed: () => notice(
                    context,
                    'El inicio de sesión estará disponible al integrar el servicio.',
                  ),
                  child: const Text('INICIAR SESIÓN'),
                ),
              ],
            ),
          ),
          const Gap(),
          OutlinedButton(
            onPressed: () => context.push('/crear'),
            child: const Text('CREAR CUENTA'),
          ),
          if (kDebugMode) ...[
            const Gap(),
            FilledButton.tonal(
              onPressed: () => context.go('/inicio'),
              child: const Text('Entrar en modo demostración'),
            ),
          ],
          const Gap(),
          const Panel(
            color: Color(0xffe7eefc),
            child: Text(
              'Chequi · Tu asistente\nOrganiza tus gastos y recibos en un solo lugar.',
            ),
          ),
        ],
      ),
    ),
  );
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterState();
}

class _RegisterState extends State<RegisterScreen> {
  final form = GlobalKey<FormState>();
  final password = TextEditingController();
  bool business = false, terms = false, hidden = true;
  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Crear cuenta')),
    body: Form(
      key: form,
      child: PageBody(
        children: [
          const Panel(
            color: Color(0xffe7eefc),
            child: Text('KECH • Gestor de gastos y recibos\nCrear cuenta'),
          ),
          const Gap(),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DATOS PERSONALES',
                  style: TextStyle(fontWeight: FontWeight.bold, color: blue),
                ),
                const Gap(),
                const LabeledField(label: 'Nombre', validator: requiredText),
                const LabeledField(label: 'Apellidos', validator: requiredText),
                LabeledField(
                  label: 'Correo electrónico',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      v == null ||
                          !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)
                      ? 'Introduce un correo válido'
                      : null,
                ),
                const LabeledField(label: 'Nombre de usuario (opcional)'),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Personal')),
                    ButtonSegment(value: true, label: Text('Negocio')),
                  ],
                  selected: {business},
                  onSelectionChanged: (v) => setState(() => business = v.first),
                ),
                const Gap(),
                if (business)
                  const LabeledField(
                    label: 'Nombre del negocio',
                    validator: requiredText,
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
                  'SEGURIDAD',
                  style: TextStyle(fontWeight: FontWeight.bold, color: blue),
                ),
                const Gap(),
                LabeledField(
                  label: 'Contraseña',
                  controller: password,
                  obscure: hidden,
                  suffix: IconButton(
                    onPressed: () => setState(() => hidden = !hidden),
                    icon: const Icon(Icons.visibility_outlined),
                  ),
                  validator: (v) =>
                      v == null || v.length < 8 || !RegExp(r'\d').hasMatch(v)
                      ? 'Usa al menos 8 caracteres y un número'
                      : null,
                ),
                LabeledField(
                  label: 'Confirmar contraseña',
                  obscure: hidden,
                  validator: (v) => v != password.text || v == null || v.isEmpty
                      ? 'Las contraseñas deben coincidir'
                      : null,
                ),
              ],
            ),
          ),
          CheckboxListTile(
            value: terms,
            onChanged: (v) => setState(() => terms = v ?? false),
            title: const Text('Acepto los términos y condiciones'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                if (!terms) {
                  notice(context, 'Acepta los términos para continuar.');
                  return;
                }
                notice(
                  context,
                  'El registro de cuentas está pendiente de integración.',
                );
              }
            },
            child: const Text('CREAR CUENTA'),
          ),
        ],
      ),
    ),
  );
}

class RecoveryScreen extends StatelessWidget {
  const RecoveryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final key = GlobalKey<FormState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: Form(
        key: key,
        child: PageBody(
          children: [
            const Panel(
              color: Color(0xffe7eefc),
              child: Text(
                'Recuperación de cuenta\nEl envío, la verificación y el cambio de contraseña estarán disponibles cuando se integre el servicio.',
              ),
            ),
            const Gap(24),
            LabeledField(
              label: 'Correo electrónico',
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  v == null ||
                      !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)
                  ? 'Introduce un correo válido'
                  : null,
            ),
            FilledButton(
              onPressed: () {
                if (key.currentState!.validate()) {
                  notice(
                    context,
                    'Servicio de recuperación aún no disponible. No se ha enviado ningún correo.',
                  );
                }
              },
              child: const Text('SOLICITAR RECUPERACIÓN'),
            ),
            const Gap(24),
            const ListTile(
              leading: Icon(Icons.lock_clock_outlined),
              title: Text('Verificación y nueva contraseña'),
              subtitle: Text('Pendiente de integración con el servicio.'),
            ),
          ],
        ),
      ),
    );
  }
}

