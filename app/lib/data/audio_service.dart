import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

abstract class AudioService {
  Future<void> playJumpBeep();
  Future<void> playFinalBeep();
  Future<void> dispose();
}

/// Plays the bundled synthetic tones (assets/sounds, see tool/generate_sounds.dart).
/// Failures are swallowed: audio must never break the routine.
class AudioplayersAudioService implements AudioService {
  final _jump = AudioPlayer();
  final _final = AudioPlayer();

  @override
  Future<void> playJumpBeep() => _play(_jump, 'sounds/jump_beep.wav');

  @override
  Future<void> playFinalBeep() => _play(_final, 'sounds/final_beep.wav');

  Future<void> _play(AudioPlayer player, String asset) async {
    try {
      await player.stop();
      await player.play(AssetSource(asset), mode: PlayerMode.lowLatency);
    } catch (e) {
      debugPrint('Audio playback failed: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await _jump.dispose();
    await _final.dispose();
  }
}

class NoopAudioService implements AudioService {
  @override
  Future<void> playJumpBeep() async {}
  @override
  Future<void> playFinalBeep() async {}
  @override
  Future<void> dispose() async {}
}
