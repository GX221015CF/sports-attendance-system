import 'package:flutter/material.dart';

import 'pages/current_session_page.dart';
import 'theme/app_theme.dart';

class SportsAttendanceApp extends StatelessWidget {
  const SportsAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '运动队签到',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const CurrentSessionPage(),
    );
  }
}
