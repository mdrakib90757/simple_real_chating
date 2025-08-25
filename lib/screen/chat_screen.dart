import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:web_socket_app/model/message_model/message_model.dart';
import 'package:web_socket_app/utils/color.dart';
import '../ChatService/chatService.dart';

class ChatScreen extends StatefulWidget {
  final String receiverEmail;
  final String receiverID;
  final String currentUserId; // sender
  final String receiverUserId; // receiver
  const ChatScreen({
    super.key,
    required this.receiverEmail,
    required this.receiverID,
    required this.currentUserId,
    required this.receiverUserId,
  });
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService chatService = ChatService();
  final FirebaseFirestore _firebaseFirestore = FirebaseFirestore.instance;
  final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final User currentUser = FirebaseAuth.instance.currentUser!;
  String chatRoomId = "";
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    List<String> ids = [currentUser.uid, widget.receiverID]..sort();
    ids.sort();
    chatRoomId = ids.join('_');
    _messaging.requestPermission(alert: true, badge: true, sound: true);

    // Foreground message listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        print("🔔 Foreground notification: ${message.notification!.body}");
      }
    });
  }

  Future<void> _sendMessage({String? text, String? imageUrl}) async {
    // String text = _textController.text.trim();
    // if (text.isEmpty) return;
    final String currentText = text ?? _textController.text.trim();
    if (currentText.isEmpty && (imageUrl == null || imageUrl.isEmpty)) {
      print("Cannot send an empty message.");
      return;
    }
    _textController.clear();

    await chatService.sendMessage(
      context: context,
      senderId: currentUser.uid,
      receiverId: widget.receiverUserId,
      message: currentText.isNotEmpty ? currentText : null,
      imageUrl: imageUrl,
    );
  }

  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isUploading = true);

    const String cloudName = "dlqufneob";
    const String uploadPreset = "chat_app_unsigned";
    final url = Uri.parse(
      "https://api.cloudinary.com/v1_1/$cloudName/image/upload",
    );

    try {
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', image.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonMap = json.decode(responseData);
        final imageUrl = jsonMap['secure_url'];


        await _sendMessage(imageUrl: imageUrl);
      } else {
        print("Image upload failed with status: ${response.statusCode}");
      }
    } catch (e) {
      print("Error uploading image: $e");
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColor.primaryColor,
        title: Text(
          widget.receiverEmail,
          style: TextStyle(color: Colors.white, fontSize: 15),
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firebaseFirestore
                  .collection("chat_rooms")
                  .doc(chatRoomId)
                  .collection("messages")
                  .orderBy("timestamp", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text("Say hello! 👋"));
                }
                final messages = snapshot.data!.docs;
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: EdgeInsets.all(16.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final doc = messages[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final message = Message(
                      sender: data['senderEmail'] ?? "Unknown user",
                      text: data['text'],
                      imageUrl: data["imageUrl"],
                      type: data['type'] ?? 'text',
                      isMe: data['senderId'] == currentUser.uid,
                    );
                    return _buildMessageBubble(message);
                  },
                );
              },
            ),
          ),

          _buildMessageComposer(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    final bool isMe = message.isMe;
    return Column(
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10, right: 10, bottom: 4),
          child: Text(
            message.sender,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
        Container(
          padding: message.type == 'image'
              ? EdgeInsets.all(5)
              : EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? AppColor.primaryColor : Color(0xFFF1F1F1),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: isMe ? const Radius.circular(20) : Radius.zero,
              bottomRight: isMe ? Radius.zero : const Radius.circular(20),
            ),
          ),
          child: message.type == "image"
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(15.0),
                  child: Image.network(
                    message.imageUrl ?? "",
                    height: 200,
                    width: 200,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      return progress == null
                          ? child
                          : SizedBox(
                              height: 200,
                              width: 200,
                              child: Center(child: CircularProgressIndicator()),
                            );
                    },
                  ),
                )
              : Text(
                  message.text ?? "",
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87,
                    fontSize: 16,
                  ),
                ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.photo_camera, color: AppColor.primaryColor),
            onPressed: _isUploading ? null : _sendImage,
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: "Type your message here",
                filled: true,
                fillColor: Color(0xFFF1F1F1),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 10.0,
                  horizontal: 20.0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(width: 8.0),
          GestureDetector(
            onTap: () {
              _sendMessage(text: _textController.text);
            },
            child: Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: AppColor.primaryColor,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
