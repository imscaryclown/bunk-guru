class ScheduleSlot {
  final String id;
  final String userId;
  final String subjectId;
  final int dayOfWeek; // 0=Mon, ..., 6=Sun
  final String time;
  final String endTime;
  final String slotType; // 'theory' or 'practical'
  final String room;
  final String createdAt;
  final bool isPending;

  ScheduleSlot({
    required this.id,
    required this.userId,
    required this.subjectId,
    required this.dayOfWeek,
    this.time = '09:00',
    this.endTime = '10:00',
    this.slotType = 'theory',
    this.room = '',
    required this.createdAt,
    this.isPending = false,
  });

  factory ScheduleSlot.fromJson(Map<String, dynamic> json) {
    return ScheduleSlot(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      subjectId: json['subject_id'] ?? '',
      dayOfWeek: json['day_of_week'] is String 
          ? int.parse(json['day_of_week']) 
          : (json['day_of_week'] ?? json['day'] ?? 0),
      time: json['time'] ?? '09:00',
      endTime: json['end_time'] ?? '10:00',
      slotType: json['slot_type'] ?? 'theory',
      room: json['room'] ?? '',
      createdAt: json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      isPending: json['isPending'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'subject_id': subjectId,
      'day_of_week': dayOfWeek,
      'time': time,
      'end_time': endTime,
      'slot_type': slotType,
      'room': room,
      'created_at': createdAt,
      'isPending': isPending,
    };
  }

  ScheduleSlot copyWith({
    String? id,
    String? userId,
    String? subjectId,
    int? dayOfWeek,
    String? time,
    String? endTime,
    String? slotType,
    String? room,
    String? createdAt,
    bool? isPending,
  }) {
    return ScheduleSlot(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      subjectId: subjectId ?? this.subjectId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      time: time ?? this.time,
      endTime: endTime ?? this.endTime,
      slotType: slotType ?? this.slotType,
      room: room ?? this.room,
      createdAt: createdAt ?? this.createdAt,
      isPending: isPending ?? this.isPending,
    );
  }
}
