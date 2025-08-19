import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'local_excel_repository.dart';
import 'medidas_repository.dart';
import 'api_medidas_repository.dart';
import 'fallback_medidas_repository.dart';

class MedidasRepositoryFactory {
  static MedidasRepository create() {
    // Usa IP fixo como padrão para testes locais
    final baseUrl =
        dotenv.maybeGet('API_BASE_URL') ?? 'http://192.168.0.241:5005';
    final api = ApiMedidasRepository(overrideBaseUrl: baseUrl);
    if (Platform.isWindows) {
      // Caminho UNC do arquivo na rede
      // Usa duas strings raw adjacentes para evitar quebras de linha
      const planilhaPath =
          r'\\192.168.0.82\00. SGI - Sistema Integrado\12. Qualidade\09. Formulários\For - 007 - Registro de amostragem e '
          r'For - 008 - Liberação de Maquina 4.xlsx';
      final local =
          LocalExcelRepository(planilhaPath: planilhaPath, aba: 'CADASTRO');
      return FallbackMedidasRepository(local: local, api: api);
    }
    // Android (ou outros): usa API HTTP diretamente
    return api;
  }
}
