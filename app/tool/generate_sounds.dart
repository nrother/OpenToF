// Generates the bundled synthetic beep sounds (16-bit mono PCM WAV).
// Run: dart run tool/generate_sounds.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const sampleRate = 44100;

/// Renders a sequence of (frequencyHz, durationMs) tones with a short fade in/out
/// per tone to avoid clicks.
Uint8List render(List<(double, int)> tones, {double volume = 0.6}) {
  final samples = <int>[];
  for (final (freq, ms) in tones) {
    final n = sampleRate * ms ~/ 1000;
    final fade = math.min(n ~/ 2, sampleRate ~/ 200); // 5 ms
    for (var i = 0; i < n; i++) {
      var env = 1.0;
      if (i < fade) env = i / fade;
      if (i > n - fade) env = (n - i) / fade;
      final v = math.sin(2 * math.pi * freq * i / sampleRate) * env * volume;
      samples.add((v * 32767).round());
    }
  }
  final dataLen = samples.length * 2;
  final bytes = ByteData(44 + dataLen);
  void str(int off, String s) {
    for (var i = 0; i < s.length; i++) {
      bytes.setUint8(off + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  bytes.setUint32(4, 36 + dataLen, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little); // PCM
  bytes.setUint16(22, 1, Endian.little); // mono
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  str(36, 'data');
  bytes.setUint32(40, dataLen, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    bytes.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  return bytes.buffer.asUint8List();
}

void main() {
  final dir = Directory('assets/sounds')..createSync(recursive: true);
  // Per-jump beep: short 880 Hz tone.
  File('${dir.path}/jump_beep.wav').writeAsBytesSync(render([(880.0, 80)]));
  // Final jump: distinct rising three-tone.
  File('${dir.path}/final_beep.wav')
      .writeAsBytesSync(render([(659.0, 120), (880.0, 120), (1319.0, 300)]));
  stdout.writeln('Wrote assets/sounds/jump_beep.wav and final_beep.wav');
}
