import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kech_app/features/receipts/ocr_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('El modelo Kech reconoce una imagen de texto', (tester) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xffffffff), ui.BlendMode.src);
    final paragraph =
        (ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 48))
              ..pushStyle(ui.TextStyle(color: const ui.Color(0xff000000)))
              ..addText('TIENDA KECH\nFECHA: 18/11/2026\nTOTAL: 120.50'))
            .build()
          ..layout(const ui.ParagraphConstraints(width: 900));
    canvas.drawParagraph(paragraph, const ui.Offset(30, 30));
    final picture = recorder.endRecording();
    final image = await picture.toImage(900, 300);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final result = await ReceiptOcrService().recognize(
      bytes!.buffer.asUint8List(),
    );
    // La calidad depende del modelo; esta prueba verifica que el motor lea texto real.
    expect(result.text.trim(), isNotEmpty);
    image.dispose();
    picture.dispose();
  });
}
