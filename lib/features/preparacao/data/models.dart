// lib/features/preparacao/data/models.dart
import 'dart:convert';

enum StatusMedida { ok, alerta, reprovadaAcima, reprovadaAbaixo, pendente }

StatusMedida statusFromString(String? s) {
  switch (s?.toLowerCase()) {
    case 'ok':
      return StatusMedida.ok;
    case 'alerta':
      return StatusMedida.alerta;
    case 'reprovada_acima':
    case 'acima':
    case 'reprovada':
      return StatusMedida.reprovadaAcima;
    case 'reprovada_abaixo':
    case 'abaixo':
      return StatusMedida.reprovadaAbaixo;
    default:
      return StatusMedida.pendente;
  }
}

String statusToString(StatusMedida s) {
  switch (s) {
    case StatusMedida.ok:
      return 'ok';
    case StatusMedida.alerta:
      return 'alerta';
    case StatusMedida.reprovadaAcima:
      return 'reprovada_acima';
    case StatusMedida.reprovadaAbaixo:
      return 'reprovada_abaixo';
    case StatusMedida.pendente:
      return 'pendente';
  }
}

class MedidaItem {
  final String titulo;
  /// Texto amigável da faixa (ex.: "10.00 ~ 12.00 mm").
  final String faixaTexto;
  /// Limite mínimo aceito (opcional).
  final double? minimo;
  /// Limite máximo aceito (opcional).
  final double? maximo;
  /// Unidade de medida (ex.: "mm", "°", etc).
  final String? unidade;

  final StatusMedida status;
  final String? medicao;
  final String? observacao;
  final String? periodicidade;
  final String? instrumento;

  MedidaItem({
    required this.titulo,
    this.faixaTexto = '',
    this.minimo,
    this.maximo,
    this.unidade,
    this.status = StatusMedida.pendente,
    this.medicao,
    this.observacao,
    this.periodicidade,
    this.instrumento,
  });

  factory MedidaItem.fromMap(Map<String, dynamic> map) {
    double? parseToDouble(v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      final s = v.toString().replaceAll(',', '.').trim();
      return double.tryParse(s);
    }

    final faixa = (map['faixaTexto'] ?? map['faixa_texto'] ?? '').toString();
    double? minimo = parseToDouble(map['minimo'] ?? map['min']);
    double? maximo = parseToDouble(map['maximo'] ?? map['max']);

    if ((minimo == null || maximo == null) && faixa.isNotEmpty) {
      final matches = RegExp(r'-?\d+(?:[.,]\d+)?')
          .allMatches(faixa)
          .map((m) => double.tryParse(m.group(0)!.replaceAll(',', '.')))
          .whereType<double>()
          .toList();
      minimo ??= matches.isNotEmpty ? matches.first : null;
      maximo ??= matches.length > 1 ? matches[1] : null;
    }

    return MedidaItem(
      titulo: (map['titulo'] ?? '').toString(),
      faixaTexto: faixa,
      minimo: minimo,
      maximo: maximo,
      unidade: map['unidade']?.toString(),
      status: statusFromString(map['status']?.toString()),
      medicao: map['medicao']?.toString(),
      observacao: map['observacao']?.toString(),
      periodicidade: map['periodicidade']?.toString(),
      instrumento: map['instrumento']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'titulo': titulo,
    'faixaTexto': faixaTexto,
    'minimo': minimo,
    'maximo': maximo,
    'unidade': unidade,
    'status': statusToString(status),
    'medicao': medicao,
    'observacao': observacao,
    'periodicidade': periodicidade,
    'instrumento': instrumento,
  };
}

class PreparacaoResultado {
  final String re;
  final String partnumber;
  final String operacao;
  final List<MedidaItem> medidas;

  PreparacaoResultado({
    required this.re,
    required this.partnumber,
    required this.operacao,
    required this.medidas,
  });

  Map<String, dynamic> toMap() => {
    're': re,
    'partnumber': partnumber,
    'operacao': operacao,
    'medidas': medidas.map((e) => e.toMap()).toList(),
  };

  String toJson() => jsonEncode(toMap());
}
