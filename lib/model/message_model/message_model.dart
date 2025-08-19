

class Message{
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
    required this.type
});
}