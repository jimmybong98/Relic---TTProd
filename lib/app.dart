import 'package:flutter/material.dart';
import 'features/preparacao/presentation/widgets/preparacao_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Relic TT Prod',
      debugShowCheckedModeBanner: false,
      home: const PreparacaoPage(), // <- aqui tá a sua home
    );
  }
}
