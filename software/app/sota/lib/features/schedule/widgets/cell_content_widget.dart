import 'package:flutter/material.dart';
import 'package:sota/data/models/medication_entry.dart';

class CellContentWidget extends StatelessWidget {
  final int cellId;
  final List<MedicationEntry> entries;

  const CellContentWidget({
    super.key,
    required this.cellId,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey('cell_$cellId'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Ячейка $cellId',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        if (entries.isEmpty)
          const Text(
            'Нет данных',
            textAlign: TextAlign.center,
          )
        else
          ...entries.map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '${entry.title} — ${entry.quantity} шт\n${entry.times.join(', ')}\n${entry.days.join(', ')}',
                  textAlign: TextAlign.center,
                ),
              )),
      ],
    );
  }
}
