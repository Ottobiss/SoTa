class MedicationEntry {
  final String title;
  final int quantity;
  final List<String> times;
  final List<String> days;

  MedicationEntry(this.title, this.quantity, this.times, this.days);

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'quantity': quantity,
      'times': times,
      'days': days,
    };
  }

  factory MedicationEntry.fromJson(Map<String, dynamic> json) {
    return MedicationEntry(
      json['title'],
      json['quantity'],
      List<String>.from(json['times']),
      List<String>.from(json['days']),
    );
  }
}
