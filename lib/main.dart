// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart'; // lib/app.dart

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carrega variáveis de ambiente do arquivo .env, ignorando se ausente
  try {
    await dotenv.load();
  } catch (_) {
    // Se não houver arquivo .env, seguimos com valores padrão
  }

  // Inicializa Hive (desktop/mobile/web via hive_flutter)
  await Hive.initFlutter();

  // Abra as boxes que o app usa ANTES do runApp
  await Future.wait([
    Hive.openBox('config'),
    Hive.openBox('medidas'),
  ]);

  // Sobe o app (MaterialApp está em lib/app.dart)
  runApp(const ProviderScope(child: App()));
}
