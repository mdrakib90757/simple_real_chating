class Message {
  final String messageId;
  final String sender;
  final String? text;
  final String? imageUrl;
  final String type;
  final bool isMe;
  final RepliedMessageInfo? repliedTo;

  Message({
    required this.messageId,
    required this.sender,
    this.text,
    this.imageUrl,
    required this.isMe,
    required this.type,
    this.repliedTo,
  });

  factory Message.fromMap(
    Map<String, dynamic> data,
    String currentUserId,
    String docId,
  ) {
    RepliedMessageInfo? repliedInfo;

    if (data['repliedTo'] != null && data['repliedTo'] is Map) {
      repliedInfo = RepliedMessageInfo.fromJson(data['repliedTo']);
    }

    return Message(
      messageId: docId,
      sender: data['senderEmail'] ?? "Unknown user",
      text: data['text'],
      imageUrl: data['imageUrl'],
      type: data['type'] ?? "text",
      isMe: data['senderId'] == currentUserId,
      repliedTo: repliedInfo,
    );
  }
}

class RepliedMessageInfo {
  final String content;
  final String senderEmail;
  final String? messageId;

  RepliedMessageInfo({
    required this.content,
    required this.senderEmail,
    this.messageId,
  });

  factory RepliedMessageInfo.fromJson(Map<String, dynamic> json) {
    return RepliedMessageInfo(
      content: json['content'] ?? '',
      senderEmail: json['senderEmail'] ?? 'Unknown',
      messageId: json["messageId"] ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'senderEmail': senderEmail,
      "messageId": messageId,
    };
  }
}
