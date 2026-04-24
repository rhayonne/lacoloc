import 'package:flutter/material.dart';
import 'package:lacoloc_front/presentation/home_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: HomePage(title: 'Home'),
    );
  }
}
