// lib/features/preparacao/data/local_excel_repository.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'medidas_repository.dart';
import 'models.dart';

/// Repositório local que pode ler:
/// - JSON embarcado via [assetPath]; OU
/// - (placeholder) uma planilha indicada por [planilhaPath] e aba [aba].
///
/// OBS: A leitura de planilha é deixada como TODO (depende do package que você usa
/// para XLS/XLSX/CSV). Por ora, retorna lista vazia para esse modo (mas compila).
class LocalExcelRepository implements MedidasRepository {
  /// Caminho do asset JSON (ex.: 'assets/medidas.json').
  final String? assetPath;

  /// Caminho da planilha local (ex.: '/storage/emulated/0/Download/medidas.xlsx').
  final String? planilhaPath;

  /// Nome da aba da planilha (ex.: 'CADASTRO').
  final String? aba;

  /// Você pode instanciar de duas formas:
  /// - LocalExcelRepository(assetPath: 'assets/medidas.json')
  /// - LocalExcelRepository(planilhaPath: '/caminho/arquivo.xlsx', aba: 'CADASTRO')
  LocalExcelRepository({
    this.assetPath,
    this.planilhaPath,
    this.aba,
  }) : assert(assetPath != null || planilhaPath != null,
  'Informe assetPath OU planilhaPath');

  @override
  Future<List<MedidaItem>> getMedidas({
    required String partnumber,
    required String operacao,
  }) async {
    // Prioriza JSON embarcado se informado.
    if (assetPath != null) {
      final raw = await rootBundle.loadString(assetPath!);
      final data = jsonDecode(raw);

      if (data is! List) return <MedidaItem>[];

      return data.map<MedidaItem>((e) {
        final map = (e as Map).cast<String, dynamic>();

        String faixaTexto = (map['faixaTexto'] ?? '').toString();
        double? min = _toDouble(map['minimo'] ?? map['min']);
        double? max = _toDouble(map['maximo'] ?? map['max']);
        String? unidade = map['unidade']?.toString();

        if (faixaTexto.isEmpty && (min != null || max != null)) {
          final minStr = min?.toStringAsFixed(2) ?? '';
          final maxStr = max?.toStringAsFixed(2) ?? '';
          final uni = (unidade ?? '').isNotEmpty ? ' $unidade' : '';
          if (min != null && max != null) {
            faixaTexto = '$minStr ~ $maxStr$uni';
          } else if (min != null) {
            faixaTexto = '≥ $minStr$uni';
          } else if (max != null) {
            faixaTexto = '≤ $maxStr$uni';
          }
        }

        return MedidaItem(
          titulo: (map['titulo'] ?? '').toString(),
          faixaTexto: faixaTexto,
          minimo: min,
          maximo: max,
          unidade: unidade,
          status: statusFromString(map['status']?.toString()),
          medicao: map['medicao']?.toString(),
          observacao: map['observacao']?.toString(),
        );
      }).toList();
    }

    // TODO: Implementar leitura real de planilha (XLS/XLSX/CSV) usando o pacote escolhido.
    // Ex.: 'excel', 'syncfusion_flutter_xlsio', 'csv', etc.
    if (kDebugMode) {
      // Só pra dar um toque no console durante dev.
      print(
          'LocalExcelRepository: leitura de planilha não implementada ainda. caminho=$planilhaPath aba=$aba');
    }
    return <MedidaItem>[];
  }

  @override
  Future<void> enviarResultado(PreparacaoResultado resultado) async {
    // Local: não envia; apenas simula sucesso.
    await Future<void>.value();
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll(',', '.').trim();
    return double.tryParse(s);
  }
}
