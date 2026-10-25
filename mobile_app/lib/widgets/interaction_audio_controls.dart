import 'package:flutter/material.dart';

import '../services/interaction_audio.dart';

class SoundToggleButton extends StatefulWidget {
  const SoundToggleButton({super.key, this.color});
  final Color? color;
  @override
  State<SoundToggleButton> createState() => _SoundToggleButtonState();
}

class _SoundToggleButtonState extends State<SoundToggleButton> {
  @override
  void initState() {
    super.initState();
    InteractionAudio.instance.initialize();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: InteractionAudio.instance,
    builder: (context, _) {
      final audio = InteractionAudio.instance;
      return IconButton(
        tooltip: !audio.available
            ? '交互音效暂不可用'
            : audio.enabled
            ? '关闭交互音效'
            : '开启交互音效',
        color: widget.color,
        isSelected: audio.enabled,
        icon: const Icon(Icons.volume_off_outlined),
        selectedIcon: const Icon(Icons.volume_up_outlined),
        onPressed: !audio.available || audio.changing
            ? null
            : () async {
                await audio.setEnabled(!audio.enabled);
                if (audio.enabled) audio.play(SoundCue.select);
              },
      );
    },
  );
}

/// Navigation sounds describe user transitions, never scrolling or loading.
class InteractionSoundObserver extends NavigatorObserver {
  bool _audible(Route<dynamic> route) =>
      route is PageRoute ||
      route is ModalBottomSheetRoute ||
      route is DialogRoute;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null && _audible(route)) {
      InteractionAudio.instance.play(SoundCue.transition);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null && _audible(route)) {
      InteractionAudio.instance.play(SoundCue.transition);
    }
  }
}
