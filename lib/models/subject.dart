class Subject {
  final String id;
  final String userId;
  final String name;
  final String professor;
  final int totalClasses;
  final int attendedClasses;
  final bool hasPractical;
  final bool isPracticalOnly;
  final int practicalTotal;
  final int practicalAttended;
  final String icon;
  final String color;
  final String createdAt;
  final bool isPending; // Local offline sync helper

  Subject({
    required this.id,
    required this.userId,
    this.name = 'Untitled Subject',
    this.professor = '',
    this.totalClasses = 0,
    this.attendedClasses = 0,
    this.hasPractical = false,
    this.isPracticalOnly = false,
    this.practicalTotal = 0,
    this.practicalAttended = 0,
    this.icon = 'school',
    this.color = 'primary',
    required this.createdAt,
    this.isPending = false,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      name: json['name'] ?? 'Untitled Subject',
      professor: json['professor'] ?? '',
      totalClasses: json['total_classes'] ?? 0,
      attendedClasses: json['attended_classes'] ?? 0,
      hasPractical: json['has_practical'] ?? false,
      isPracticalOnly: json['is_practical_only'] ?? false,
      practicalTotal: json['practical_total'] ?? 0,
      practicalAttended: json['practical_attended'] ?? 0,
      icon: json['icon'] ?? 'school',
      color: json['color'] ?? 'primary',
      createdAt: json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      isPending: json['isPending'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'professor': professor,
      'total_classes': totalClasses,
      'attended_classes': attendedClasses,
      'has_practical': hasPractical,
      'is_practical_only': isPracticalOnly,
      'practical_total': practicalTotal,
      'practical_attended': practicalAttended,
      'icon': icon,
      'color': color,
      'created_at': createdAt,
      'isPending': isPending,
    };
  }

  Subject copyWith({
    String? id,
    String? userId,
    String? name,
    String? professor,
    int? totalClasses,
    int? attendedClasses,
    bool? hasPractical,
    bool? isPracticalOnly,
    int? practicalTotal,
    int? practicalAttended,
    String? icon,
    String? color,
    String? createdAt,
    bool? isPending,
  }) {
    return Subject(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      professor: professor ?? this.professor,
      totalClasses: totalClasses ?? this.totalClasses,
      attendedClasses: attendedClasses ?? this.attendedClasses,
      hasPractical: hasPractical ?? this.hasPractical,
      isPracticalOnly: isPracticalOnly ?? this.isPracticalOnly,
      practicalTotal: practicalTotal ?? this.practicalTotal,
      practicalAttended: practicalAttended ?? this.practicalAttended,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      isPending: isPending ?? this.isPending,
    );
  }
}
