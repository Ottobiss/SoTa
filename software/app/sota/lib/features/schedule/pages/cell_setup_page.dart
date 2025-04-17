import 'package:flutter/material.dart';
import 'package:sota/data/models/medication_entry.dart';
import 'package:sota/data/services/database_service.dart';
import 'package:sota/core/notification_service.dart';

class CellSetupPage extends StatefulWidget {
  final int cellNumber;
  final void Function(int, List<MedicationEntry>) onSave;

  const CellSetupPage({
    super.key,
    required this.cellNumber,
    required this.onSave,
  });

  @override
  State<CellSetupPage> createState() => _CellSetupPageState();
}

class _CellSetupPageState extends State<CellSetupPage> {
  final _db = DatabaseService();
  final _entries = <MedicationEntry>[];

  final _title = TextEditingController();
  final _count = TextEditingController();
  final _times = <TimeOfDay>[];
  final _days = <String>{};

  final _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final meds = await _db.loadCellMedications(widget.cellNumber);
    if (!mounted) return;
    setState(() => _entries.addAll(meds));
  }

  void _addTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) setState(() => _times.add(picked));
  }

  void _toggleDay(String d) =>
      setState(() => _days.contains(d) ? _days.remove(d) : _days.add(d));

  void _addEntry() {
    if (_title.text.trim().isEmpty || _times.isEmpty || _days.isEmpty) return;
    final entry = MedicationEntry(
      _title.text.trim(),
      int.tryParse(_count.text) ?? 1,
      _times
          .map((t) =>
              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
          .toList(),
      _days.toList(),
    );
    setState(() {
      _entries.add(entry);
      _title.clear();
      _count.clear();
      _times.clear();
      _days.clear();
    });
  }

  void _remove(int index) => setState(() => _entries.removeAt(index));

  Future<void> _saveAll() async {
    await _db.saveCellMedications(widget.cellNumber, _entries);
    final fresh = await _db.loadCellMedications(widget.cellNumber);
    if (!mounted) return;

    for (var entry in fresh) {
      final weekdays = entry.days.map((d) => _weekdays.indexOf(d) + 1).toList();
      for (var time in entry.times) {
        final parts = time.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);

        await NotificationService.scheduleWeeklyNotification(
          id: widget.cellNumber * 1000 + hour * 60 + minute,
          title: 'Напоминание о приёме',
          body: '${entry.title} — ${entry.quantity} шт.',
          hour: hour,
          minute: minute,
          weekdays: weekdays,
        );
      }
    }

    widget.onSave(widget.cellNumber, fresh);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ячейка ${widget.cellNumber}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_entries.isNotEmpty)
              ..._entries.asMap().entries.map((e) => ListTile(
                    title: Text(e.value.title),
                    subtitle: Text(
                        '${e.value.quantity} шт\n${e.value.times.join(', ')}\n${e.value.days.join(', ')}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _remove(e.key),
                    ),
                  )),
            const Divider(),
            TextField(
              controller: _title,
              decoration:
                  const InputDecoration(labelText: 'Название препарата'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _count,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Количество таблеток'),
            ),
            const SizedBox(height: 20),
            const Text('Время приёма:'),
            Wrap(
              spacing: 8,
              children: [
                ..._times.map((t) => Chip(label: Text(t.format(context)))),
                ActionChip(
                    label: const Text('+ Добавить'), onPressed: _addTime),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Дни недели:'),
            Wrap(
              spacing: 8,
              children: _weekdays.map((d) {
                return FilterChip(
                  label: Text(d),
                  selected: _days.contains(d),
                  onSelected: (_) => _toggleDay(d),
                );
              }).toList(),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _addEntry,
                    icon: const Icon(Icons.add, size: 16),
                    label:
                        const Text('Добавить', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveAll,
                    icon: const Icon(Icons.save, size: 16),
                    label:
                        const Text('Сохранить', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
