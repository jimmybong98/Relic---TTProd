import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// IMPORTS ALINHADOS COM A ESTRUTURA QUE TE PASSEI
import '../data/models.dart';
import '../data/repository_provider.dart';

/// Provider do controller (Riverpod)
final medidasControllerProvider = StateNotifierProvider.autoDispose<
    MedidasController, AsyncValue<List<MedidaItem>>>((ref) {
  return MedidasController(ref);
});

class MedidasController extends StateNotifier<AsyncValue<List<MedidaItem>>> {
  final Ref _ref;
  MedidasController(this._ref) : super(const AsyncValue.data([]));

  Future<void> carregar({
    required String partnumber,
    required String operacao,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(medidasRepositoryProvider);
      final itens =
      await repo.getMedidas(partnumber: partnumber, operacao: operacao);
      state = AsyncValue.data(itens);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void setMedicao(int index, String medicao) {
    final current = [...(state.value ?? const <MedidaItem>[])];
    if (index < 0 || index >= current.length) return;

    final item = current[index];
    double? valor;
    try {
      valor = double.parse(medicao.replaceAll(',', '.'));
    } catch (_) {
      valor = null;
    }

    StatusMedida status = StatusMedida.pendente;
    if (valor != null) {
      final minimo = item.minimo;
      final maximo = item.maximo;
      if ((minimo != null && valor < minimo) ||
          (maximo != null && valor > maximo)) {
        status = StatusMedida.reprovada;
      } else {
        status = StatusMedida.ok;
      }
    }

    current[index] = MedidaItem(
      titulo: item.titulo,
      faixaTexto: item.faixaTexto,
      minimo: item.minimo,
      maximo: item.maximo,
      unidade: item.unidade,
      status: status,
      medicao: medicao,
      observacao: item.observacao,
      periodicidade: item.periodicidade,
      instrumento: item.instrumento,
    );
    state = AsyncValue.data(current);
  }
}

class PreparacaoPage extends ConsumerStatefulWidget {
  const PreparacaoPage({super.key});

  @override
  ConsumerState<PreparacaoPage> createState() => _PreparacaoPageState();
}

class _PreparacaoPageState extends ConsumerState<PreparacaoPage> {
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

  Future<void> _liberarMaquina() async {
    final medidas = ref.read(medidasControllerProvider).value ?? [];
    final resultado = PreparacaoResultado(
      re: _reCtrl.text.trim(),
      partnumber: _partCtrl.text.trim(),
      operacao: _opCtrl.text.trim(),
      medidas: medidas,
    );
    try {
      final repo = ref.read(medidasRepositoryProvider);
      await repo.enviarResultado(resultado);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Máquina liberada com sucesso')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao liberar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final medidasAsync = ref.watch(medidasControllerProvider);
    final medidas = medidasAsync.value ?? [];
    final todasOk =
        medidas.isNotEmpty && medidas.every((m) => m.status == StatusMedida.ok);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preparação de OS'),
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
                        labelText: 'RE do Preparador',
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
                                .read(medidasControllerProvider.notifier)
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
                          item: item,
                          onChanged: (valor) => ref
                              .read(medidasControllerProvider.notifier)
                              .setMedicao(index, valor),
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: todasOk ? _liberarMaquina : null,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Liberar máquina'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget interno para exibir cada medida + seleção de status
class _MeasurementTile extends StatelessWidget {
  final MedidaItem item;
  final void Function(String) onChanged;

  const _MeasurementTile({
    required this.item,
    required this.onChanged,
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
            Text(item.titulo.isEmpty ? '(sem título)' : item.titulo, style: styleLabel),
            const SizedBox(height: 4),
            Text(subtitulo.isEmpty ? '(sem faixa)' : subtitulo, style: styleSpec),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: item.medicao ?? '',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Medição',
                filled: true,
                fillColor: item.status == StatusMedida.ok
                    ? Colors.green.shade100
                    : item.status == StatusMedida.reprovada
                        ? Theme.of(context).colorScheme.errorContainer
                        : null,
              ),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
