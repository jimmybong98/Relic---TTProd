// lib/features/preparacao/data/repository_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_medidas_repository.dart';
import 'medidas_repository.dart';

final medidasRepositoryProvider = Provider<MedidasRepository>((ref) {
  return ApiMedidasRepository();
});
