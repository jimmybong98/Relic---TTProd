// lib/features/preparacao/data/repository_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'medidas_repository.dart';
import 'medidas_repository_factory.dart';

final medidasRepositoryProvider = Provider<MedidasRepository>((ref) {
  return MedidasRepositoryFactory.create();
});
