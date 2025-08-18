import 'package:flutter/material.dart';
import '../../data/models.dart';

class MeasurementTile extends StatelessWidget {
  final MedidaItem item;
  final void Function(StatusMedida) onSelect;
  const MeasurementTile({super.key, required this.item, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final styleLabel = Theme.of(context).textTheme.titleMedium;
    final styleSpec = Theme.of(context).textTheme.bodyMedium;

    return Card(
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.titulo.isEmpty ? '(sem etiqueta)' : item.titulo, style: styleLabel),
            const SizedBox(height: 4),
            Text(item.faixaTexto.isEmpty ? '(sem especificação)' : item.faixaTexto, style: styleSpec),
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
                  label: const Text('Reprovada'),
                  selected: item.status == StatusMedida.reprovada,
                  onSelected: (_) => onSelect(StatusMedida.reprovada),
                  selectedColor: Theme.of(context).colorScheme.errorContainer,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}