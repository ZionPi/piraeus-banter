enum ConversationViewMode {
  chat('chat', '聊天气泡', '左右对话气泡，适合连续阅读和长图截取'),
  card('card', '卡片列表', '保留原来的单条卡片工作台样式');

  const ConversationViewMode(this.id, this.label, this.description);

  final String id;
  final String label;
  final String description;

  static ConversationViewMode fromId(String? id) {
    return ConversationViewMode.values.firstWhere(
      (mode) => mode.id == id,
      orElse: () => ConversationViewMode.chat,
    );
  }
}
