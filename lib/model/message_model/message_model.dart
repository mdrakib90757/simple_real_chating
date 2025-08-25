class Message {
  final String sender;
  final String? text;
  final String? imageUrl;
  final String type;
  final bool isMe;

  Message({
    required this.sender,
    this.text,
    this.imageUrl,
    required this.isMe,
    required this.type,
  });

  factory Message.fromMap(Map<String, dynamic> data, String currentUserEmail) {
    return Message(
      sender: data['sender']?.toString() ?? "Unknown user",
      text: data['text']?.toString(),
      imageUrl: data['imageUrl']?.toString(),
      type: data['type']?.toString() ?? "text",
      isMe: data['sender']?.toString() == currentUserEmail,
    );
  }
}
