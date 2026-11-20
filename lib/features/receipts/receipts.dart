import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../shared/ui.dart';

class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Escanear ticket')),
    body: PageBody(
      children: [
        const Text(
          'Cámara pendiente de integración',
          style: TextStyle(color: green, fontWeight: FontWeight.bold),
        ),
        const Gap(),
        Container(
          height: 360,
          decoration: BoxDecoration(
            color: const Color(0xff34465d),
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.all(35),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xffbcebd5), width: 3),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: Text(
                'Vista de cámara no disponible\n\nColoca el ticket dentro del recuadro',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
        const Gap(),
        const Text(
          'La captura y la selección de imágenes se habilitarán al integrar la cámara y el OCR.',
          textAlign: TextAlign.center,
        ),
        const Gap(),
        FilledButton.icon(
          onPressed: () => notice(context, 'La cámara aún no está integrada.'),
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('CAPTURAR'),
        ),
        const Gap(8),
        OutlinedButton.icon(
          onPressed: () => notice(context, 'La galería aún no está integrada.'),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('SELECCIONAR DE GALERÍA'),
        ),
        TextButton(
          onPressed: () => context.go('/gasto'),
          child: const Text('Volver al registro manual'),
        ),
        TextButton(
          onPressed: () => context.push('/revisar'),
          child: const Text('Ver pantalla de revisión pendiente'),
        ),
      ],
    ),
  );
}

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Revisar ticket')),
    body: PageBody(
      children: [
        const Panel(
          color: Color(0xffe7eefc),
          child: Text(
            'OCR pendiente de integración. No hay fotografía ni datos reconocidos para revisar.',
          ),
        ),
        const Gap(),
        const Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.image_outlined, size: 48, color: blue),
              Text('Fotografía no disponible'),
              Gap(),
              Text('Texto reconocido: pendiente'),
              Gap(),
              Text('Comercio: sin identificar'),
              Text('Fecha: sin identificar'),
              Text('Total: sin identificar'),
              Text('Método de pago: Desconocido'),
              Gap(),
              Text(
                'Los datos deberán revisarse y confirmarse antes de guardar.',
              ),
            ],
          ),
        ),
        const Gap(),
        FilledButton(onPressed: null, child: const Text('CONFIRMAR Y GUARDAR')),
        const Gap(),
        OutlinedButton(
          onPressed: () => context.go('/gasto'),
          child: const Text('REGISTRAR MANUALMENTE'),
        ),
      ],
    ),
  );
}
