final class ExplainPaperDto {
  const ExplainPaperDto({required this.title});

  factory ExplainPaperDto.fromJson(Map<String, dynamic> json) {
    return ExplainPaperDto(title: json['title'] as String);
  }

  final String title;

  Map<String, dynamic> toJson() => {'title': title};
}

final class ExplainTodoDto {
  const ExplainTodoDto({required this.required, required this.text});

  factory ExplainTodoDto.fromJson(Map<String, dynamic> json) {
    return ExplainTodoDto(
      required: json['required'] as bool,
      text: json['text'] as String,
    );
  }

  final bool required;
  final String text;

  Map<String, dynamic> toJson() => {'required': required, 'text': text};
}

final class ExplainDateDto {
  const ExplainDateDto({required this.date, this.time, required this.text});

  factory ExplainDateDto.fromJson(Map<String, dynamic> json) {
    return ExplainDateDto(
      date: json['date'] as String,
      time: json['time'] as String?,
      text: json['text'] as String,
    );
  }

  final String date;
  final String? time;
  final String text;

  Map<String, dynamic> toJson() => {'date': date, 'time': time, 'text': text};
}

final class ExplainCautionDto {
  const ExplainCautionDto({required this.text});

  factory ExplainCautionDto.fromJson(Map<String, dynamic> json) {
    return ExplainCautionDto(text: json['text'] as String);
  }

  final String text;

  Map<String, dynamic> toJson() => {'text': text};
}

final class ExplainContactDto {
  const ExplainContactDto({required this.name, required this.phone});

  factory ExplainContactDto.fromJson(Map<String, dynamic> json) {
    return ExplainContactDto(
      name: json['name'] as String,
      phone: json['phone'] as String,
    );
  }

  final String name;
  final String phone;

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};
}

final class ExplainPlaceDto {
  const ExplainPlaceDto({required this.text});

  factory ExplainPlaceDto.fromJson(Map<String, dynamic> json) {
    return ExplainPlaceDto(text: json['text'] as String);
  }

  final String text;

  Map<String, dynamic> toJson() => {'text': text};
}

final class ExplainResponseDto {
  const ExplainResponseDto({
    required this.explainSchemaVersion,
    required this.sessionId,
    required this.status,
    required this.paper,
    required this.explain,
    required this.todo,
    this.date,
    this.caution,
    this.contact,
    this.place,
  });

  factory ExplainResponseDto.fromJson(Map<String, dynamic> json) {
    return ExplainResponseDto(
      explainSchemaVersion: json['explain_schema_version'] as String,
      sessionId: json['session_id'] as String,
      status: json['status'] as String,
      paper: ExplainPaperDto.fromJson(json['paper'] as Map<String, dynamic>),
      explain: (json['explain'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      todo: ExplainTodoDto.fromJson(json['todo'] as Map<String, dynamic>),
      date: _nullableObject(json['date'], ExplainDateDto.fromJson),
      caution: _nullableObject(json['caution'], ExplainCautionDto.fromJson),
      contact: _nullableObject(json['contact'], ExplainContactDto.fromJson),
      place: _nullableObject(json['place'], ExplainPlaceDto.fromJson),
    );
  }

  final String explainSchemaVersion;
  final String sessionId;
  final String status;
  final ExplainPaperDto paper;
  final List<String> explain;
  final ExplainTodoDto todo;
  final ExplainDateDto? date;
  final ExplainCautionDto? caution;
  final ExplainContactDto? contact;
  final ExplainPlaceDto? place;

  Map<String, dynamic> toJson() => {
    'explain_schema_version': explainSchemaVersion,
    'session_id': sessionId,
    'status': status,
    'paper': paper.toJson(),
    'explain': explain,
    'todo': todo.toJson(),
    'date': date?.toJson(),
    'caution': caution?.toJson(),
    'contact': contact?.toJson(),
    'place': place?.toJson(),
  };
}

T? _nullableObject<T>(Object? raw, T Function(Map<String, dynamic>) fromJson) {
  if (raw == null) return null;
  return fromJson(raw as Map<String, dynamic>);
}
