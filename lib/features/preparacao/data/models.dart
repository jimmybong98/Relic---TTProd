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
      return 'OK';
    case StatusMedida.alerta:
      return 'ALERTA';
    case StatusMedida.reprovada:
      return 'REPROVADA';
    case StatusMedida.pendente:
      return 'PENDENTE';
  }
}

class MedidaItem {
  final String titulo;      // ex.: "DIÂMETRO"
  final String faixaTexto;  // ex.: "4.05–4.20"
  final double? minimo;     // 4.05
  final double? maximo;     // 4.20
  final String? unidade;    // ex.: "mm"
  StatusMedida status;      // marcado pelo preparador
  final String? observacao; // opcional

  MedidaItem({
    required this.titulo,
    required this.faixaTexto,
    this.minimo,
    this.maximo,
    this.unidade,
    this.status = StatusMedida.pendente,
    this.observacao,
  });

  factory MedidaItem.fromMap(Map<String, dynamic> map) {
    return MedidaItem(
      titulo: (map['titulo'] ?? map['label'] ?? map['g'] ?? '').toString(),
      faixaTexto: (map['faixa'] ?? map['range'] ?? map['h'] ?? '').toString(),
      minimo: _toDoubleOrNull(map['min'] ?? map['minimo']),
      maximo: _toDoubleOrNull(map['max'] ?? map['maximo']),
      unidade: map['unidade']?.toString(),
      status: statusFromString(map['status']?.toString()),
      observacao: map['observacao']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'titulo': titulo,
    'faixa': faixaTexto,
    'min': minimo,
        'max': maximo,
    'unidade': unidade,
    'status': statusToString(status),
    'observacao': observacao,
  };

  static double? _toDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll(',', '.');
    return double.tryParse(s);
  }
}

class PreparacaoFiltro {
  final String re;          // RE do preparador
  final String partnumber;  // código da peça
  final String operacao;    // ex.: "010"

  PreparacaoFiltro({
    required this.re,
    required this.partnumber,
    required this.operacao,
  });

  String get chaveCadastro => '$partnumber*$operacao';
}

class ResultadoItem {
  final String titulo;
  final StatusMedida status;
  final String? medicao;    // valor medido digitado (opcional)
  final String? observacao;

  ResultadoItem({
    required this.titulo,
    required this.status,
    this.medicao,
    this.observacao,
  });

  Map<String, dynamic> toMap() => {
    'titulo': titulo,
    'status': statusToString(status),
    'medicao': medicao,
    'observacao': observacao,
  };
}

class PreparacaoResultado {
  final String re;
