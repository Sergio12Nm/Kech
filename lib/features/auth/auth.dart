import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/local_store.dart';
import '../expenses/model.dart';

import '../../shared/ui.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginState();
}

class _LoginState extends ConsumerState<LoginScreen> {
  bool hidden = true;
  bool busy = false;
  final identifier = TextEditingController(),
      password = TextEditingController();
  @override
  void dispose() {
    identifier.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (identifier.text.trim().isEmpty || password.text.isEmpty) {
      notice(context, 'Introduce tu correo o usuario y contraseña.');
      return;
    }
    setState(() => busy = true);
    try {
      final ok = await LocalStore.instance.login(
        identifier.text,
        password.text,
      );
      if (!mounted) return;
      if (!ok) {
        notice(context, 'Correo, usuario o contraseña incorrectos.');
        return;
      }
      await ref
          .read(expensesProvider.notifier)
          .load(LocalStore.instance.session.value!);
      if (mounted) context.go('/inicio');
    } catch (_) {
      LocalStore.instance.logout();
      if (mounted) {
        notice(context, 'No se pudo iniciar sesión en este dispositivo.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

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
          const Text('Cuenta local: tus datos permanecen en este dispositivo.', textAlign: TextAlign.center),
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
                LabeledField(
                  label: 'Correo electrónico o usuario',
                  controller: identifier,
                ),
                LabeledField(
                  label: 'Contraseña',
                  controller: password,
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
                  onPressed: busy ? null : login,
                  child: Text(busy ? 'INICIANDO…' : 'INICIAR SESIÓN'),
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
              onPressed: () {
                LocalStore.instance.enterDemo();
                ref.read(expensesProvider.notifier).clear();
                context.go('/inicio');
              },
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
  final name = TextEditingController(),
      surname = TextEditingController(),
      email = TextEditingController(),
      username = TextEditingController(),
      businessName = TextEditingController();
  bool busy = false;
  bool business = false, terms = false, hidden = true;
  @override
  void dispose() {
    password.dispose();
    for (final c in [name, surname, email, username, businessName]) {
      c.dispose();
    }
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
                LabeledField(
                  label: 'Nombre',
                  controller: name,
                  validator: requiredText,
                ),
                LabeledField(
                  label: 'Apellidos',
                  controller: surname,
                  validator: requiredText,
                ),
                LabeledField(
                  label: 'Correo electrónico',
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      v == null ||
                          !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)
                      ? 'Introduce un correo válido'
                      : null,
                ),
                LabeledField(
                  label: 'Nombre de usuario (opcional)',
                  controller: username,
                  validator: (v) => v != null && v.contains('@')
                      ? 'El usuario no puede contener @'
                      : null,
                ),
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
                  LabeledField(
                    label: 'Nombre del negocio',
                    controller: businessName,
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
            onPressed: busy
                ? null
                : () async {
                    if (form.currentState!.validate()) {
                      if (!terms) {
                        notice(context, 'Acepta los términos para continuar.');
                        return;
                      }
                      setState(() => busy = true);
                      try {
                        await LocalStore.instance.register(
                          name: name.text,
                          surname: surname.text,
                          email: email.text,
                          username: username.text,
                          password: password.text,
                          business: business,
                          businessName: businessName.text,
                        );
                        if (context.mounted) {
                          context.go('/');
                          notice(
                            context,
                            'Cuenta creada en este dispositivo. Inicia sesión.',
                          );
                        }
                      } on DatabaseException catch (e) {
                        if (context.mounted) {
                          notice(
                            context,
                            e.isUniqueConstraintError()
                                ? 'El correo o usuario ya está registrado.'
                                : 'No se pudo crear la cuenta.',
                          );
                        }
                      } catch (_) {
                        if (context.mounted) {
                          notice(
                            context,
                            'No se pudo crear la cuenta en este dispositivo.',
                          );
                        }
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
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
                'Recuperación de cuenta\nLas cuentas y sus contraseñas son locales. La recuperación por correo aún no está disponible. Si olvidas tu contraseña, no podrás acceder a los datos de esta cuenta.',
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
