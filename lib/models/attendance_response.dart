class AttendanceResponse {
  final String id;
  final String userId;
  final String slotId;
  final String date; // YYYY-MM-DD
  final bool lectureHappened;
  final bool attended;
  final String createdAt;

  AttendanceResponse({
    required this.id,
    required this.userId,
    required this.slotId,
    required this.date,
    this.lectureHappened = true,
    this.attended = false,
    required this.createdAt,
  });

  factory AttendanceResponse.fromJson(Map<String, dynamic> json) {
    return AttendanceResponse(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      slotId: json['slot_id'] ?? '',
      date: json['date'] ?? '',
      lectureHappened: json['lecture_happened'] ?? true,
      attended: json['attended'] ?? false,
      createdAt: json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'slot_id': slotId,
      'date': date,
      'lecture_happened': lectureHappened,
      'attended': attended,
      'created_at': createdAt,
    };
  }

  AttendanceResponse copyWith({
    String? id,
    String? userId,
    String? slotId,
    String? date,
    bool? lectureHappened,
    bool? attended,
    String? createdAt,
  }) {
    return AttendanceResponse(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      slotId: slotId ?? this.slotId,
      date: date ?? this.date,
      lectureHappened: lectureHappened ?? this.lectureHappened,
      attended: attended ?? this.attended,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
