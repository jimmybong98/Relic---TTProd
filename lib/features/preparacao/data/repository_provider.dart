import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../preparacao/data/medidas_repository.dart';
import '../../preparacao/data/medidas_repository_factory.dart';

/// Provider para as rotas do OPERADOR
final operadorRepositoryProvider = Provider<MedidasRepository>((ref) {
  return MedidasRepositoryFactory.create(
    useApi: true,
    medidasPath: '/operador/medidas',
    resultadoPath: '/operador/resultado',
  );
});

/// NEW: Provider para as rotas do PREPARADOR
final preparadorRepositoryProvider = Provider<MedidasRepository>((ref) {
  return MedidasRepositoryFactory.create(
    useApi: true,
    medidasPath: '/preparador/medidas',
    resultadoPath: '/preparador/resultado', // já existe no backend (retorna ok)
  );
});