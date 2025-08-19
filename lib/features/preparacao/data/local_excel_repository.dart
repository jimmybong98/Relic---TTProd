import 'dart:io';
import 'package:excel/excel.dart';
import 'models.dart';
import 'medidas_repository.dart';

class LocalExcelRepository implements MedidasRepository {
  final String planilhaPath;
  final String aba;
  const LocalExcelRepository({required this.planilhaPath, required this.aba});

  @override
  Future<List<MedidaItem>> getMedidas({
    required String partnumber,
    required String operacao,
  }) async {
    final key = '${partnumber.trim()}*${operacao.trim()}';
    final bytes = await File(planilhaPath).readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[aba];
    if (sheet == null) {
      throw Exception('Aba "$aba" não encontrada na planilha.');
    }

    // Procurar a linha onde a coluna C (índice 2) == key
    for (final row in sheet.rows) {
      final cellC = _cellText(row, 2);
      if (cellC == key) {
        // A partir da coluna G (índice 6), ler pares (etiqueta, especificação)
        final medidas = <MedidaItem>[];
        int col = 6; // G
        while (true) {
          final etiqueta = _cellText(row, col);
          final especificacao = _cellText(row, col + 1);
          final ambosVazios = (etiqueta.isEmpty && especificacao.isEmpty);
          if (ambosVazios) break; // chegou ao fim

          if (etiqueta.isNotEmpty || especificacao.isNotEmpty) {
            medidas.add(
              MedidaItem(
                titulo: etiqueta,
                faixaTexto: especificacao,
              ),
            );
          }
          col += 2; // próximo par (I/J, K/L, ...)
        }
        return medidas;
      }
    }
    // Se não achar, retorna vazio para o app tratar
    return <MedidaItem>[];
  }

  String _cellText(List<Data?> row, int index) {
    if (index < 0 || index >= row.length) return '';
    final d = row[index];
    if (d == null) return '';
    final v = d.value;
    if (v == null) return '';
    return v.toString().trim();
  }

  @override
  Future<void> enviarResultado(PreparacaoResultado resultado) async {
    // Repositório Excel é somente leitura; resultados não são persistidos localmente.
  }