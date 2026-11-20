import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';

class ReceiptDraft {
  const ReceiptDraft({
    required this.image,
    required this.text,
    this.total,
    this.date,
    this.payment,
    this.merchant,
    this.reference,
    this.category,
    this.products = const [],
  });
  final Uint8List image;
  final String text;
  final String? total;
  final DateTime? date;
  final String? payment;
  final String? merchant, reference;
  final String? category;
  final List<String> products;
}

String _normalize(String text) => text
    .toLowerCase()
    .replaceAll(RegExp('[áà]'), 'a')
    .replaceAll(RegExp('[éè]'), 'e')
    .replaceAll(RegExp('[íì]'), 'i')
    .replaceAll(RegExp('[óò]'), 'o')
    .replaceAll(RegExp('[úùü]'), 'u')
    .replaceAll('ñ', 'n');

const _productWords = <String, List<String>>{
  'Alimentos': [
    'limon',
    'jicama',
    'pina',
    'manzana',
    'platano',
    'naranja',
    'fruta',
    'verdura',
    'leche',
    'pan',
    'huevo',
    'arroz',
    'frijol',
    'carne',
    'pollo',
    'queso',
    'cafe',
    'agua',
    'yogur',
    'aceite',
    'azucar',
    'tomate',
    'papa',
    'tortilla',
  ],
  'Insumos': [
    'estambre',
    'cierre metalico',
    'hilo',
    'tela',
    'boton',
    'aguja',
    'cremallera',
    'etiqueta',
    'empaque',
    'bolsa',
    'papeleria',
    'papel',
    'tinta',
    'carton',
  ],
  'Transporte': [
    'gasolina',
    'diesel',
    'combustible',
    'peaje',
    'estacionamiento',
    'pasaje',
  ],
  'Servicios': [
    'electricidad',
    'energia electrica',
    'internet',
    'telefonia',
    'servicio de agua',
  ],
  'Operación': [
    'limpieza',
    'detergente',
    'jabon',
    'desinfectante',
    'escoba',
    'mantenimiento',
  ],
};

String? classifyProducts(List<String> products) {
  if (products.isEmpty) return null;
  final found = <String>{};
  for (final product in products) {
    final normalized = _normalize(product);
    final matches = <String>{};
    for (final entry in _productWords.entries) {
      for (final word in entry.value) {
        if (RegExp('(?:^|[^a-z])${RegExp.escape(word)}(?:s|es)?(?:\$|[^a-z])')
            .hasMatch(normalized)) {
          matches.add(entry.key);
        }
      }
    }
    if (matches.length != 1) return null;
    found.add(matches.single);
  }
  return found.length == 1 ? found.single : null;
}

String redactSensitiveText(String text) {
  return text
      .split('\n')
      .map((line) {
        if (RegExp(
          r'\b(?:cvv|cvc|nip|pin)\b',
          caseSensitive: false,
        ).hasMatch(line)) {
          return '[Datos sensibles omitidos]';
        }
        return line.replaceAllMapped(
          RegExp(r'(?<!\d)(?:\d[ -]?){13,19}(?!\d)'),
          (match) => '[Número sensible omitido]',
        );
      })
      .join('\n');
}

