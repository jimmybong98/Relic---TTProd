// lib/features/preparacao/data/models.dart
import 'dart:convert';

enum StatusMedida { ok, alerta, reprovada, pendente }

StatusMedida statusFromString(String? s) {
  switch (s?.toLowerCase()) {
    case 'ok':
      return StatusMedida.ok;
    case 'alerta':
      return StatusMedida.alerta;
    case 'reprovada':
      return StatusMedida.reprovada;
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
    case StatusMedida.reprovada:
      return 'reprovada';
    case StatusMedida.pendente:
    default:
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

  MedidaItem({
    required this.titulo,
    this.faixaTexto = '',
    this.minimo,
    this.maximo,
    this.unidade,
    this.status = StatusMedida.pendente,
    this.medicao,
    this.observacao,
  });

  factory MedidaItem.fromMap(Map<String, dynamic> map) {
    double? _toDouble(v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      final s = v.toString().replaceAll(',', '.').trim();
      return double.tryParse(s);
    }

    return MedidaItem(
      titulo: (map['titulo'] ?? '').toString(),
      faixaTexto: (map['faixaTexto'] ?? map['faixa_texto'] ?? '').toString(),
      minimo: _toDouble(map['minimo'] ?? map['min']),
      maximo: _toDouble(map['maximo'] ?? map['max']),
      unidade: map['unidade']?.toString(),
      status: statusFromString(map['status']?.toString()),
      medicao: map['medicao']?.toString(),
      observacao: map['observacao']?.toString(),
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
