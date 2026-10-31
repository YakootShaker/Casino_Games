import 'package:flutter/material.dart';
import 'theme.dart';
import 'router.dart';

class QuizBuzzerApp extends StatelessWidget {
  const QuizBuzzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quiz Buzzer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      onGenerateRoute: onGenerateRoute,
      initialRoute: AppRoutes.home,
    );
  }
}
