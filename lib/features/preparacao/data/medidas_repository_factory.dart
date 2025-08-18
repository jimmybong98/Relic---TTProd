import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'local_excel_repository.dart';
import 'medidas_repository.dart';
import 'api_medidas_repository.dart';

class MedidasRepositoryFactory {
  static MedidasRepository create() {
    if (Platform.isWindows) {
      // Caminho UNC do arquivo na rede
      const planilhaPath = r"\\192.168.0.82\00. SGI - Sistema Integrado\12. Qualidade\09. Formulários\For - 007 - Registro de amostragem e For - 008 - Liberação de Maquina 4.xlsx";
      return LocalExcelRepository(planilhaPath: planilhaPath, aba: 'CADASTRO');
    }
    // Android (ou outros): usa API HTTP
    final baseUrl = dotenv.maybeGet('API_BASE_URL') ?? 'http://192.168.0.82:5005';
    return ApiMedidasRepository(overrideBaseUrl: baseUrl);
  }
}