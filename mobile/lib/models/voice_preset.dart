class VoicePreset {
  const VoicePreset({required this.name, required this.id});

  final String name;
  final String id;

  factory VoicePreset.fromJson(Map<String, dynamic> json) {
    return VoicePreset(
      name: json['name'] as String? ?? json['id'] as String? ?? 'Unknown',
      id: json['id'] as String? ?? '',
    );
  }
}
