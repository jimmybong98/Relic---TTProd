// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart'; // lib/app.dart

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
