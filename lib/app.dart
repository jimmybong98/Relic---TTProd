import 'package:flutter/material.dart';
import 'features/main_menu/main_menu_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Relic TT Prod',
      debugShowCheckedModeBanner: false,
      home: const MainMenuPage(), // Menu principal com áreas
    );
  }
}
