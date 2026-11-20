import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

const blue = Color(0xff526f8d),
    green = Color(0xff5f927b),
    ink = Color(0xff1c2b43),
    background = Color(0xfff3f7fa),
    border = Color(0xffcdd9e6);
String money(int cents) => NumberFormat.currency(
  locale: 'es_MX',
  symbol: '\$',
  decimalDigits: 2,
).format(cents / 100);
String dateLabel(DateTime date) =>
    DateFormat('d MMM yyyy', 'es_MX').format(date);

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final Color color;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: border.withValues(alpha: .35)),
    ),
    child: Material(color: Colors.transparent, child: child),
  );
}

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );
}

class Gap extends StatelessWidget {
  // ignore: use_key_in_widget_constructors
  const Gap([this.height = 16]);
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}

class Brand extends StatelessWidget {
  const Brand({super.key, this.size = 52});
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.asset(
      'assets/kech_logo.jpeg',
      width: size,
      height: size,
      fit: BoxFit.cover,
    ),
  );
}

void notice(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

class Shell extends StatelessWidget {
  const Shell({
    super.key,
    required this.title,
    required this.index,
    required this.body,
  });
  final String title;
  final int index;
  final Widget body;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          const Brand(size: 36),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('KECH', style: TextStyle(fontSize: 11, color: green)),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => context.go('/asistente'),
          icon: const Icon(Icons.smart_toy_outlined),
          tooltip: 'Chequi',
        ),
      ],
    ),
    body: body,
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (i) =>
          context.go(['/inicio', '/registros', '/asistente'][i]),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Inicio'),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          label: 'Registros',
        ),
        NavigationDestination(
          icon: Icon(Icons.smart_toy_outlined),
          label: 'Asistente',
        ),
      ],
    ),
  );
}

class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    this.controller,
    this.validator,
    this.obscure = false,
    this.keyboardType,
    this.suffix,
    this.hint,
  });
  final String label;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final String? hint;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      validator: validator,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffix,
      ),
    ),
  );
}

String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'Este campo es obligatorio' : null;

