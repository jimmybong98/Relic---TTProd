import 'medidas_repository.dart';
import 'api_medidas_repository.dart';
import 'local_excel_repository.dart';
import 'models.dart';

/// Repository that tries to load measures from the local Excel first and
/// falls back to the API when none are found. Results are always sent to the
/// API repository.
class FallbackMedidasRepository implements MedidasRepository {
  final LocalExcelRepository local;
  final ApiMedidasRepository api;

  FallbackMedidasRepository({required this.local, required this.api});

  @override
  Future<List<MedidaItem>> getMedidas({
    required String partnumber,
    required String operacao,
  }) async {
    final localResult = await local
        .getMedidas(
          partnumber: partnumber,
          operacao: operacao,
        )
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () => <MedidaItem>[],
        )
        .catchError((_) => <MedidaItem>[]);

    if (localResult.isNotEmpty) {
      return localResult;
    }

    return api.getMedidas(partnumber: partnumber, operacao: operacao);
  }

  @override
  Future<void> enviarResultado(PreparacaoResultado resultado) {
    // Envios sempre feitos via API
    return api.enviarResultado(resultado);
  }
}
