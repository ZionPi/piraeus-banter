import 'project.dart';

class AppSettings {
  AppSettings({
    this.hostName = 'Host (Leo)',
    this.guestName = 'Guest (Jane)',
    this.hostVoiceId = 'zh_female_inspirational',
    this.guestVoiceId = 'zh_male_huolijieshuo',
    this.appKey = '',
    this.accessToken = '',
    this.geminiApiKey = '',
    this.dialogStyleId = 'spar',
  });

  String hostName;
  String guestName;
  String hostVoiceId;
  String guestVoiceId;
  String appKey;
  String accessToken;
  String geminiApiKey;
  String dialogStyleId;

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
    hostName: json['hostName'] as String? ?? 'Host (Leo)',
    guestName: json['guestName'] as String? ?? 'Guest (Jane)',
    hostVoiceId: json['hostVoiceId'] as String? ?? 'zh_female_inspirational',
    guestVoiceId: json['guestVoiceId'] as String? ?? 'zh_male_huolijieshuo',
    appKey: json['appKey'] as String? ?? '',
    accessToken: json['accessToken'] as String? ?? '',
    geminiApiKey: json['geminiApiKey'] as String? ?? '',
    dialogStyleId: json['dialogStyleId'] as String? ?? 'spar',
  );

  Map<String, dynamic> toJson() => {
    'hostName': hostName,
    'guestName': guestName,
    'hostVoiceId': hostVoiceId,
    'guestVoiceId': guestVoiceId,
    'appKey': appKey,
    'accessToken': accessToken,
    'geminiApiKey': geminiApiKey,
    'dialogStyleId': dialogStyleId,
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
