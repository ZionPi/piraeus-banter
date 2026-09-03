enum BubbleRole { host, guest }

enum BubbleStatus { idle, loading, success, error }

class DialogueBubble {
  DialogueBubble({
    required this.id,
    required this.role,
    required this.name,
    required this.content,
    this.isNonEssential = false,
    this.topicId,
    this.status = BubbleStatus.idle,
    this.audioPath,
    this.errorMessage,
  });

  final String id;
  BubbleRole role;
  String name;
  String content;
  bool isNonEssential;
  int? topicId;
  BubbleStatus status;
  String? audioPath;
  String? errorMessage;

  String get speakerLabel => role == BubbleRole.host ? 'Host' : 'Guest';

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.name,
    'name': name,
    'content': content,
    'isNonEssential': isNonEssential,
    'topicId': topicId,
    'status': status.name,
    'audioPath': audioPath,
    'errorMessage': errorMessage,
  };

  factory DialogueBubble.fromJson(Map<String, dynamic> json) {
    return DialogueBubble(
      id: '${json['id'] ?? DateTime.now().microsecondsSinceEpoch}',
      role: BubbleRole.values.firstWhere(
        (role) => role.name == json['role'],
        orElse: () => BubbleRole.guest,
      ),
      name: json['name'] as String? ?? 'Speaker',
      content: json['content'] as String? ?? '',
      isNonEssential: json['isNonEssential'] as bool? ?? false,
      topicId: (json['topicId'] as num?)?.toInt(),
      status: BubbleStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => BubbleStatus.idle,
      ),
      audioPath: json['audioPath'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}

class ProjectSummary {
  ProjectSummary({
    required this.fileName,
    required this.name,
    required this.updatedAt,
    required this.bubbleCount,
  });

  final String fileName;
  final String name;
  final DateTime updatedAt;
  final int bubbleCount;
}

class BanterProject {
  BanterProject({
    required this.name,
    required this.updatedAt,
    required this.bubbles,
    this.fileName,
    this.hostName = 'Host (Leo)',
    this.guestName = 'Guest (Jane)',
    this.hostVoiceId = 'zh_female_inspirational',
    this.guestVoiceId = 'zh_male_huolijieshuo',
    this.appKey = '',
    this.accessToken = '',
    this.geminiApiKey = '',
    this.dialogStyleId = 'spar',
  });

  String? fileName;
  String name;
  DateTime updatedAt;
  List<DialogueBubble> bubbles;
  String hostName;
  String guestName;
  String hostVoiceId;
  String guestVoiceId;
  String appKey;
  String accessToken;
  String geminiApiKey;
  String dialogStyleId;

  Map<String, dynamic> toJson() => {
    'name': name,
    'updatedAt': updatedAt.toIso8601String(),
    'hostName': hostName,
    'guestName': guestName,
    'hostVoiceId': hostVoiceId,
    'guestVoiceId': guestVoiceId,
    'bubbles': bubbles.map((bubble) => bubble.toJson()).toList(),
  };

  factory BanterProject.fromJson(
    Map<String, dynamic> json, {
    String? fileName,
  }) {
    return BanterProject(
      fileName: fileName,
      name: json['name'] as String? ?? 'Mobile_Project',
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      hostName: json['hostName'] as String? ?? 'Host (Leo)',
      guestName: json['guestName'] as String? ?? 'Guest (Jane)',
      hostVoiceId: json['hostVoiceId'] as String? ?? 'zh_female_inspirational',
      guestVoiceId: json['guestVoiceId'] as String? ?? 'zh_male_huolijieshuo',
      appKey: json['appKey'] as String? ?? '',
      accessToken: json['accessToken'] as String? ?? '',
      geminiApiKey: json['geminiApiKey'] as String? ?? '',
      dialogStyleId: json['dialogStyleId'] as String? ?? 'spar',
      bubbles: (json['bubbles'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(DialogueBubble.fromJson)
          .toList(),
    );
  }

  factory BanterProject.initial({String? name}) => BanterProject(
    name: name ?? 'Mobile_Project',
    updatedAt: DateTime.now(),
    bubbles: [
      DialogueBubble(
        id: '1',
        role: BubbleRole.host,
        name: 'Host (Leo)',
        content: '在这里开始编写你的播客对话。',
      ),
      DialogueBubble(
        id: '2',
        role: BubbleRole.guest,
        name: 'Guest (Jane)',
        content: '也可以从桌面版兼容的 JSON 剧本导入。',
      ),
    ],
  );
}

extension BubbleRoleName on BubbleRole {
  String get displayName => this == BubbleRole.host ? '主持人' : '嘉宾';
}
