class Profile {
  final String id;
  final String displayName;
  final String email;
  final String department;
  final String university;
  final String year;
  final String avatarUrl;

  Profile({
    required this.id,
    this.displayName = 'Student',
    this.email = '',
    this.department = '',
    this.university = 'Galgotias University',
    this.year = '1st Year',
    this.avatarUrl = '',
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] ?? '',
      displayName: json['display_name'] ?? 'Student',
      email: json['email'] ?? '',
      department: json['department'] ?? '',
      university: json['university'] ?? 'Galgotias University',
      year: json['year'] ?? '1st Year',
      avatarUrl: json['avatar_url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'email': email,
      'department': department,
      'university': university,
      'year': year,
      'avatar_url': avatarUrl,
    };
  }

  Profile copyWith({
    String? id,
    String? displayName,
    String? email,
    String? department,
    String? university,
    String? year,
    String? avatarUrl,
  }) {
    return Profile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      department: department ?? this.department,
      university: university ?? this.university,
      year: year ?? this.year,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