/// Solo sugiere un total cuando una única línea lo identifica de forma clara.
ReceiptDraft extractReceipt(Uint8List image, String text) {
  final totals = <String>{};
  final dates = <DateTime>{};
  final methods = <String>{};
  final references = <String>{};
  final products = <String>[];
  final lines = text
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  String? merchant;
  if (lines.isNotEmpty) {
    final first = lines.first;
    if (first.length >= 4 &&
        first.length <= 80 &&
        RegExp(r'^[A-ZÁÉÍÓÚÑÜ &.\-]+$').hasMatch(first) &&
        !RegExp(
          r'^(?:TICKET|RECIBO|FACTURA|NOTA|TOTAL|BIENVENIDO)',
          caseSensitive: false,
        ).hasMatch(first)) {
      merchant = first;
    }
  }
  for (final line in text.split('\n')) {
    final lower = line.toLowerCase();
    final item = RegExp(
      r'^\s*\d+(?:[.,]\d+)?\s*[xX×]\s*(.+?)\s+\$?\d+[.,]\d{2}\s*$',
    ).firstMatch(line);
    if (item != null) products.add(item[1]!.trim());
    if (RegExp(
      r'^\s*(?:gran\s+total|total(?:\s+a\s+pagar)?|importe\s+total)\s*[:\-]?\s*\$?\s*\d+[.,]\d{2}\s*$',
      caseSensitive: false,
    ).hasMatch(line)) {
      final amount = RegExp(r'\d+[.,]\d{2}').firstMatch(line);
      if (amount != null) totals.add(amount.group(0)!.replaceAll(',', '.'));
    }
    final folio = RegExp(
      r'^\s*(?:folio|referencia)\s*[:#]?\s*([A-Za-z0-9][A-Za-z0-9-]{1,30})\s*$',
      caseSensitive: false,
    ).firstMatch(line);
    if (folio != null) references.add(folio[1]!);
    if (RegExp(r'\bfecha\b', caseSensitive: false).hasMatch(line)) {
      for (final match in RegExp(
        r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{4})\b',
      ).allMatches(line)) {
        final day = int.parse(match[1]!);
        final month = int.parse(match[2]!);
        final year = int.parse(match[3]!);
        final date = DateTime(year, month, day);
        if (year >= 2000 &&
            year <= 2100 &&
            date.year == year &&
            date.month == month &&
            date.day == day) {
          dates.add(date);
        }
      }
    }
    if (RegExp(r'\b(?:forma|m[eé]todo|medio)\s+de\s+pago\b').hasMatch(lower) ||
        RegExp(
          r'^\s*tarjeta\s+(?:de\s+)?(?:d[eé]bito|cr[eé]dito)\s*$',
          caseSensitive: false,
        ).hasMatch(lower)) {
      if (RegExp(r'\befectivo\b').hasMatch(lower)) methods.add('Efectivo');
      if (RegExp(r'\b(?:tarjeta\s+(?:de\s+)?d[eé]bito|d[eé]bito)\b')
          .hasMatch(lower)) {
        methods.add('Tarjeta de débito');
      }
      if (RegExp(r'\b(?:tarjeta\s+(?:de\s+)?cr[eé]dito|cr[eé]dito)\b')
          .hasMatch(lower)) {
        methods.add('Tarjeta de crédito');
      }
      if (RegExp(r'\btransferencia\b').hasMatch(lower)) {
        methods.add('Transferencia');
      }
      if (RegExp(r'\bbilletera\s+digital\b').hasMatch(lower)) {
        methods.add('Billetera digital');
      }
      if (RegExp(r'\bmixto\b').hasMatch(lower) ||
          (RegExp(r'\btarjeta\b').hasMatch(lower) &&
              !RegExp(r'd[eé]bito|cr[eé]dito').hasMatch(lower))) {
        methods.add('Desconocido');
      }
    }
  }
  return ReceiptDraft(
    image: image,
    text: text,
    total: totals.length == 1 ? totals.single : null,
    date: dates.length == 1 ? dates.single : null,
    payment: methods.length == 1 && methods.single != 'Desconocido'
        ? methods.single
        : null,
    merchant: merchant,
    reference: references.length == 1 ? references.single : null,
    products: products,
    category: classifyProducts(products),
  );
}

class ReceiptOcrService {
  Future<ReceiptDraft> recognize(Uint8List image) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError(
        'El OCR con el modelo Kech está disponible en Android.',
      );
    }
    final tempRoot = await getTemporaryDirectory();
    final directory = await tempRoot.createTemp('kech_ocr_');
    try {
      final file = File('${directory.path}/ticket');
      await file.writeAsBytes(image, flush: true);
      final text = await TesseractOcr.extractText(
        file.path,
        config: const OCRConfig(language: 'kech', engine: OCREngine.tesseract),
      );
      return extractReceipt(image, redactSensitiveText(text.trim()));
    } finally {
      await directory.delete(recursive: true);
    }
  }
}
