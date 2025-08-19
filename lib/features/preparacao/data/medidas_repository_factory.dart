// lib/features/preparacao/data/medidas_repository_factory.dart
import 'api_medidas_repository.dart';
import 'local_excel_repository.dart';
import 'medidas_repository.dart';

class MedidasRepositoryFactory {
  /// Cria um repositório de medidas.
  ///
  /// Exemplos:
  /// - API:
  ///   MedidasRepositoryFactory.create(useApi: true, baseUrlOverride: 'https://host')
  ///
  /// - Local via JSON:
  ///   MedidasRepositoryFactory.create(useApi: false, assetPath: 'assets/medidas.json')
  ///
  /// - Local via planilha:
  ///   MedidasRepositoryFactory.create(useApi: false, planilhaPath: '/path/arquivo.xlsx', aba: 'CADASTRO')
  static MedidasRepository create({
    required bool useApi,
    String? baseUrlOverride,
    String? assetPath,
    String? planilhaPath,
    String? aba,
  }) {
    if (useApi) {
      return ApiMedidasRepository(overrideBaseUrl: baseUrlOverride);
    }

    if (planilhaPath != null) {
      return LocalExcelRepository(planilhaPath: planilhaPath, aba: aba ?? 'CADASTRO');
    }

    if (assetPath != null) {
      return LocalExcelRepository(assetPath: assetPath);
    }

    // Fallback seguro: tenta JSON padrão de assets.
    return LocalExcelRepository(assetPath: 'assets/medidas.json');
  }
}
