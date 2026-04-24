import 'package:flutter/material.dart';
import 'package:la_coloc/theme.dart';
import 'package:la_coloc/home_page.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ChezSoi - La Coloc',
      theme: AppTheme.lightTheme,
      home: const HomePage(),
    );
  }
}
