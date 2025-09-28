import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:web_socket_app/model/message_model/message_model.dart';
import 'package:web_socket_app/screen/camera/cameraScreen.dart';
import 'package:web_socket_app/screen/photo_display_screen/photo_display_screen.dart';
import 'package:web_socket_app/screen/video_display_screen/video_display_screen.dart';
import 'package:web_socket_app/utils/color.dart';
import '../ChatService/chatService.dart';
import 'package:web_socket_app/main.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:crypto/crypto.dart';
import '../notification_handle/notificationHandle.dart';
import '../utils/call_handler/call_handler.dart';
import 'call_screen/call_screen.dart';
import 'calling_screen/calling_screen.dart';

class ChatScreen extends StatefulWidget {
  final String receiverEmail;
  final String receiverID;
  final String currentUserId;
  final String receiverUserId;
  final String currentUserEmail;
  const ChatScreen({
    super.key,
    required this.receiverEmail,
    required this.receiverID,
    required this.currentUserId,
    required this.receiverUserId,
    required this.currentUserEmail,
  });
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService chatService = ChatService();
  final FirebaseDatabase _realtimeDatabase = FirebaseDatabase.instance;
  final FirebaseFirestore _firebaseFirestore = FirebaseFirestore.instance;
  final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  NotificationHandler? _notificationHandler;

  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final User currentUser = FirebaseAuth.instance.currentUser!;
  String chatRoomId = "";
  bool _isUploading = false;
  String? _receiverPhotoUrl;
  RepliedMessageInfo? _repliedMessage;
  String? _editingMessageId;
  String? _repliedMessageId;
  DatabaseReference? _typingStatusRef;
  StreamSubscription<DatabaseEvent>? _typingSubscription;
  bool _isReceiverTyping = false;
  Timer? _debounce;
  bool _showEmojiPicker = false;
  final FocusNode _emojiFocusNode = FocusNode();
  final String cloudinaryApiKey = "911398349135266";
  final String CLOUDINARY_API_SECRET = "572xxi7X4yqr_3Y-wRcJ7EgJUJs";

  // final String url = "https://api.cloudinary.com/v1_1/$cloudName/$cloudinaryResourceType/destroy";
  @override
  void initState() {
    super.initState();
    List<String> ids = [currentUser.uid, widget.receiverID]..sort();
    ids.sort();
    chatRoomId = ids.join('_');
    _messaging.requestPermission(alert: true, badge: true, sound: true);

    currentChatUserId = widget.receiverID;
    _markMessagesAsRead();

    _typingStatusRef = _realtimeDatabase.ref(
      'chat_room_typing/$chatRoomId/${currentUser.uid}',
    );
    _setupTypingListener();
    _emojiFocusNode.addListener(() {
      if (_emojiFocusNode.hasFocus) {
        setState(() {
          _showEmojiPicker = false;
        });
      }
    });
    _fetchReceiverPhotoUrl();
    _notificationHandler = NotificationHandler(context);
  }

