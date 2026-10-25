import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'branding/app_brand.dart';
import 'pages/mode_home_page.dart';
import 'theme/app_theme.dart';
import 'services/interaction_audio.dart';
import 'widgets/interaction_audio_controls.dart';

class SportsAttendanceApp extends StatefulWidget {
  const SportsAttendanceApp({super.key});

  @override
  State<SportsAttendanceApp> createState() => _SportsAttendanceAppState();
}

class _SportsAttendanceAppState extends State<SportsAttendanceApp> {
  final _soundObserver = InteractionSoundObserver();
  @override
  void initState() {
    super.initState();
    InteractionAudio.instance.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppBrand.name,
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      theme: AppTheme.lightTheme,
      navigatorObservers: [_soundObserver],
      home: const ModeHomePage(),
    );
  }
}
