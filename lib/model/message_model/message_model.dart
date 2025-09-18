class Message {
  final String sender;
  final String? text;
  final String? imageUrl;
  final String type;
  final bool isMe;
  final bool? isRead;
  final RepliedMessageInfo? repliedTo;

  Message({
    required this.sender,
    this.text,
    this.imageUrl,
    required this.isMe,
    required this.type,
    this.repliedTo,
    this.isRead,
  });

  factory Message.fromMap(Map<String, dynamic> data, String currentUserEmail) {
    return Message(
      sender: data['sender']?.toString() ?? "Unknown user",
      text: data['text']?.toString(),
      imageUrl: data['imageUrl']?.toString(),
      type: data['type']?.toString() ?? "text",
      isRead: data['isRead'] ?? false,
      isMe: data['sender']?.toString() == currentUserEmail,
    );
  }
}

class RepliedMessageInfo {
  final String content;
  final String senderEmail;

  RepliedMessageInfo({required this.content, required this.senderEmail});

  factory RepliedMessageInfo.fromJson(Map<String, dynamic> json) {
    return RepliedMessageInfo(
      content: json['content'] ?? '',
      senderEmail: json['senderEmail'] ?? 'Unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {'content': content, 'senderEmail': senderEmail};
  }
}
