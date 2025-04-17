import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sota/data/models/medication_entry.dart';
import 'package:sota/data/services/database_service.dart';
import 'package:sota/features/schedule/pages/cell_setup_page.dart';
import 'package:sota/features/schedule/widgets/cell_content_widget.dart';
import 'package:sota/core/notification_service.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  static const int totalCells = 15;
  static const double radius = 120;
  static const double buttonSize = 46;

  final _db = DatabaseService();
  final Map<int, GlobalKey> cellKeys = {};
  final Map<int, List<MedicationEntry>> cellMedications = {};
  int? hoveredCell;
  Timer? _nextDoseTimer;
  Map<String, dynamic>? _nextDose;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < totalCells; i++) {
      cellKeys[i] = GlobalKey();
    }
    _loadInitial();
    _updateNextDose();
    _nextDoseTimer =
        Timer.periodic(const Duration(minutes: 1), (_) => _updateNextDose());
  }

  @override
  void dispose() {
    _nextDoseTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    for (int i = 1; i <= 14; i++) {
      final entries = await _db.loadCellMedications(i);
      if (entries.isNotEmpty) {
        setState(() => cellMedications[i] = entries);
      }
    }
  }

  void _updateNextDose() {
    final next = _findNextDose();
    if (!mounted) return;
    setState(() => _nextDose = next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Расписание приёма'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.notifications),
        label: const Text('Тест уведомления'),
        onPressed: () {
          NotificationService.testNow();
        },
      ),
      body: GestureDetector(
        onPanDown: (details) => _detectHovered(details.globalPosition),
        onPanUpdate: (details) => _detectHovered(details.globalPosition),
        onPanEnd: (_) => setState(() => hoveredCell = null),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = min(constraints.maxWidth, constraints.maxHeight);
            final canvasSize = size * 0.95;
            final center = canvasSize / 2;

            return Center(
              child: SizedBox(
                width: canvasSize,
                height: canvasSize,
                child: Stack(
                  children: [
                    for (int i = 0; i < totalCells; i++)
                      _buildCellButton(i, center, canvasSize),
                    _buildCenterDisplay(center),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCellButton(int index, double center, double canvasSize) {
    final angle = 2 * pi * index / totalCells - pi / 2;
    final x = center + radius * cos(angle) - buttonSize / 2;
    final y = center + radius * sin(angle) - buttonSize / 2;
    final isHovered = hoveredCell == index;

    return Positioned(
      left: x,
      top: y,
      child: Container(
        key: cellKeys[index],
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: index == 0
              ? Colors.grey.shade400
              : isHovered
                  ? Colors.blueAccent
                  : const Color(0xFF1A1F27),
        ),
        child: index == 0
            ? const SizedBox.shrink()
            : TextButton(
                style: TextButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                ),
                onPressed: () => _openEditor(index),
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildCenterDisplay(double center) {
    return Positioned(
      left: center - 80,
      top: center - 65,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: hoveredCell != null && hoveredCell != 0
            ? StreamBuilder<List<MedicationEntry>>(
                stream: _db.watchCell(hoveredCell!),
                builder: (context, snapshot) {
                  final entries = snapshot.data ?? [];
                  return CellContentWidget(
                    key: ValueKey(hoveredCell),
                    cellId: hoveredCell!,
                    entries: entries,
                  );
                },
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _nextDose != null
                        ? 'Следующий приём'
                        : 'Ближайших\nприёмов нет',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_nextDose != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${_nextDose!['day']}, ${_nextDose!['time']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Ячейка ${_nextDose!['cell']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ]
                ],
              ),
      ),
    );
  }

  void _detectHovered(Offset globalPosition) {
    for (final entry in cellKeys.entries) {
      final context = entry.value.currentContext;
      if (context == null) continue;

      final box = context.findRenderObject() as RenderBox;
      final position = box.localToGlobal(Offset.zero);
      final rect = position & box.size;

      if (rect.contains(globalPosition)) {
        if (hoveredCell != entry.key) {
          setState(() => hoveredCell = entry.key);
        }
        return;
      }
    }

    if (hoveredCell != null) {
      setState(() => hoveredCell = null);
    }
  }

  void _openEditor(int cellId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CellSetupPage(
          cellNumber: cellId,
          onSave: (cell, entries) async {
            await _db.saveCellMedications(cell, entries);
            if (!mounted) return;
            setState(() {
              cellMedications[cell] = entries;
              hoveredCell = cell;
              _updateNextDose();
            });
          },
        ),
      ),
    );
  }

  Map<String, dynamic>? _findNextDose() {
    final now = DateTime.now();
    final nowWeekday = now.weekday;
    const shortWeek = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

    DateTime? nearest;
    int? nearestCell;
    String? nearestTime;
    String? nearestDay;

    for (int i = 1; i <= 14; i++) {
      final entries = cellMedications[i];
      if (entries == null) continue;

      for (final entry in entries) {
        for (final day in entry.days) {
          final dayIndex = shortWeek.indexOf(day);
          if (dayIndex == -1) continue;

          for (final time in entry.times) {
            final parts = time.split(':');
            if (parts.length != 2) continue;
            final hour = int.tryParse(parts[0]) ?? 0;
            final minute = int.tryParse(parts[1]) ?? 0;

            final weekdayTarget = dayIndex + 1;
            int addDays = (weekdayTarget - nowWeekday) % 7;
            if (addDays < 0) addDays += 7;

            var scheduled = DateTime(
              now.year,
              now.month,
              now.day,
              hour,
              minute,
            ).add(Duration(days: addDays));

            if (addDays == 0 && scheduled.isBefore(now)) {
              scheduled = scheduled.add(const Duration(days: 7));
            }

            if (nearest == null || scheduled.isBefore(nearest)) {
              nearest = scheduled;
              nearestCell = i;
              nearestTime =
                  '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
              nearestDay = day;
            }
          }
        }
      }
    }

    if (nearest != null) {
      return {
        'cell': nearestCell,
        'time': nearestTime,
        'day': nearestDay,
      };
    }

    return null;
  }
}
