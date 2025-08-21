import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../preparacao/data/models.dart';
import '../data/repository_provider.dart';

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

  void setStatus(int index, StatusMedida status) {
    final current = [...(state.value ?? const <MedidaItem>[])];
    if (index < 0 || index >= current.length) return;
    current[index] = MedidaItem(
      titulo: current[index].titulo,
      faixaTexto: current[index].faixaTexto,
      minimo: current[index].minimo,
      maximo: current[index].maximo,
      unidade: current[index].unidade,
      status: status,
      medicao: current[index].medicao,
      observacao: current[index].observacao,
      periodicidade: current[index].periodicidade,
      instrumento: current[index].instrumento,
    );
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
  final _partCtrl = TextEditingController();
  final _opCtrl = TextEditingController();

  @override
  void dispose() {
    _reCtrl.dispose();
    _partCtrl.dispose();
    _opCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final medidasAsync = ref.watch(medidasOperadorControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Área do Operador'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: Text(
                Platform.isWindows
                    ? 'Windows: leitura direta/API'
                    : 'Android: via API',
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
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
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
                                (v == null || v.trim().isEmpty)
                                    ? 'Obrigatório'
                                    : null,
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
                                (v == null || v.trim().isEmpty)
                                    ? 'Obrigatório'
                                    : null,
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
                                .read(
                                    medidasOperadorControllerProvider.notifier)
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
                        child: Text(
                            'Nenhuma medida encontrada para a chave informada.'),
                      );
                    }
                    return ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = list[index];
                        return _MeasurementTile(
                          item: item,
                          onSelect: (status) => ref
                              .read(medidasOperadorControllerProvider.notifier)
                              .setStatus(index, status),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (e, _) => Center(
                    child: Text('Erro ao carregar:\n${e.toString()}'),
                  ),
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
  final MedidaItem item;
  final void Function(StatusMedida) onSelect;

  const _MeasurementTile({
    required this.item,
    required this.onSelect,
  });

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

    return Card(
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.titulo.isEmpty ? '(sem título)' : item.titulo,
                style: styleLabel),
            const SizedBox(height: 4),
            Text(subtitulo.isEmpty ? '(sem faixa)' : subtitulo,
                style: styleSpec),
            if ((item.periodicidade ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Periodicidade: ${item.periodicidade}', style: styleSpec),
            ],
            if ((item.instrumento ?? '').isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('Instrumento: ${item.instrumento}', style: styleSpec),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('OK'),
                  selected: item.status == StatusMedida.ok,
                  onSelected: (_) => onSelect(StatusMedida.ok),
                ),
                ChoiceChip(
                  label: const Text('Alerta'),
                  selected: item.status == StatusMedida.alerta,
                  onSelected: (_) => onSelect(StatusMedida.alerta),
                ),
                ChoiceChip(
                  label: const Text('Reprovada acima'),
                  selected: item.status == StatusMedida.reprovadaAcima,
                  onSelected: (_) => onSelect(StatusMedida.reprovadaAcima),
                ),
                ChoiceChip(
                  label: const Text('Reprovada abaixo'),
                  selected: item.status == StatusMedida.reprovadaAbaixo,
                  onSelected: (_) => onSelect(StatusMedida.reprovadaAbaixo),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
