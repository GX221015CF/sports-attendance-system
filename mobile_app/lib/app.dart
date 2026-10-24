import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'branding/app_brand.dart';
import 'pages/mode_home_page.dart';
import 'theme/app_theme.dart';

class SportsAttendanceApp extends StatelessWidget {
  const SportsAttendanceApp({super.key});

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
      home: const ModeHomePage(),
    );
  }
}
