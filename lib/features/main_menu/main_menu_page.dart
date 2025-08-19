import 'package:flutter/material.dart';

import '../preparacao/presentation/preparacao_page.dart';
import '../operador/presentation/operador_page.dart';

class MainMenuPage extends StatelessWidget {
  const MainMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menu Principal')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PreparacaoPage(),
                  ),
                );
              },
              child: const Text('Área do Preparador'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const OperadorPage(),
                  ),
                );
              },
              child: const Text('Área do Operador'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const _SupervisaoPage(),
                  ),
                );
              },
              child: const Text('Supervisão'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupervisaoPage extends StatelessWidget {
  const _SupervisaoPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Supervisão')),
      body: const Center(child: Text('Em desenvolvimento')),
    );
  }
}
