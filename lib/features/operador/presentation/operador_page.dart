// lib/features/operador/presentation/operador_page.dart
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../preparacao/data/models.dart';
import '../data/repository_provider.dart';

/// >>>>> Ajuste para o endereço/porta do seu Flask <<<<<
const String kBaseUrl = 'http://192.168.0.241:5005';

final medidasOperadorControllerProvider = StateNotifierProvider.autoDispose<
    MedidasOperadorController, AsyncValue<List<MedidaItem>>>((ref) {
  return MedidasOperadorController(ref);
});

class MedidasOperadorController
    extends StateNotifier<AsyncValue<List<MedidaItem>>> {
  final Ref _ref;
  MedidasOperadorController(this._ref) : super(const AsyncValue.data([]));

  Future<void> carregar({
    required String partnumber,
    required String operacao,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(operadorRepositoryProvider);
      final itens =
      await repo.getMedidas(partnumber: partnumber, operacao: operacao);
      state = AsyncValue.data(itens);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Define status e medição (texto) para um índice.
  void setStatusAndMedicao(int index, StatusMedida status, String? medicao) {
    final current = [...(state.value ?? const <MedidaItem>[])];
    if (index < 0 || index >= current.length) return;
    final old = current[index];
    current[index] = MedidaItem(
      titulo: old.titulo,
      faixaTexto: old.faixaTexto,
      minimo: old.minimo,
      maximo: old.maximo,
      unidade: old.unidade,
      status: status,
      medicao: medicao,
      observacao: old.observacao,
      periodicidade: old.periodicidade,
      instrumento: old.instrumento,
      tolerancias: old.tolerancias,
    );
    state = AsyncValue.data(current);
  }

  /// Reseta todas as seleções (status -> pendente, medição -> null)
  void resetSelecoes() {
    final current = [...(state.value ?? const <MedidaItem>[])];
    for (var i = 0; i < current.length; i++) {
      final old = current[i];
      current[i] = MedidaItem(
        titulo: old.titulo,
        faixaTexto: old.faixaTexto,
        minimo: old.minimo,
        maximo: old.maximo,
        unidade: old.unidade,
        status: StatusMedida.pendente,
        medicao: null,
        observacao: old.observacao,
        periodicidade: old.periodicidade,
        instrumento: old.instrumento,
        tolerancias: old.tolerancias,
      );
    }
    state = AsyncValue.data(current);
  }
}

class OperadorPage extends ConsumerStatefulWidget {
  const OperadorPage({super.key});

  @override
  ConsumerState<OperadorPage> createState() => _OperadorPageState();
}

class _OperadorPageState extends ConsumerState<OperadorPage> {
  final _formKey = GlobalKey<FormState>();
  final _reCtrl = TextEditingController();
  final _osCtrl = TextEditingController(); // <<<< O.S.
  final _partCtrl = TextEditingController();
  final _opCtrl = TextEditingController();

  bool _registrando = false;

  @override
  void dispose() {
    _reCtrl.dispose();
    _osCtrl.dispose();
    _partCtrl.dispose();
    _opCtrl.dispose();
    super.dispose();
  }

  Future<void> _registrarAmostragem() async {
    final medidas = ref.read(medidasOperadorControllerProvider).value ?? [];

    // Valida RE/OS
    if (_reCtrl.text.trim().isEmpty || _osCtrl.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha RE e O.S. para registrar.')),
      );
      return;
    }

    // Todas respondidas?
    final faltando = <int>[];
    for (var i = 0; i < medidas.length; i++) {
      final m = medidas[i];
      if (m.status == StatusMedida.pendente ||
          (m.medicao == null || m.medicao!.isEmpty)) {
        faltando.add(i);
      }
    }
    if (faltando.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
            Text('Faltam ${faltando.length} medições para selecionar.')),
      );
      return;
    }

    // Monta itens no formato que o backend espera
    final itens = medidas.map((m) {
      final map = m.toMap();
      // backend espera 'min'/'max' e não 'minimo'/'maximo'
      map['min'] = m.minimo;
      map['max'] = m.maximo;
      // escolha = texto selecionado (OK / Aprovado / Reprovado / pílula etc.)
      map['escolha'] = m.medicao ?? '';
      // status como string
      map['status'] = statusToString(m.status);
      return map;
    }).toList();

    final body = jsonEncode({
      're': _reCtrl.text.trim(),
      'os': _osCtrl.text.trim(),
      'partnumber': _partCtrl.text.trim(),
      'operacao': _opCtrl.text.trim(),
      // >>> chave correta no backend:
      'itens': itens,
    });

    final uri = Uri.parse('$kBaseUrl/operador/registrar');

    setState(() => _registrando = true);
    try {
      final resp = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 25));

      if (!mounted) return;

      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Amostragem registrada com sucesso!')),
        );
        // Limpa seleções, mantém lista
        ref.read(medidasOperadorControllerProvider.notifier).resetSelecoes();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Falha ao registrar: ${resp.statusCode} ${resp.body}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao registrar: $e')),
      );
    } finally {
      if (mounted) setState(() => _registrando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final medidasAsync = ref.watch(medidasOperadorControllerProvider);
    final medidas = medidasAsync.value ?? [];
    final reOk = _reCtrl.text.trim().isNotEmpty;
    final osOk = _osCtrl.text.trim().isNotEmpty;

    // todas respondidas?
    final todasRespondidas = medidas.isNotEmpty &&
        medidas.every((m) =>
        m.status != StatusMedida.pendente && (m.medicao ?? '').isNotEmpty);

    final podeRegistrar = reOk && osOk && todasRespondidas && !_registrando;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Área do Operador'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: Text(
                Platform.isWindows ? 'Windows: leitura direta/API' : 'Android: via API',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _reCtrl,
                      decoration: const InputDecoration(
                        labelText: 'RE do Operador',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _osCtrl,
                      decoration: const InputDecoration(
                        labelText: 'O.S.',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _partCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Código da peça (PartNumber)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 140,
                          child: TextFormField(
                            controller: _opCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Operação',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            FocusScope.of(context).unfocus();
                            await ref
                                .read(medidasOperadorControllerProvider.notifier)
                                .carregar(
                              partnumber: _partCtrl.text.trim(),
                              operacao: _opCtrl.text.trim(),
                            );
                          }
                        },
                        icon: const Icon(Icons.search),
                        label: const Text('Carregar medidas'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: medidasAsync.when(
                  data: (list) {
                    if (list.isEmpty) {
                      return const Center(
                        child: Text('Nenhuma medida encontrada para a chave informada.'),
                      );
                    }
                    return ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = list[index];
                        return _MeasurementTile(
                          index: index,
                          item: item,
                          onSelect: (status, medicao) => ref
                              .read(medidasOperadorControllerProvider.notifier)
                              .setStatusAndMedicao(index, status, medicao),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text('Erro ao carregar:\n${e.toString()}'),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: podeRegistrar ? _registrarAmostragem : null,
                  icon: _registrando
                      ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: const Text('Registrar amostragem'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeasurementTile extends StatelessWidget {
  final int index;
  final MedidaItem item;
  final void Function(StatusMedida status, String? medicao) onSelect;

  const _MeasurementTile({
    required this.index,
    required this.item,
    required this.onSelect,
  });

  // ---------- helpers ----------
  String _norm(String? s) => (s ?? '').trim();
  String _nfd(String s) {
    // normalização simples (sem pacote intl)
    const rep = {
      'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a',
      'é': 'e', 'ê': 'e',
      'í': 'i',
      'ó': 'o', 'ô': 'o', 'õ': 'o',
      'ú': 'u',
      'ç': 'c',
      'Á': 'A', 'À': 'A', 'Ã': 'A', 'Â': 'A',
      'É': 'E', 'Ê': 'E',
      'Í': 'I',
      'Ó': 'O', 'Ô': 'O', 'Õ': 'O',
      'Ú': 'U',
      'Ç': 'C',
    };
    var t = s;
    rep.forEach((k, v) => t = t.replaceAll(k, v));
    return t;
  }

  bool _containsAny(String hay, List<String> needles) {
    final h = _nfd(hay.toLowerCase());
    return needles.any((n) => h.contains(_nfd(n.toLowerCase())));
  }

  bool get _isVisualRugParalelismoOrAfins {
    final t = _norm(item.titulo);
    final inst = _norm(item.instrumento);
    return _containsAny(t, ['visual', 'rug', 'paralelismo', 'anel de rosca passa', 'cqf', 'simetria', 'concentricidade']) ||
        _containsAny(inst, ['visual', 'rug', 'rugosimetro', 'paralelismo', 'anel de rosca passa', 'cqf', 'simetria']);
  }

  bool get _isTampao {
    final t = _norm(item.titulo);
    final inst = _norm(item.instrumento);
    return _containsAny(t, ['tamp', 'tampao', 'tampão', 'tampa']) ||
        _containsAny(inst, ['tamp', 'tampao', 'tampão', 'tampa']);
  }

  double? _toDoubleNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.').trim());
  }

  bool _near(double a, double b) => (a - b).abs() <= 0.005;

  Color _fgOn(Color bg) =>
      ThemeData.estimateBrightnessForColor(bg) == Brightness.dark ? Colors.white : Colors.black87;

  Widget _pill({
    required String text,
    required Color bg,
    required Color border,
    bool selected = false,
    Color? fg,
    VoidCallback? onTap,
  }) {
    final fgColor = fg ?? _fgOn(bg);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? border.withValues(alpha: 0.9) : border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: fgColor,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final styleLabel = Theme.of(context).textTheme.titleMedium;
    final styleSpec = Theme.of(context).textTheme.bodyMedium;

    String subtitulo = item.faixaTexto;
    if (subtitulo.isEmpty && (item.minimo != null || item.maximo != null)) {
      final minStr = item.minimo?.toStringAsFixed(2) ?? '';
      final maxStr = item.maximo?.toStringAsFixed(2) ?? '';
      final uni = (item.unidade ?? '').isNotEmpty ? ' ${item.unidade}' : '';
      if (minStr.isNotEmpty && maxStr.isNotEmpty) {
        subtitulo = '$minStr – $maxStr$uni';
      } else if (minStr.isNotEmpty) {
        subtitulo = '≥ $minStr$uni';
      } else if (maxStr.isNotEmpty) {
        subtitulo = '≤ $maxStr$uni';
      }
    }

    // NÃO usar ?? [] se tolerancias for não-nulo (evita dead_null_aware_expression)
    final tolerancias = item.tolerancias;
    final tolVals = <double>[];
    for (final t in tolerancias) {
      final d = _toDoubleNum(t);
      if (d != null) tolVals.add(d);
    }
    tolVals.sort();

    final minEdge = item.minimo ?? (tolVals.isNotEmpty ? tolVals.first : null);
    final maxEdge = item.maximo ?? (tolVals.isNotEmpty ? tolVals.last : null);

    // ------- UI -------
    return Card(
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.titulo.isEmpty ? '(sem título)' : item.titulo, style: styleLabel),
          if (subtitulo.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitulo, style: styleSpec),
          ],
          if ((item.periodicidade ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Periodicidade: ${item.periodicidade}', style: styleSpec),
          ],
          if ((item.instrumento ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('Instrumento: ${item.instrumento}', style: styleSpec),
          ],
          const SizedBox(height: 10),

          // Modo 1: Visual/Rug/Paralelismo/Anel de rosca passa/CQF/Simetria (binário)
          if (_isVisualRugParalelismoOrAfins) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pill(
                  text: 'Aprovado',
                  bg: Colors.green.shade200,
                  border: Colors.green.shade600,
                  fg: Colors.green.shade900,
                  selected: item.medicao == 'Aprovado',
                  onTap: () => onSelect(StatusMedida.ok, 'Aprovado'),
                ),
                _pill(
                  text: 'Reprovado',
                  bg: Colors.red.shade100,
                  border: Colors.red.shade400,
                  selected: item.medicao == 'Reprovado',
                  onTap: () =>
                      onSelect(StatusMedida.reprovadaAcima, 'Reprovado'),
                ),
              ],
            ),
          ]
          // Modo 2: Tampão (4 botões)
          else if (_isTampao) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pill(
                  text: 'Lado passa — Aprovado',
                  bg: Colors.green.shade200,
                  border: Colors.green.shade600,
                  fg: Colors.green.shade900,
                  selected: item.medicao == 'Lado passa — Aprovado',
                  onTap: () =>
                      onSelect(StatusMedida.ok, 'Lado passa — Aprovado'),
                ),
                _pill(
                  text: 'Lado passa — Reprovado',
                  bg: Colors.red.shade100,
                  border: Colors.red.shade400,
                  selected: item.medicao == 'Lado passa — Reprovado',
                  onTap: () => onSelect(
                      StatusMedida.reprovadaAcima, 'Lado passa — Reprovado'),
                ),
                _pill(
                  text: 'Lado não passa — Aprovado',
                  bg: Colors.green.shade200,
                  border: Colors.green.shade600,
                  fg: Colors.green.shade900,
                  selected: item.medicao == 'Lado não passa — Aprovado',
                  onTap: () => onSelect(
                      StatusMedida.ok, 'Lado não passa — Aprovado'),
                ),
                _pill(
                  text: 'Lado não passa — Reprovado',
                  bg: Colors.red.shade100,
                  border: Colors.red.shade400,
                  selected: item.medicao == 'Lado não passa — Reprovado',
                  onTap: () => onSelect(StatusMedida.reprovadaAcima,
                      'Lado não passa — Reprovado'),
                ),
              ],
            ),
          ]
          // Modo 3: Pílulas de tolerância + OK
          else ...[
              Builder(
                builder: (context) {
                  final chips = <Widget>[];

                  // Monta as 4 pílulas coloridas
                  for (final raw in tolerancias) {
                    final d = _toDoubleNum(raw);
                    // default amarelo
                    Color bg = Colors.amber.shade100;
                    Color bd = Colors.amber.shade400;
                    if (d != null &&
                        ((minEdge != null && _near(d, minEdge)) ||
                            (maxEdge != null && _near(d, maxEdge)))) {
                      bg = Colors.red.shade100; // extremos
                      bd = Colors.red.shade400;
                    }

                    final label = d != null
                        ? d.toStringAsFixed(2)
                        : raw.toString();

                    final selected = item.medicao == label;

                    chips.add(_pill(
                      text: label,
                      bg: bg,
                      border: bd,
                      selected: selected,
                      onTap: () {
                        // Seleciona a tolerância: classifica
                        StatusMedida st = StatusMedida.alerta;
                        if (d != null) {
                          if (minEdge != null && _near(d, minEdge)) {
                            st = StatusMedida.reprovadaAbaixo;
                          } else if (maxEdge != null && _near(d, maxEdge)) {
                            st = StatusMedida.reprovadaAcima;
                          } else {
                            st = StatusMedida.alerta;
                          }
                        }
                        onSelect(st, label);
                      },
                    ));
                  }

                  // Insere OK central
                  final mid = chips.isEmpty ? 0 : (chips.length ~/ 2);
                  chips.insert(
                    mid,
                    _pill(
                      text: 'OK',
                      bg: Colors.green.shade200,
                      border: Colors.green.shade600,
                      fg: Colors.green.shade900,
                      selected: item.medicao == 'OK',
                      onTap: () => onSelect(StatusMedida.ok, 'OK'),
                    ),
                  );

                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: chips,
                  );
                },
              ),
            ],
        ]),
      ),
    );
  }
}
