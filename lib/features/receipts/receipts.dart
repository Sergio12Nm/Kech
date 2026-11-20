import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../shared/ui.dart';
import 'ocr_service.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ImagePicker picker = ImagePicker();
  bool busy = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _recoverLostImage();
    }
  }

  Future<void> _recoverLostImage() async {
    try {
      final response = await picker.retrieveLostData();
      if (!mounted || response.isEmpty) return;
      if (response.exception != null) {
        notice(
          context,
          'No se pudo recuperar la fotografía. Inténtalo de nuevo.',
        );
      } else if (response.files?.isNotEmpty ?? false) {
        await _openImage(response.files!.first);
      }
    } on PlatformException {
      if (mounted) notice(context, 'No se pudo recuperar la fotografía.');
    }
  }

  Future<void> _pick(ImageSource source) async {
    setState(() => busy = true);
    try {
      final image = await picker.pickImage(source: source);
      if (image != null && mounted) await _openImage(image);
    } on PlatformException catch (error) {
      if (mounted) {
        final denied = error.code.toLowerCase().contains('denied');
        notice(
          context,
          denied
              ? 'No se concedió acceso. Revisa los permisos del dispositivo.'
              : 'No se pudo abrir la cámara o galería. Inténtalo de nuevo.',
        );
      }
    } catch (_) {
      if (mounted) {
        notice(context, 'No se pudo abrir la imagen. Inténtalo de nuevo.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _openImage(XFile file) async {
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.isEmpty) {
      notice(context, 'La imagen está vacía. Selecciona otra.');
      return;
    }
    context.push('/revisar', extra: bytes);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Escanear ticket')),
    body: PageBody(
      children: [
        const Panel(
          color: Color(0xffe7eefc),
          child: Text(
            'Fotografía tu ticket o selecciona una imagen. Se abrirá la cámara o galería del dispositivo.',
          ),
        ),
        const Gap(),
        Container(
          height: 300,
          padding: const EdgeInsets.all(35),
          decoration: BoxDecoration(
            color: const Color(0xff34465d),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xffbcebd5), width: 3),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.document_scanner_outlined,
                    color: Colors.white,
                    size: 56,
                  ),
                  Gap(),
                  Text(
                    'Encuadra el ticket en la cámara',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Gap(),
        if (busy) const Center(child: CircularProgressIndicator()),
        const Gap(),
        FilledButton.icon(
          onPressed: busy ? null : () => _pick(ImageSource.camera),
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('ABRIR CÁMARA'),
        ),
        const Gap(8),
        OutlinedButton.icon(
          onPressed: busy ? null : () => _pick(ImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('SELECCIONAR DE GALERÍA'),
        ),
        TextButton(
          onPressed: busy ? null : () => context.go('/gasto'),
          child: const Text('Volver al registro manual'),
        ),
      ],
    ),
  );
}

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, this.image});
  final Uint8List? image;
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  ReceiptDraft? draft;
  bool processing = false;
  String? error;
  @override
  void initState() {
    super.initState();
    if (widget.image != null) _recognize();
  }

  Future<void> _recognize() async {
    setState(() {
      processing = true;
      error = null;
      draft = null;
    });
    try {
      final result = await ReceiptOcrService().recognize(widget.image!);
      if (mounted) setState(() => draft = result);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'No se pudo reconocer el texto con el modelo Kech. Puedes reintentar o continuar manualmente.',
        );
      }
    } finally {
      if (mounted) setState(() => processing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Revisar ticket')),
    body: PageBody(
      children: [
        const Panel(
          color: Color(0xffe7eefc),
          child: Text(
            'Revisa la imagen y confirma o corrige todos los datos antes de guardar. El texto reconocido puede contener errores.',
          ),
        ),
        const Gap(),
        if (widget.image != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.memory(
              widget.image!,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Panel(child: Text('No se pudo mostrar la imagen.')),
            ),
          )
        else
          const Panel(child: Text('No hay ninguna fotografía seleccionada.')),
        const Gap(),
        if (processing)
          const Panel(
            child: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Expanded(child: Text('Reconociendo texto en el dispositivo…')),
              ],
            ),
          )
        else if (error != null)
          Panel(
            child: Column(
              children: [
                Text(error!),
                TextButton(
                  onPressed: _recognize,
                  child: const Text('REINTENTAR'),
                ),
              ],
            ),
          )
        else if (draft != null)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Texto reconocido',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Gap(8),
                SelectableText(
                  draft!.text.isEmpty
                      ? 'No se encontró texto. Intenta con una imagen más clara.'
                      : draft!.text,
                ),
                const Gap(),
                Text(
                  'Total sugerido: ${draft!.total == null ? 'Sin identificar' : '\$${draft!.total}'}',
                ),
                Text(
                  'Fecha sugerida: ${draft!.date == null ? 'Sin identificar' : dateLabel(draft!.date!)}',
                ),
                Text(
                  'Método de pago sugerido: ${draft!.payment ?? 'Desconocido'}',
                ),
                Text(
                  'Comercio sugerido: ${draft!.merchant ?? 'Sin identificar'}',
                ),
                Text(
                  'Folio sugerido: ${draft!.reference ?? 'Sin identificar'}',
                ),
                Text(
                  'Productos identificados: ${draft!.products.isEmpty ? 'Sin identificar' : draft!.products.join(', ')}',
                ),
                Text(
                  'Categoría sugerida: ${draft!.category ?? 'Sin identificar; selecciona una categoría'}',
                ),
                const Text(
                  'Las sugerencias deben verificarse con la fotografía.',
                ),
              ],
            ),
          ),
        const Gap(),
        FilledButton(
          onPressed: widget.image == null || processing
              ? null
              : () => context.push(
                  '/gasto',
                  extra: draft ?? ReceiptDraft(image: widget.image!, text: ''),
                ),
          child: const Text('REVISAR Y REGISTRAR GASTO'),
        ),
        const Gap(),
        OutlinedButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/escanear'),
          child: const Text('ELEGIR OTRA IMAGEN'),
        ),
      ],
    ),
  );
}
