class Note {
  final String id;
  final String title;
  final String content;
  final int colorValue;
  final DateTime updatedAt;
  final DateTime? reminderAt;
  final bool isPinned;

  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.colorValue,
    required this.updatedAt,
    this.reminderAt,
    this.isPinned = false,
  });

  Note copyWith({
    String? id,
    String? title,
    String? content,
    int? colorValue,
    DateTime? updatedAt,
    DateTime? reminderAt,
    bool? clearReminder,
    bool? isPinned,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      colorValue: colorValue ?? this.colorValue,
      updatedAt: updatedAt ?? this.updatedAt,
      reminderAt: clearReminder == true ? null : (reminderAt ?? this.reminderAt),
      isPinned: isPinned ?? this.isPinned,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'colorValue': colorValue,
      'updatedAt': updatedAt.toIso8601String(),
      'reminderAt': reminderAt?.toIso8601String(),
      'isPinned': isPinned,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      colorValue: json['colorValue'] as int,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      reminderAt: json['reminderAt'] != null
          ? DateTime.parse(json['reminderAt'] as String)
          : null,
      isPinned: json['isPinned'] as bool? ?? false,
    );
  }
}
