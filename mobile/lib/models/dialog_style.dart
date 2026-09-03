class DialogStyle {
  const DialogStyle({
    required this.id,
    required this.name,
    required this.description,
    required this.systemInstruction,
    required this.userPrompt,
    this.builtIn = true,
  });

  final String id;
  final String name;
  final String description;
  final String systemInstruction;
  final String userPrompt;
  final bool builtIn;

  DialogStyle copyWith({
    String? id,
    String? name,
    String? description,
    String? systemInstruction,
    String? userPrompt,
    bool? builtIn,
  }) {
    return DialogStyle(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      systemInstruction: systemInstruction ?? this.systemInstruction,
      userPrompt: userPrompt ?? this.userPrompt,
      builtIn: builtIn ?? this.builtIn,
    );
  }

  factory DialogStyle.fromJson(Map<String, dynamic> json) => DialogStyle(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    systemInstruction: json['systemInstruction'] as String? ?? '',
    userPrompt: json['userPrompt'] as String? ?? '',
    builtIn: json['builtIn'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'systemInstruction': systemInstruction,
    'userPrompt': userPrompt,
    'builtIn': builtIn,
  };
}
