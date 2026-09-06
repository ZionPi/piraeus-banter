import 'dart:math';

import 'project.dart';
import 'conversation_view_mode.dart';

class AppSettings {
  AppSettings({
    this.hostName = '主持人（Leo）',
    this.guestName = '嘉宾（Jane）',
    this.hostVoiceId = 'zh_female_inspirational',
    this.guestVoiceId = 'zh_male_huolijieshuo',
    this.appKey = '',
    this.accessToken = '',
    this.geminiApiKey = '',
    this.geminiModel = 'gemini-3.6-flash',
    this.playbackSpeed = 1.0,
    this.skipBlankOnPlayback = true,
    this.dialogStyleId = 'spar',
    this.dialogueInputMode = 'topic',
    this.lastDialogueInput = '',
    this.lastDialogueUrl = '',
    this.lastDialogueFilePath = '',
    this.lastDialogueFileName = '',
    this.lastDialogueFileSize = 0,
    this.conversationViewMode = ConversationViewMode.chat,
    this.workspaceCollapsed = false,
    int? hostAvatarSeed,
    int? guestAvatarSeed,
    this.hostAvatarPath = '',
    this.guestAvatarPath = '',
  }) : hostAvatarSeed = hostAvatarSeed ?? newAvatarSeed(),
       guestAvatarSeed = guestAvatarSeed ?? newAvatarSeed() {
    while (this.guestAvatarSeed == this.hostAvatarSeed) {
      this.guestAvatarSeed = newAvatarSeed();
    }
  }

  String hostName;
  String guestName;
  String hostVoiceId;
  String guestVoiceId;
  String appKey;
  String accessToken;
  String geminiApiKey;
  String geminiModel;
  double playbackSpeed;
  bool skipBlankOnPlayback;
  String dialogStyleId;
  String dialogueInputMode;
  String lastDialogueInput;
  String lastDialogueUrl;
  String lastDialogueFilePath;
  String lastDialogueFileName;
  int lastDialogueFileSize;
  ConversationViewMode conversationViewMode;
  bool workspaceCollapsed;
  int hostAvatarSeed;
  int guestAvatarSeed;
  String hostAvatarPath;
  String guestAvatarPath;

  static int newAvatarSeed() => Random.secure().nextInt(0x7fffffff);

  factory AppSettings.fromProject(BanterProject project) => AppSettings(
    hostName: project.hostName,
    guestName: project.guestName,
    hostVoiceId: project.hostVoiceId,
    guestVoiceId: project.guestVoiceId,
    appKey: project.appKey,
    accessToken: project.accessToken,
    geminiApiKey: project.geminiApiKey,
    dialogStyleId: project.dialogStyleId,
  );

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    hostName: json['hostName'] as String? ?? '主持人（Leo）',
    guestName: json['guestName'] as String? ?? '嘉宾（Jane）',
    hostVoiceId: json['hostVoiceId'] as String? ?? 'zh_female_inspirational',
    guestVoiceId: json['guestVoiceId'] as String? ?? 'zh_male_huolijieshuo',
    appKey: json['appKey'] as String? ?? '',
    accessToken: json['accessToken'] as String? ?? '',
    geminiApiKey: json['geminiApiKey'] as String? ?? '',
    geminiModel: json['geminiModel'] as String? ?? 'gemini-3.6-flash',
    playbackSpeed: (json['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
    skipBlankOnPlayback: json['skipBlankOnPlayback'] as bool? ?? true,
    dialogStyleId: json['dialogStyleId'] as String? ?? 'spar',
    dialogueInputMode: json['dialogueInputMode'] as String? ?? 'topic',
    lastDialogueInput: json['lastDialogueInput'] as String? ?? '',
    lastDialogueUrl: json['lastDialogueUrl'] as String? ?? '',
    lastDialogueFilePath: json['lastDialogueFilePath'] as String? ?? '',
    lastDialogueFileName: json['lastDialogueFileName'] as String? ?? '',
    lastDialogueFileSize: (json['lastDialogueFileSize'] as num?)?.toInt() ?? 0,
    conversationViewMode: ConversationViewMode.fromId(
      json['conversationViewMode'] as String?,
    ),
    workspaceCollapsed: json['workspaceCollapsed'] as bool? ?? false,
    hostAvatarSeed: (json['hostAvatarSeed'] as num?)?.toInt(),
    guestAvatarSeed: (json['guestAvatarSeed'] as num?)?.toInt(),
    hostAvatarPath: json['hostAvatarPath'] as String? ?? '',
    guestAvatarPath: json['guestAvatarPath'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'hostName': hostName,
    'guestName': guestName,
    'hostVoiceId': hostVoiceId,
    'guestVoiceId': guestVoiceId,
    'appKey': appKey,
    'accessToken': accessToken,
    'geminiModel': geminiModel,
    'playbackSpeed': playbackSpeed,
    'skipBlankOnPlayback': skipBlankOnPlayback,
    'dialogStyleId': dialogStyleId,
    'dialogueInputMode': dialogueInputMode,
    'lastDialogueInput': lastDialogueInput,
    'lastDialogueUrl': lastDialogueUrl,
    'lastDialogueFilePath': lastDialogueFilePath,
    'lastDialogueFileName': lastDialogueFileName,
    'lastDialogueFileSize': lastDialogueFileSize,
    'conversationViewMode': conversationViewMode.id,
    'workspaceCollapsed': workspaceCollapsed,
    'hostAvatarSeed': hostAvatarSeed,
    'guestAvatarSeed': guestAvatarSeed,
    'hostAvatarPath': hostAvatarPath,
    'guestAvatarPath': guestAvatarPath,
  };

  void applyNamesTo(BanterProject project) {
    project.hostName = hostName;
    project.guestName = guestName;
    project.hostVoiceId = hostVoiceId;
    project.guestVoiceId = guestVoiceId;
    project.appKey = appKey;
    project.accessToken = accessToken;
    project.geminiApiKey = geminiApiKey;
    project.dialogStyleId = dialogStyleId;
    for (final bubble in project.bubbles) {
      bubble.name = bubble.role == BubbleRole.host ? hostName : guestName;
    }
  }
}
