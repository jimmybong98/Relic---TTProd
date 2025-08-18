// lib/features/preparacao/data/local_excel_repository.dart
import 'dart:io';
import 'package:excel/excel.dart';

import 'medidas_repository.dart';
import 'models.dart';

/// Leitura direta da planilha .xlsx via caminho (UNC/local).
/// Uso recomendado apenas no Windows (acesso à rede).
class LocalExcelRepository implements MedidasRepository {
  final String planilhaPath;
  final String aba;

  const LocalExcelRepository({
    required this.planilhaPath,
    required this.aba,
  });

  @override
  Future<List<MedidaItem>> getMedidas({
    required String partnumber,
    required String operacao,
  }) async {
    final chave = '${partnumber.trim()}*${operacao.trim()}';

    final file = File(planilhaPath);
    if (!await file.exists()) {
      throw Exception('Planilha não encontrada: $planilhaPath');
    }

    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[aba];
    if (sheet == null) {
      throw Exception('Aba "$aba" não encontrada na planilha.');
    }

    // Procura linha cuja COLUNA C (índice 2) == chave exata
    for (final row in sheet.rows) {
      final cVal = _cellText(row, 2); // C = índice 2 (0-based)
      if (cVal == chave) {
        final itens = <MedidaItem>[];
        int col = 6; // G (0-based)
        while (true) {
          final etiqueta = _cellText(row, col);       // G, I, K, ...
          final especific = _cellText(row, col + 1);  // H, J, L, ...
          if (etiqueta.isEmpty && especific.isEmpty) break;

          // Apenas exibir (escopo atual). Tenta extrair min/max/unidade se vier no padrão.
          final parsed = _tryParseRange(especific);

          itens.add(MedidaItem(
            titulo: etiqueta,
            faixaTexto: especific,
            minimo: parsed.$1,
            maximo: parsed.$2,
            unidade: parsed.$3,
            status: StatusMedida.pendente,
          ));

          col += 2;
        }
        return itens;
      }
    }

    // Não encontrou a chave
    return const <MedidaItem>[];
  }

  @override
  Future<void> enviarResultado(PreparacaoResultado resultado) async {
    // Por enquanto, não persiste em planilha local.
    // Mantemos a assinatura para cumprir o contrato.
    // Você pode trocar por escrita em CSV/Excel futuramente.
    return;
  }

  // ---------- helpers ----------

  String _cellText(List<Data?> row, int index) {
    if (index < 0 || index >= row.length) return '';
    final d = row[index];
    if (d == null) return '';
    final v = d.value;
    if (v == null) return '';
    return v.toString().trim();
  }

  /// Tenta extrair (min, max, unidade) de uma faixa tipo "4.05-4.20", "10,0 – 10,5 mm".
  /// Retorna (double? min, double? max, String? unidade)
  (double?, double?, String?) _tryParseRange(String faixa) {
    if (faixa.isEmpty) return (null, null, null);
    final re = RegExp(
      r'^\s*([+-]?\d+(?:[.,]\d+)?)\s*[-–]\s*([+-]?\d+(?:[.,]\d+)?)(?:\s*([a-zA-Z%º°]+))?\s*$',
    );
    final m = re.firstMatch(faixa);
    if (m == null) return (null, null, null);

    double? toDouble(String s) => double.tryParse(s.replaceAll(',', '.'));

    final minStr = m.group(1) ?? '';
    final maxStr = m.group(2) ?? '';
    final uni = m.group(3);

    return (toDouble(minStr), toDouble(maxStr), uni);
  }
}
