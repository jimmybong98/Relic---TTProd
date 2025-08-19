import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../preparacao/data/medidas_repository.dart';
import '../../preparacao/data/api_medidas_repository.dart';

final operadorRepositoryProvider = Provider<MedidasRepository>((ref) {
  return ApiMedidasRepository(
    medidasPath: '/operador/medidas',
    resultadoPath: '/operador/resultado',
  );
});
