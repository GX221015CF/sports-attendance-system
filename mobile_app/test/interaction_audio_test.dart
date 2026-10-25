import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/interaction_audio.dart';
import 'package:mobile_app/widgets/attendance_motion.dart';
import 'package:mobile_app/widgets/interaction_audio_controls.dart';

import 'attendance_motion_test.dart' as motion;
import 'attendance_workspace_test.dart' as signing;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('duiqi/interaction_audio');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final cues = <String>[];
  bool enabled = true;
  bool playbackFails = false;

  setUp(() async {
    cues.clear();
    playbackFails = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getEnabled') return enabled;
      if (call.method == 'setEnabled') return enabled = call.arguments as bool;
      if (call.method == 'play') {
        cues.add(call.arguments as String);
        if (playbackFails) throw PlatformException(code: 'no_output');
        return true;
      }
      return null;
    });
    await InteractionAudio.instance.initialize();
    await InteractionAudio.instance.setEnabled(true);
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('restores muted preference and coalesces preload requests', () async {
    const testChannel = MethodChannel('duiqi/test_audio');
    var reads = 0;
    final played = <String>[];
    messenger.setMockMethodCallHandler(testChannel, (call) async {
      if (call.method == 'getEnabled') {
        reads++;
        return false;
      }
      if (call.method == 'setEnabled') return call.arguments;
      if (call.method == 'play') played.add(call.arguments as String);
      return true;
    });
    final audio = InteractionAudio(channel: testChannel);
    await Future.wait([audio.initialize(), audio.initialize()]);
    expect(reads, 1);
    expect(audio.enabled, isFalse);
    audio.play(SoundCue.success);
    await Future<void>.delayed(Duration.zero);
    expect(played, isEmpty);
    await audio.setEnabled(true);
    audio.play(SoundCue.select);
    await Future<void>.delayed(Duration.zero);
    expect(played, ['select']);
    audio.dispose();
    messenger.setMockMethodCallHandler(testChannel, null);
  });

  test('missing native player fails silently without queued sounds', () async {
    const missing = MethodChannel('duiqi/missing_audio');
    final audio = InteractionAudio(channel: missing);
    audio.play(SoundCue.success);
    await audio.initialize();
    expect(audio.available, isFalse);
    audio.play(SoundCue.failure);
    await Future<void>.delayed(Duration.zero);
    audio.dispose();
  });

  for (final local in [false, true]) {
    testWidgets(
      '${local ? 'offline' : 'online'} success sound waits for persistence and plays once',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1180, 820));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final probe = motion.SaveProbe()..pending = Completer<void>();
        await tester.pumpWidget(
          motion.motionApp(
            signing.signingPage(
              local,
              cloud: motion.MotionCloud(probe),
              device: motion.MotionLocal(probe),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(cues, isEmpty);
        await tester.tap(find.widgetWithText(ElevatedButton, '签到').first);
        await tester.pump();
        expect(cues, ['tap']);
        probe.pending!.complete();
        await tester.pumpAndSettle();
        expect(cues.where((c) => c == 'checkinSuccess').length, 1);
        expect(cues, isNot(contains('success')));
        await tester.pump(const Duration(seconds: 2));
        expect(cues.where((c) => c == 'checkinSuccess').length, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'generic form success remains independent from check-in sound',
    () async {
      InteractionAudio.instance.play(SoundCue.success);
      await Future<void>.delayed(Duration.zero);
      expect(cues, ['success']);
    },
  );

  testWidgets('failure plays no success and muted retry remains silent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1180, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final probe = motion.SaveProbe()..fail = true;
    await tester.pumpWidget(
      motion.motionApp(
        signing.signingPage(false, cloud: motion.MotionCloud(probe)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '签到').first);
    await tester.pumpAndSettle();
    expect(cues, ['tap', 'failure']);
    await InteractionAudio.instance.setEnabled(false);
    cues.clear();
    probe.fail = false;
    await tester.tap(find.widgetWithText(ElevatedButton, '签到').first);
    await tester.pumpAndSettle();
    expect(cues, isEmpty);
    expect(probe.saved.length, 1);
  });

  testWidgets(
    'audio output failure does not turn a committed save into failure',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1180, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      playbackFails = true;
      final probe = motion.SaveProbe();
      await tester.pumpWidget(
        motion.motionApp(
          signing.signingPage(false, cloud: motion.MotionCloud(probe)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, '签到').first);
      await tester.pumpAndSettle();
      expect(probe.saved.length, 1);
      expect(
        tester.widget<CheckinFeedback>(find.byType(CheckinFeedback)).sequence,
        1,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('refresh, skeleton animation and count changes are silent', (
    tester,
  ) async {
    await tester.pumpWidget(
      motion.motionApp(const Scaffold(body: LoadingSkeleton())),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(cues, isEmpty);
    await tester.pumpWidget(
      motion.motionApp(const Scaffold(body: RollingCount(value: 1))),
    );
    await tester.pumpWidget(
      motion.motionApp(const Scaffold(body: RollingCount(value: 2))),
    );
    await tester.pumpAndSettle();
    expect(cues, isEmpty);
  });

  testWidgets('initial page stays silent, user navigation plays transition', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [InteractionSoundObserver()],
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('下一页')),
                ),
              ),
              child: const Text('进入'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(cues, isEmpty);
    await tester.tap(find.text('进入'));
    await tester.pumpAndSettle();
    expect(cues, ['transition']);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(cues, ['transition', 'transition']);
  });

  testWidgets(
    'sound switch persists disable and enable independently of animations',
    (tester) async {
      await tester.pumpWidget(
        motion.motionApp(
          const Scaffold(body: SoundToggleButton()),
          reduced: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('关闭交互音效'));
      await tester.pumpAndSettle();
      expect(enabled, isFalse);
      expect(cues, isEmpty);
      await tester.tap(find.byTooltip('开启交互音效'));
      await tester.pumpAndSettle();
      expect(enabled, isTrue);
      expect(cues, ['select']);
    },
  );
}
