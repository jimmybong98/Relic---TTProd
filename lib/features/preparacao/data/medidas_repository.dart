// lib/features/preparacao/data/medidas_repository.dart
import 'models.dart';

abstract class MedidasRepository {
  /// Busca medidas para um partnumber + operação.
  Future<List<MedidaItem>> getMedidas({
    required String partnumber,
    required String operacao,
  });

  /// Envia o resultado preenchido pelo preparador.
  Future<void> enviarResultado(PreparacaoResultado resultado);
}
