import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceService {
  final _speech = SpeechToText();
  final _tts = FlutterTts();
  bool _ready = false;
  bool _closed = false;
  int _epoch = 0;

  Future<void> listen({
    required void Function(String) onText,
    required void Function(bool) onListening,
    required void Function(String) onError,
  }) async {
    if (_closed) return;
    await stopSpeaking();
    final epoch = ++_epoch;
    final available = await _speech.initialize(
      options: [SpeechToText.androidNoBluetooth],
      onStatus: (status) {
        if (!_closed) onListening(status == 'listening');
      },
      onError: (_) {
        if (!_closed) {
          onListening(false);
          onError(
            'No se pudo reconocer la voz. Revisa el permiso de micrófono y el servicio de voz del teléfono.',
          );
        }
      },
    );
    if (_closed || epoch != _epoch) return;
    if (!available) {
      if (!_closed) {
        onError(
          'El reconocimiento de voz no está disponible o no tiene permiso de micrófono.',
        );
      }
      return;
    }
    final locales = await _speech.locales();
    if (_closed || epoch != _epoch) return;
    final spanish = locales
        .where(
          (e) => e.localeId.toLowerCase().replaceAll('_', '-').startsWith('es'),
        )
        .toList();
    if (spanish.isEmpty) {
      onError(
        'Instala o habilita el reconocimiento de español en el teléfono.',
      );
      return;
    }
    final locale = spanish.firstWhere(
      (e) => e.localeId.toLowerCase().replaceAll('_', '-') == 'es-mx',
      orElse: () => spanish.first,
    );
    if (_closed || epoch != _epoch) return;
    await _speech.listen(
      onResult: (result) {
        if (!_closed) onText(result.recognizedWords);
      },
      listenOptions: SpeechListenOptions(
        localeId: locale.localeId,
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        listenFor: const Duration(seconds: 40),
        pauseFor: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> speak(String text) async {
    if (_closed) return;
    await stopListening();
    final epoch = _epoch;
    if (!_ready) {
      final languages = await _tts.getLanguages;
      final list = (languages as List)
          .map((e) => e.toString())
          .where((e) => e.toLowerCase().startsWith('es'))
          .toList();
      if (list.isEmpty) {
        throw StateError(
          'Instala una voz en español en los ajustes de texto a voz del teléfono.',
        );
      }
      final language = list.firstWhere(
        (e) => e.toLowerCase().replaceAll('_', '-') == 'es-mx',
        orElse: () => list.first,
      );
      await _tts.setLanguage(language);
      await _tts.setSpeechRate(0.45);
      _ready = true;
    }
    if (_closed || epoch != _epoch) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stopListening() async {
    _epoch++;
    try {
      await _speech.cancel();
    } catch (_) {}
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> stop() async {
    await stopListening();
    await stopSpeaking();
  }

  void dispose() {
    _closed = true;
    stop();
  }
}
