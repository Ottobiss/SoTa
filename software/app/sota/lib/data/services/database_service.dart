import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medication_entry.dart';

class DatabaseService {
  final _db = FirebaseFirestore.instance;
  final _collection = 'cells';

  Future<void> saveCellMedications(
      int cellNumber, List<MedicationEntry> meds) async {
    final data = meds.map((m) => m.toJson()).toList();
    await _db
        .collection(_collection)
        .doc('$cellNumber')
        .set({'medications': data});
  }

  Future<List<MedicationEntry>> loadCellMedications(int cellNumber) async {
    final doc = await _db.collection(_collection).doc('$cellNumber').get();
    if (!doc.exists || !doc.data()!.containsKey('medications')) return [];
    final raw = doc['medications'] as List;
    return raw.map((e) => MedicationEntry.fromJson(e)).toList();
  }

  Stream<List<MedicationEntry>> watchCell(int cellNumber) {
    return _db
        .collection(_collection)
        .doc('$cellNumber')
        .snapshots()
        .map((doc) {
      if (!doc.exists || !doc.data()!.containsKey('medications')) return [];
      final raw = doc['medications'] as List;
      return raw.map((e) => MedicationEntry.fromJson(e)).toList();
    });
  }
}
