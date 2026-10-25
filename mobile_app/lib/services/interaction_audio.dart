import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum SoundCue { tap, select, success, checkinSuccess, failure, transition }

/// Optional feedback: audio must never delay or fail a business operation.
class InteractionAudio extends ChangeNotifier {
  InteractionAudio({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('duiqi/interaction_audio');

  static final instance = InteractionAudio();
  final MethodChannel _channel;
  Future<void>? _initialization;
  bool _enabled = true;
  bool _available = false;
  bool _changing = false;
  bool get enabled => _enabled;
  bool get available => _available;
  bool get changing => _changing;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      _enabled = await _channel.invokeMethod<bool>('getEnabled') ?? true;
      _available = true;
    } on MissingPluginException {
      _available = false;
    } on PlatformException {
      _available = false;
    }
    notifyListeners();
  }

  void play(SoundCue cue) {
    if (!_enabled) return;
    if (!_available) {
      // Preload at startup; don't queue a late sound for an old interaction.
      unawaited(initialize());
      return;
    }
    unawaited(_play(cue));
  }

  Future<void> _play(SoundCue cue) async {
    try {
      await _channel.invokeMethod<bool>('play', cue.name);
    } on MissingPluginException {
      // Unsupported platforms still retain the complete visual interaction.
    } on PlatformException {
      // An unavailable output device never turns a saved check-in into failure.
    }
  }

  Future<void> setEnabled(bool value) async {
    if (!_available || _changing || value == _enabled) return;
    final previous = _enabled;
    _enabled = value;
    _changing = true;
    notifyListeners();
    try {
      _enabled =
          await _channel.invokeMethod<bool>('setEnabled', value) ?? value;
    } on MissingPluginException {
      _enabled = previous;
      _available = false;
    } on PlatformException {
      _enabled = previous;
    } finally {
      _changing = false;
      notifyListeners();
    }
  }
}