  @override
  void dispose() {
    // TODO: implement dispose
    _textController.dispose();
    currentChatUserId = null;
    _typingSubscription?.cancel();
    _setTypingStatus(false);
    _debounce?.cancel();
    _emojiFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage({String? text, String? imageUrl}) async {
    final String currentText = text ?? _textController.text.trim();
    if (currentText.isEmpty && (imageUrl == null || imageUrl.isEmpty)) {
      print("Cannot send an empty message.");
      return;
    }
    if (_editingMessageId != null) {
      await _editMessage(_editingMessageId!, currentText);
      setState(() {
        _editingMessageId = null;
        _textController.clear();
      });
      return;
    }
    _textController.clear();

    final RepliedMessageInfo? messageToReplay = _repliedMessage;
    setState(() {
      _repliedMessage = null;
      _repliedMessageId = null;
    });

    await chatService.sendMessage(
      context: context,
      senderId: currentUser.uid,
      receiverId: widget.receiverUserId,
      message: currentText.isNotEmpty ? currentText : null,
      imageUrl: imageUrl,
      repliedMessage: messageToReplay,
    );
  }

  // send file with image
  Future<void> _sendFile() async {
    final pickedOption = await showModalBottomSheet<String>(
      backgroundColor: Colors.white,
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Send Image from Gallery'),
                onTap: () => Navigator.pop(context, 'image'),
              ),
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Send Video from Gallery'),
                onTap: () => Navigator.pop(context, 'video'),
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: const Text('Send Document (PDF, etc.)'),
                onTap: () => Navigator.pop(context, 'document'),
              ),
            ],
          ),
        );
      },
    );

    if (pickedOption == null) return;

    if (pickedOption == 'image') {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      await _uploadToCloudinary(image.path, 'image');
    } else if (pickedOption == 'video') {
      final picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
      if (video == null) return;
      await _uploadToCloudinary(video.path, 'video');
    } else if (pickedOption == 'document') {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'csv'],
      );

      if (result == null || result.files.isEmpty) return;

      final PlatformFile file = result.files.first;
      if (file.path == null) return;

      await _uploadToCloudinary(file.path!, 'document', fileName: file.name);
    }
  }

  // Generic Cloudinary upload function
  Future<void> _uploadToCloudinary(
    String filePath,
    String fileType, {
    String? fileName,
  }) async {
    setState(() => _isUploading = true);

    const String cloudName = "dlqufneob";
    String uploadPreset;
    String cloudinaryResourceType;

    if (fileType == 'image') {
      uploadPreset = "chat_app_unsigned";
      cloudinaryResourceType = "image";
    } else if (fileType == 'video') {
      uploadPreset = "chat_app_unsigned";
      cloudinaryResourceType = "video";
    } else if (fileType == 'document') {
      uploadPreset = "chat_app_unsigned";
      cloudinaryResourceType = "raw";
    } else {
      print("Unsupported file type for upload: $fileType");
      setState(() => _isUploading = false);
      return;
    }

    final url = Uri.parse(
      "https://api.cloudinary.com/v1_1/$cloudName/$cloudinaryResourceType/upload",
    );

    try {
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(
          await http.MultipartFile.fromPath(
            'file',
            filePath,
            filename: fileName,
          ),
        );

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonMap = json.decode(responseData);
        final fileUrl = jsonMap['secure_url'];
        final publicId = jsonMap['public_id'];
        await chatService.sendMessage(
          context: context,
          senderId: currentUser.uid,
          receiverId: widget.receiverUserId,
          message: null,
          imageUrl: fileUrl,
          type: fileType,
          fileName: fileName,
          publicId: publicId,
        );
      } else {
        print("$fileType upload failed with status: ${response.statusCode}");
        final errorBody = await response.stream.bytesToString();
        print("Error response: $errorBody");
      }
    } catch (e) {
      print("Error uploading $fileType: $e");
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // send camera image
  Future<void> _sendCapturedImage(String imagePath) async {
    setState(() => _isUploading = true);

    const String cloudName = "dlqufneob";
    const String uploadPreset = "chat_app_unsigned";
    final url = Uri.parse(
      "https://api.cloudinary.com/v1_1/$cloudName/image/upload",
    );

    try {
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', imagePath));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonMap = json.decode(responseData);
        final imageUrl = jsonMap['secure_url'];
        final publicId = jsonMap['public_id'];

        //await _sendMessage(imageUrl: imageUrl);

        await chatService.sendMessage(
          context: context,
          senderId: currentUser.uid,
          receiverId: widget.receiverUserId,
          message: null,
          imageUrl: imageUrl,
          type: "image",
          publicId: publicId,
        );
      } else {
        print("Image upload failed with status: ${response.statusCode}");
      }
    } catch (e) {
      print("Error uploading image: $e");
    } finally {
      setState(() => _isUploading = false);
    }
  }

  //send camera video
  Future<void> _sendCapturedVideo(String videoPath) async {
    setState(() => _isUploading = true);

    const String cloudName = "dlqufneob";
    const String uploadPreset = "chat_app_unsigned";
    final url = Uri.parse(
      "https://api.cloudinary.com/v1_1/$cloudName/video/upload",
    );

    try {
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', videoPath));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonMap = json.decode(responseData);
        final videoUrl = jsonMap['secure_url'];
        final publicId = jsonMap['public_id'];

        await chatService.sendMessage(
          context: context,
          senderId: currentUser.uid,
          receiverId: widget.receiverUserId,
          message: null,
          imageUrl: videoUrl,
          type: "video",
          publicId: publicId,
        );
      } else {
        print("Video upload failed: ${response.statusCode}");
      }
    } catch (e) {
      print("Error uploading video: $e");
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // all message marks
  Future<void> _markMessagesAsRead() async {
    final messagesRef = _firebaseFirestore
        .collection("chat_rooms")
        .doc(chatRoomId)
        .collection("messages");

    final unreadMessages = await messagesRef
        .where('receiverId', isEqualTo: currentUser.uid)
        .where('senderId', isEqualTo: widget.receiverUserId)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in unreadMessages.docs) {
      await doc.reference.update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }
  }

  void _setupTypingListener() {
    final receiverTypingRef = _realtimeDatabase.ref(
      'chat_room_typing/$chatRoomId/${widget.receiverUserId}',
    );
    _typingSubscription = receiverTypingRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        setState(() {
          final lastUpdated = data['timestamp'] as int?;
          if (lastUpdated != null &&
              (DateTime.now().millisecondsSinceEpoch - lastUpdated) < 5000) {
            _isReceiverTyping = data['isTyping'] ?? false;
          } else {
            _isReceiverTyping = false;
          }
        });
      } else {
        setState(() {
          _isReceiverTyping = false;
        });
      }
    });
  }

  void _setTypingStatus(bool isTyping) {
    _typingStatusRef
        ?.set({'isTyping': isTyping, 'timestamp': ServerValue.timestamp})
        .catchError((error) {
          print("Failed to set typing status: $error");
        });
  }

  //delete  message dialog
  void _showEditDeleteOptions(DocumentSnapshot messageDoc) {
    final data = messageDoc.data() as Map<String, dynamic>;
    final String? messageText = data['text'];
    final String? imageUrl = data['imageUrl'];
    final String? messageType = data['type'];
    final String? publicId = data['publicId'];

    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (messageText != null &&
                  messageText.isNotEmpty &&
                  messageType == 'text')
                ListTile(
                  leading: Icon(Icons.edit),
                  title: Text("Edit Message"),
                  onTap: () {
                    Navigator.pop(context);
                    _startEditingMessage(messageDoc.id, messageText);
                  },
                ),
              ListTile(
                leading: Icon(Icons.delete_forever, color: Colors.red),
                title: Text(
                  "Delete Message",
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(
                    messageDoc.id,
                    imageUrl,
                    messageType,
                    publicId,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // edit message dialog
  void _startEditingMessage(String messageId, String currentText) {
    setState(() {
      _editingMessageId = messageId;
      _textController.text = currentText;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
    });

    FocusScope.of(context).requestFocus(_emojiFocusNode);
  }

  //delete message
  Future<void> _deleteMessage(
    String messageId,
    String? imageUrl,
    String? type,
    String? publicId,
  ) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text("Delete Message"),
        content: Text(
          "Are you sure you want to delete this message? This cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firebaseFirestore
            .collection('chat_rooms')
            .doc(chatRoomId)
            .collection('messages')
            .doc(messageId)
            .delete();

        if (imageUrl != null && imageUrl.isNotEmpty && publicId != null) {
          await _deleteFileFromCloudinary(publicId, type);
          print("File deleted from Cloudinary.");
        }

        print("Message deleted from Firestore.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Message deleted successfully.")),
        );
      } catch (e) {
        print("Error deleting message: $e");
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to delete message: $e")));
      }
    }
  }

  // Function to delete files from Cloudinary
  Future<void> _deleteFileFromCloudinary(
    String publicId,
    String? fileType,
  ) async {
    const String cloudName = "dlqufneob";
    String cloudinaryResourceType;
    if (fileType == 'image') {
      cloudinaryResourceType = "image";
    } else if (fileType == 'video') {
      cloudinaryResourceType = "video";
    } else if (fileType == 'document') {
      cloudinaryResourceType = "raw";
    } else {
      print("Unsupported file type for deletion: $fileType");
      return;
    }
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000)
        .toString();
    Map<String, String> paramsToSign = {
      'public_id': publicId,
      'timestamp': timestamp,
      'invalidate': 'true',
    };
    var sortedKeys = paramsToSign.keys.toList()..sort();
    String paramString = sortedKeys
        .map((key) => '$key=${paramsToSign[key]}')
        .join('&');
    final String signatureString = '$paramString$CLOUDINARY_API_SECRET';
    final List<int> bytes = utf8.encode(signatureString);
    final String signature = sha1.convert(bytes).toString();

    final String url =
        "https://api.cloudinary.com/v1_1/$cloudName/$cloudinaryResourceType/destroy";
    print('Attempting to delete Cloudinary file: $publicId (Type: $fileType)');
    print(
      'Signature String used: $signatureString',
    ); // For debugging signature issues
    print('Generated Signature: $signature');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          //'Authorization': 'Basic ' + base64Encode(utf8.encode('$cloudinaryApiKey:$CLOUDINARY_API_SECRET')),
        },
        body: jsonEncode({
          'public_id': publicId,
          'timestamp': timestamp,
          'signature': signature,
          'invalidate': true,
          'api_key': cloudinaryApiKey,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['result'] == 'ok') {
          print("Cloudinary file $publicId deleted successfully.");
        } else {
          print(
            "Cloudinary deletion failed for $publicId: ${responseData['result']}",
          );
        }
      } else {
        print(
          "Cloudinary deletion API error for $publicId: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      print("Error deleting from Cloudinary for $publicId: $e");
    }
  }

  //edit message
  Future<void> _editMessage(String messageId, String newText) async {
    try {
      await _firebaseFirestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .update({'text': newText, 'editedAt': FieldValue.serverTimestamp()});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Message updated!")));
    } catch (e) {
      print("Error editing message: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to edit message: $e")));
    }
  }

  //fetch receiver photo
  Future<void> _fetchReceiverPhotoUrl() async {
    try {
      DocumentSnapshot userDoc = await _firebaseFirestore
          .collection('users') // Assuming your user profiles are here
          .doc(widget.receiverID) // Use the receiver's ID
          .get();

      if (userDoc.exists) {
        setState(() {
          _receiverPhotoUrl = userDoc['photoUrl']; // Assuming 'photoUrl' field
        });
      } else {
        print("Receiver user document not found!");
      }
    } catch (e) {
      print("Error fetching receiver photo URL: $e");
    }
  }

  // get receiver ReceiverEmail
  String _getTruncatedReceiverEmail(String email) {
    const String targetString = "mdrakibdeveloper";
    const int maxDisplayLength = targetString.length;
    int atIndex = email.indexOf('@');

    if (atIndex != -1 &&
        email.substring(0, atIndex).length > maxDisplayLength) {
      return email.substring(0, maxDisplayLength) + '...';
    } else if (email.length > 20) {
      return email.substring(0, 17) + '...';
    }
    return email;
  }

  // get receiver FCMToke
  Future<String?> _getReceiverFcmToken(String receiverUserId) async {
    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(receiverUserId)
        .get();

    if (doc.exists && doc.data() != null) {
      return doc.data()!["fcmToken"];
    }
    return null;
  }

  // get receiver profile photo
  Future<String> getReceiverPhoto(String userID) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userID)
        .get();
    if (doc.exists) {
      return doc.data()?['photoUrl'] ?? '';
    }
    return '';
  }

  Future<void> _startCall({required bool isAudio}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final String callID = "call_${currentUser.uid}_${widget.receiverID}";

    await chatService.sendMessage(
      context: context,
      senderId: currentUser.uid,
      receiverId: widget.receiverUserId,
      message: isAudio ? "📞 Audio Call" : "🎥 Video Call",
      type: "call",
      isAudioCall: isAudio,
    );

    // Create Firestore call document
    await FirebaseFirestore.instance.collection('calls').doc(callID).set({
      "callerID": currentUser.uid,
      "calleeID": widget.receiverID,
      "callerName": currentUser.email ?? currentUser.uid,
      "status": "calling", // initially calling
      "callType": isAudio ? "audio" : "video",
      "startTime": FieldValue.serverTimestamp(),
    });

    // Send push notification to callee
    final fcmToken = await _getReceiverFcmToken(widget.receiverID);
    if (fcmToken != null) {
      await NotificationHandler(context).sendCallNotification(
        fcmToken: fcmToken,
        title: "Incoming ${isAudio ? 'Audio' : 'Video'} Call",
        body: "From ${currentUser.email ?? currentUser.uid}",
        senderId: currentUser.uid,
        senderEmail: currentUser.email ?? currentUser.uid,
        channelName: callID,
        callType: isAudio ? "audio" : "video",
        notificationType: "call",
      );
    }

    // Navigate directly to CallPage
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallPage(
          callerID: currentUser.uid,
          callerName: currentUser.email ?? currentUser.uid,
          calleeID: widget.receiverID,
          callID: callID,
          isAudioCall: isAudio,
          isCaller: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColor.primaryColor,
        title: Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
              },
              child: Icon(Icons.arrow_back, color: Colors.white),
            ),
            SizedBox(width: 10),
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white24,
              backgroundImage:
                  (_receiverPhotoUrl != null && _receiverPhotoUrl!.isNotEmpty)
                  ? NetworkImage(_receiverPhotoUrl!)
                  : null,
              child: (_receiverPhotoUrl == null || _receiverPhotoUrl!.isEmpty)
                  ? Icon(Icons.person, size: 24, color: Colors.white)
                  : null,
            ),

            SizedBox(width: 8),
            Expanded(
              child: Text(
                _getTruncatedReceiverEmail(widget.receiverEmail),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // audio call
            IconButton(
              onPressed: () async {
                final currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser == null) return;
                await _startCall(isAudio: true);
              },
              icon: Icon(Icons.call, color: Colors.white),
            ),

            SizedBox(width: 20),
            //video call
            IconButton(
              onPressed: () async {
                final currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser == null) return;
                await _startCall(isAudio: false);
              },
              icon: Icon(Icons.video_call, color: Colors.white),
            ),
          ],
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
                  return Center(
                    child: CircularProgressIndicator(
                      color: AppColor.primaryColor,
                      strokeWidth: 2.5,
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text("Say hello!👋"));
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
                    RepliedMessageInfo? repliedMessageInfo;
                    if (data['repliedTo'] != null) {
                      repliedMessageInfo = RepliedMessageInfo.fromJson(
                        data['repliedTo'],
                      );
                    }

                    final message = Message(
                      sender: data['senderEmail'] ?? "Unknown user",
                      text: data['text'],
                      imageUrl: data["imageUrl"],
                      type: data['type'] ?? 'text',
                      isMe: data['senderId'] == currentUser.uid,
                      repliedTo: repliedMessageInfo,
                      fileName: data['fileName'],
                      publicId: data['publicId'],
                      isAudioCall: data['isAudioCall'],
                    );
                    return _buildMessageBubble(message, doc);
                  },
                );
              },
            ),
          ),
          _buildReplyPreview(),
          _isReceiverTyping
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 4.0,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "${widget.receiverEmail.split('@')[0]} is typing...",
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
          _buildMessageComposer(),
          Offstage(
            offstage: !_showEmojiPicker,
            child: SizedBox(
              height: 250,
              child: EmojiPicker(
                onBackspacePressed: () {},
                textEditingController: _textController,
                config: Config(
                  height: 256,
                  checkPlatformCompatibility: true,
                  emojiViewConfig: EmojiViewConfig(
                    backgroundColor: Colors.white,
                    emojiSizeMax:
                        28 *
                        (foundation.defaultTargetPlatform == TargetPlatform.iOS
                            ? 1.20
                            : 1.0),
                  ),
                  viewOrderConfig: const ViewOrderConfig(
                    top: EmojiPickerItem.categoryBar,
                    middle: EmojiPickerItem.emojiView,
                    bottom: EmojiPickerItem.searchBar,
                  ),
                  skinToneConfig: const SkinToneConfig(),
                  categoryViewConfig: const CategoryViewConfig(),
                  bottomActionBarConfig: const BottomActionBarConfig(),
                  searchViewConfig: const SearchViewConfig(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to generate Cloudinary video thumbnail
  String getVideoThumbnail(String videoUrl) {
    if (!videoUrl.contains("/upload/")) return "";
    return videoUrl
        .replaceFirst("/upload/", "/upload/so_0/")
        .replaceAll(".mp4", ".jpg");
  }

  // build messageBubble
  Widget _buildMessageBubble(Message message, DocumentSnapshot messageDoc) {
    final bool isMe = message.isMe;
    final data = messageDoc.data() as Map<String, dynamic>;

    Widget _buildRepliedMessageWidget(RepliedMessageInfo repliedInfo) {
      return Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.blue.shade50.withOpacity(0.5)
              : Colors.grey.shade300,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
          border: Border(
            left: BorderSide(
              color: isMe ? Colors.blue : Colors.grey.shade400,
              width: 4,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              repliedInfo.senderEmail.split('@')[0],
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isMe ? Colors.blue.shade800 : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              repliedInfo.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isMe ? Colors.black.withOpacity(0.7) : Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    // Determine the read status icon
    Widget? readStatusIcon;
    if (isMe) {
      if (data['isRead'] == true) {
        readStatusIcon = Icon(
          Icons.done_all,
          size: 16,
          color: AppColor.primaryColor,
        ); // Read
      } else {
        readStatusIcon = Icon(
          Icons.check,
          size: 16,
          color: Colors.grey,
        ); // Sent
      }
    }

    return GestureDetector(
      // onLongPress: isMe && message.type == 'text'
      //     ? () => _showEditDeleteOptions(messageDoc)
      //     : null,
      onLongPress: isMe ? () => _showEditDeleteOptions(messageDoc) : null,
      child: Dismissible(
        key: Key(messageDoc.id),
        direction: DismissDirection.startToEnd,
        onDismissed: (direction) {
          setState(() {
            _repliedMessageId = messageDoc.id;
            String replyContent = data['text'] ?? "";
            if (data['type'] == 'image') {
              replyContent = "📷 Image";
            } else if (data['type'] == 'video') {
              replyContent = "📹 Video";
            } else if (data['type'] == 'document') {
              replyContent = "📄 ${data['fileName'] ?? 'Document'}";
            }
            _repliedMessage = RepliedMessageInfo(
              content: replyContent,
              senderEmail: data['senderEmail'],
            );
          });
        },
        child: Column(
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
              padding: message.type == 'image' || message.type == "video"
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (message.repliedTo != null)
                    _buildRepliedMessageWidget(message.repliedTo!),
                  Padding(
                    padding: (message.repliedTo != null)
                        ? const EdgeInsets.fromLTRB(8, 0, 8, 8)
                        : EdgeInsets.zero,
                    child: message.type == "call"
                        ? Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent.shade100,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                                bottomLeft: isMe
                                    ? Radius.circular(20)
                                    : Radius.zero,
                                bottomRight: isMe
                                    ? Radius.zero
                                    : Radius.circular(20),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.call, color: Colors.white),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    data['message'] ??
                                        ((message.isAudioCall ?? true)
                                            ? "Audio Call"
                                            : "Video Call"),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : message.type == "image"
                        ? GestureDetector(
                            onTap: () {
                              if (message.imageUrl != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DisplayPictureScreen(
                                      imagePath: message.imageUrl!,
                                      onSend: null,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: ClipRRect(
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
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              color: AppColor.primaryColor,
                                            ),
                                          ),
                                        );
                                },
                              ),
                            ),
                          )
                        : message.type == "video"
                        ? GestureDetector(
                            onTap: () {
                              if (message.imageUrl != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DisplayVideoScreen(
                                      videoPath: message.imageUrl!,
                                      onSend: null,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15.0),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Image.network(
                                    getVideoThumbnail(message.imageUrl ?? ""),
                                    height: 200,
                                    width: 200,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 200,
                                      width: 200,
                                      color: Colors.black26,
                                    ),
                                  ),
                                  Icon(
                                    Icons.play_circle_fill,
                                    size: 50,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : message.type == "document"
                        ? GestureDetector(
                            onTap: () async {
                              if (message.imageUrl != null) {
                                final url = message.imageUrl!;
                                final fileName =
                                    message.fileName ?? 'document.pdf';

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Downloading $fileName..."),
                                  ),
                                );

                                try {
                                  final directory =
                                      await getApplicationSupportDirectory();
                                  final filePath =
                                      '${directory.path}/$fileName';
                                  Dio dio = Dio();
                                  print(
                                    "Attempting to download from URL: $url",
                                  );

                                  await dio.download(
                                    url,
                                    filePath,
                                    options: Options(
                                      validateStatus: (status) {
                                        return status != null &&
                                            status >= 200 &&
                                            status < 300;
                                      },
                                    ),
                                  );

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Opening $fileName..."),
                                    ),
                                  );
                                  final result = await OpenFilex.open(filePath);
                                  if (result.type != ResultType.done) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "Failed to open document: ${result.message}",
                                        ),
                                      ),
                                    );
                                    print(
                                      "Failed to open document: ${result.message}",
                                    );
                                  }
                                } on DioException catch (e) {
                                  // Catch Dio specific exceptions
                                  String errorMessage =
                                      "Error downloading document: ";
                                  if (e.response != null) {
                                    errorMessage +=
                                        "Status ${e.response!.statusCode}, Data: ${e.response!.data}";
                                  } else {
                                    errorMessage +=
                                        e.message ?? "Unknown Dio error";
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(errorMessage)),
                                  );
                                  print(errorMessage);
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Error downloading or opening document: ${e.toString()}",
                                      ),
                                    ),
                                  );
                                  print(
                                    "Error downloading or opening document: $e",
                                  );
                                }
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.all(12),
                              constraints: BoxConstraints(maxWidth: 200),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? Colors.white24
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.grey.shade400,
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.insert_drive_file,
                                    color: isMe
                                        ? Colors.white
                                        : AppColor.primaryColor,
                                  ),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      message.fileName ?? "Document",
                                      style: TextStyle(
                                        color: isMe
                                            ? Colors.white
                                            : Colors.black87,
                                        fontSize: 14,
                                        decoration: TextDecoration.underline,
                                        decorationColor: isMe
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : SelectableText(
                            message.text ?? "",
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                  ),
                  if (data['editedAt'] != null)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 2.0,
                        left: 4.0,
                        right: 4.0,
                      ),
                      child: Text(
                        ' (Edited)',
                        style: TextStyle(
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          color: isMe ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  if (readStatusIcon !=
                      null) // Display read status icon if available
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0, right: 4.0),
                      child: readStatusIcon,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  //build messageComposer
  Widget _buildMessageComposer() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.photo_camera, color: AppColor.primaryColor),
            onPressed: () async {
              setState(() {
                _showEmojiPicker = false;
              });
              final filePath = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CameraScreen()),
              );
              if (filePath == null) return;
              if (filePath != null) {
                final isVideo = filePath.endsWith(".mp4");
                if (isVideo) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DisplayVideoScreen(
                        videoPath: filePath,
                        onSend: (path) async {
                          await _sendCapturedVideo(path);
                        },
                      ),
                    ),
                  );
                } else {
                  if (filePath != null) {
                    await _sendCapturedImage(filePath);
                  }
                }
              }
            },
          ),
          IconButton(
            icon: Icon(
              Icons.attach_file_outlined,
              color: AppColor.primaryColor,
            ),
            onPressed: _isUploading
                ? null
                : () {
                    setState(() {
                      _showEmojiPicker = false;
                    });
                    // _sendImage();
                    _sendFile();
                  },
          ),
          // EMOJI BUTTON
          IconButton(
            icon: Icon(
              _showEmojiPicker ? Icons.keyboard : Icons.sentiment_satisfied_alt,
              color: AppColor.primaryColor,
            ),
            onPressed: () {
              setState(() {
                _showEmojiPicker = !_showEmojiPicker;
                if (_showEmojiPicker) {
                  FocusScope.of(context).unfocus();
                } else {
                  _emojiFocusNode.requestFocus();
                }
              });
            },
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _emojiFocusNode,
              onTap: () {
                if (_showEmojiPicker) {
                  setState(() {
                    _showEmojiPicker = false;
                  });
                }
              },
              onChanged: (text) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _debounce = Timer(const Duration(milliseconds: 500), () {
                  _setTypingStatus(text.isNotEmpty);
                });
              },
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
            onTap: _isUploading
                ? null
                : () {
                    _sendMessage(text: _textController.text);
                    _setTypingStatus(false);
                  },
            child: Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: AppColor.primaryColor,
                shape: BoxShape.circle,
              ),
              child: _editingMessageId != null
                  ? Icon(Icons.check, color: Colors.white)
                  : Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // build reply preview
  Widget _buildReplyPreview() {
    if (_repliedMessage == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _repliedMessage!.senderEmail,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _repliedMessage!.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () {
              setState(() {
                _repliedMessage = null;
                _repliedMessageId = null;
              });
            },
          ),
        ],
      ),
    );
  }
}
