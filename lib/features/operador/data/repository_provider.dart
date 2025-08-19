import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../preparacao/data/medidas_repository.dart';
import '../../preparacao/data/medidas_repository_factory.dart';

final operadorRepositoryProvider = Provider<MedidasRepository>((ref) {
  return MedidasRepositoryFactory.create(
    useApi: true,
    medidasPath: '/operador/medidas',
    resultadoPath: '/operador/resultado',
  );
});
