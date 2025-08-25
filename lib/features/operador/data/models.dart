// lib/features/preparacao/data/models.dart
import 'dart:convert';

enum StatusMedida { ok, alerta, reprovadaAcima, reprovadaAbaixo, pendente }

StatusMedida statusFromString(String? s) {
  switch ((s ?? '').toLowerCase()) {
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
  // Básicos
  final String titulo;
  /// Texto amigável da faixa (ex.: "10,00 ~ 12,00 mm", "≥ 15,30 mm", "≤ 3,2 µm")
  final String faixaTexto;
  /// Limite mínimo aceito (opcional).
  final double? minimo;
  /// Limite máximo aceito (opcional).
  final double? maximo;
  /// Unidade de medida (ex.: "mm", "°", "µm", etc.).
  final String? unidade;

  // Metadados
  final StatusMedida status;
  /// Mantido como String? para compatibilidade com o restante do app.
  final String? medicao;
  final String? observacao;
  final String? periodicidade;
  final String? instrumento;

  /// Rótulos de tolerância (até 4) vindos do backend do Operador (AE/AF/AG/AH...).
  final List<String> tolerancias;

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
    this.tolerancias = const [],
  });

  /// Avalia um valor numérico contra os limites.
  /// - Se só houver `minimo`, reprova **abaixo** do mínimo.
  /// - Se só houver `maximo`, reprova **acima** do máximo.
  /// - Se houver ambos, valida como faixa **inclusiva** [min..max].
  StatusMedida avaliarStatus(double? valor) {
    if (valor == null) return StatusMedida.pendente;

    if (minimo != null && valor < minimo!) {
      return StatusMedida.reprovadaAbaixo;
    }
    if (maximo != null && valor > maximo!) {
      return StatusMedida.reprovadaAcima;
    }
    return StatusMedida.ok;
  }

  // ---------- Helpers internos de parsing ----------
  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll(',', '.').trim();
    return double.tryParse(s);
  }

  static String _normalizeLower(String s) {
    final rep = {
      'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a',
      'é': 'e', 'ê': 'e',
      'í': 'i',
      'ó': 'o', 'ô': 'o', 'õ': 'o',
      'ú': 'u',
      'ç': 'c',
    };
    var t = s.toLowerCase().trim();
    rep.forEach((a, b) => t = t.replaceAll(a, b));
    return t;
  }

  static bool _isRugosidade(String t) {
    final tl = _normalizeLower(t);
    // qualquer “rug” + (“ra” ou “rz”)
    return tl.contains('rug') && (tl.contains('ra') || tl.contains('rz'));
  }

  static bool _hasMinToken(String t) {
    final tl = _normalizeLower(t);
    return tl.contains('minimo') || RegExp(r'\bmin\b').hasMatch(tl);
  }

  static bool _hasMaxToken(String t) {
    final tl = _normalizeLower(t);
    return tl.contains('maximo') || RegExp(r'\bmax\b').hasMatch(tl);
  }

  static double? _firstNumber(String s) {
    final m = RegExp(r'-?\d+(?:[.,]\d+)?').firstMatch(s);
    return m == null ? null : _toDouble(m.group(0));
  }

  /// Extrai (min,max,unidade) a partir de um texto solto (faixa/valor único).
  /// Coberto:
  ///  - Faixa: "27,50-28,10", "27.50 ~ 28.10", "27,5 a 28,1", "10 a 12 mm"
  ///  - Único valor: retorna (v,v,uni)
  ///  - Com token “minimo” → (v,null,uni)
  ///  - Com token “maximo” → (null,v,uni)
  static ({double? min, double? max, String? uni}) _parseRangeAny(String texto) {
    if (texto.trim().isEmpty) return (min: null, max: null, uni: null);
    final s = texto.trim();

    // Faixa
    final m = RegExp(
      r'(-?\d+(?:[.,]\d+)?)\s*(?:-|–|~|a|ate|até|to)\s*(-?\d+(?:[.,]\d+)?)\s*([^\d\s]+.*)?$',
      caseSensitive: false,
    ).firstMatch(s);
    if (m != null) {
      var v1 = _toDouble(m.group(1));
      var v2 = _toDouble(m.group(2));
      final uni = (m.group(3) ?? '').trim().isEmpty ? null : (m.group(3) ?? '').trim();
      if (v1 != null && v2 != null && v1 > v2) {
        final tmp = v1; v1 = v2; v2 = tmp;
      }
      return (min: v1, max: v2, uni: uni);
    }

    // Único valor (com possíveis tokens de minimo/máximo)
    final v = _firstNumber(s);
    final uniMatch = RegExp(r'[a-zA-Zµ°]+[a-zA-Z0-9/%²³]*$').firstMatch(s);
    final uni = (uniMatch?.group(0) ?? '').trim().isEmpty ? null : uniMatch!.group(0)!.trim();

    if (v == null) return (min: null, max: null, uni: null);

    final hasMin = _hasMinToken(s);
    final hasMax = _hasMaxToken(s);
    if (hasMin && !hasMax) return (min: v, max: null, uni: uni);
    if (hasMax && !hasMin) return (min: null, max: v, uni: uni);

    // Sem tokens → valor exato
    return (min: v, max: v, uni: uni);
  }

  /// Gera um texto amigável para a faixa quando `faixaTexto` veio vazio.
  static String _makeFaixaTexto(double? min, double? max, String? uni) {
    final u = (uni ?? '').isNotEmpty ? ' $uni' : '';
    String fmt(double v) => v.toStringAsFixed(2);
    if (min != null && max != null) {
      if (min == 0 && max > 0) return '≤ ${fmt(max)}$u';
      return '${fmt(min)} – ${fmt(max)}$u';
    }
    if (min != null) return '≥ ${fmt(min)}$u';
    if (max != null) return '≤ ${fmt(max)}$u';
    return '';
  }

  factory MedidaItem.fromMap(Map<String, dynamic> map) {
    // Valores diretos do JSON
    String titulo = (map['titulo'] ?? '').toString();
    String faixa = (map['faixaTexto'] ?? map['faixa_texto'] ?? '').toString();

    double? minimo = _toDouble(map['minimo'] ?? map['min']);
    double? maximo = _toDouble(map['maximo'] ?? map['max']);
    String? uni    = (map['unidade']?.toString().trim().isEmpty ?? true)
        ? null
        : map['unidade']!.toString().trim();

    // Se não veio min/max, tenta extrair da faixa; se ainda não, tenta do título.
    if (minimo == null && maximo == null) {
      final r1 = _parseRangeAny(faixa);
      minimo = r1.min; maximo = r1.max; uni ??= r1.uni;
      if (minimo == null && maximo == null) {
        final r2 = _parseRangeAny(titulo);
        minimo = r2.min; maximo = r2.max; uni ??= r2.uni;
      }
    }

    // Regra especial de Rugosidade: valor único vira 0..valor (OK se <= valor)
    if (_isRugosidade(titulo)) {
      final limite = maximo ?? minimo;
      if (limite != null) {
        minimo = 0.0;
        maximo = limite;
      }
    }

    // Se faixaTexto veio vazio, monta automaticamente a partir de min/max/unidade
    final faixaOut = (faixa.isNotEmpty) ? faixa : _makeFaixaTexto(minimo, maximo, uni);

    // Tolerâncias para Operador (lista de rótulos), se existirem
    final tol = (map['tolerancias'] is List)
        ? (map['tolerancias'] as List).map((e) => e.toString()).toList()
        : const <String>[];

    return MedidaItem(
      titulo: titulo,
      faixaTexto: faixaOut,
      minimo: minimo,
      maximo: maximo,
      unidade: uni,
      status: statusFromString(map['status']?.toString()),
      medicao: map['medicao']?.toString(),
      observacao: map['observacao']?.toString(),
      periodicidade: map['periodicidade']?.toString(),
      instrumento: map['instrumento']?.toString(),
      tolerancias: tol,
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
    'tolerancias': tolerancias,
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
