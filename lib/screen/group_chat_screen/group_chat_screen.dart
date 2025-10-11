// lib/screen/group_chat_screen/group_chat_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:web_socket_app/model/message_model/message_model.dart'; // Ensure this model supports group messages
import 'package:web_socket_app/screen/camera/cameraScreen.dart';
import 'package:web_socket_app/screen/group_call_screen/group_call_screen.dart';
import 'package:web_socket_app/screen/photo_display_screen/photo_display_screen.dart';
import 'package:web_socket_app/screen/profileEditScreen/profileEditScreen.dart';
import 'package:web_socket_app/screen/video_display_screen/video_display_screen.dart';
import 'package:web_socket_app/service/group_chat_service/group_chat_service.dart';
import 'package:web_socket_app/utils/color.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

// Make sure this ChatService is updated to handle groups
// NEW: Dedicated service for group chats
import '../../notification_handle/notificationHandle.dart';
import '../add_member_screen/add_member_screen.dart';
import '../group_creation_screen/group_creation_screen.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String currentUserId;
  final List<String> groupMemberIds;
  final String? groupPhotoURL;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.currentUserId,
    required this.groupMemberIds,
    this.groupPhotoURL,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final GroupChatService _groupChatService = GroupChatService();
  final FirebaseFirestore _firebaseFirestore = FirebaseFirestore.instance;
  final FirebaseDatabase _realtimeDatabase = FirebaseDatabase.instance;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final User currentUser = FirebaseAuth.instance.currentUser!;

  bool _isUploading = false;
  RepliedMessageInfo? _repliedMessage;
  String? _editingMessageId;
  DatabaseReference? _typingStatusRef;
  StreamSubscription<DatabaseEvent>? _typingSubscription;
  Map<String, bool> _typingUsers = {};
  Timer? _debounce;
  bool _showEmojiPicker = false;
  final FocusNode _emojiFocusNode = FocusNode();

  final String cloudinaryApiKey = "911398349135266";
  final String CLOUDINARY_API_SECRET = "572xxi7X4yqr_3Y-wRcJ7EgJUJs";
  bool _isAdmin = false;
  bool _isMember = true;
  String? _groupPhotoURL;

  @override
  void initState() {
    super.initState();
    _emojiFocusNode.addListener(() {
      if (_emojiFocusNode.hasFocus) {
        setState(() {
          _showEmojiPicker = false;
        });
      }
    });

    _typingStatusRef = _realtimeDatabase.ref(
      'group_typing/${widget.groupId}/${currentUser.uid}',
    );
    _setupTypingListener();
    _checkAdminStatus();
    _checkMembership();
    _fetchGroupDetails();
    _markGroupMessagesAsRead();
  }

  Future<void> _checkAdminStatus() async {
    bool admin = await _groupChatService.isCurrentUserGroupAdmin(
      widget.groupId,
    );
    setState(() {
      _isAdmin = admin;
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _typingSubscription?.cancel();
    _setTypingStatus(false);
    _debounce?.cancel();
    _emojiFocusNode.dispose();
    super.dispose();
  }

  Future<void> _checkMembership() async {
    try {
      final doc = await _firebaseFirestore
          .collection('groups')
          .doc(widget.groupId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        List members = data['members'] ?? [];
        setState(() {
          _isMember = members.contains(currentUser.uid);
        });
      }
    } catch (e) {
      print("Error checking membership: $e");
    }
  }

  // Typing Indicator Logic
  void _setupTypingListener() {
    _realtimeDatabase.ref('group_typing/${widget.groupId}').onValue.listen((
      event,
    ) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        Map<String, bool> currentTypingUsers = {};

        data.forEach((userId, userTypingData) {
          if (userId != currentUser.uid && userTypingData != null) {
            final Map<String, dynamic> typingData = Map<String, dynamic>.from(
              userTypingData as Map,
            );
            final lastUpdated = typingData['timestamp'] as int?;
            if (lastUpdated != null &&
                (DateTime.now().millisecondsSinceEpoch - lastUpdated) < 5000) {
              currentTypingUsers[userId] = typingData['isTyping'] ?? false;
            }
          }
        });

        setState(() {
          _typingUsers = currentTypingUsers;
        });
      } else {
        setState(() {
          _typingUsers = {};
        });
      }
    });
  }

  // set typing status
  void _setTypingStatus(bool isTyping) {
    _typingStatusRef
        ?.set({'isTyping': isTyping, 'timestamp': ServerValue.timestamp})
        .catchError((error) {
          print("Failed to set typing status: $error");
        });
  }

  // fetch group details
  Future<void> _fetchGroupDetails() async {
    try {
      final groupDoc = await _firebaseFirestore
          .collection('groups')
          .doc(widget.groupId)
          .get();
      if (groupDoc.exists) {
        final data = groupDoc.data();
        setState(() {
          _groupPhotoURL = data?['groupPhotoURL'];
        });
      }
    } catch (e) {
      print("Error fetching group details: $e");
    }
  }

  //Message Sending Logic  groupChat screen
  Future<void> _sendMessage({
    String? text,
    String? imageUrl,
    String? type,
    String? fileName,
    String? publicId,
  }) async {
    final String currentText = text ?? _textController.text.trim();
    if (currentText.isEmpty && imageUrl == null && type == null) {
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
    });

    await _groupChatService.sendGroupMessage(
      groupId: widget.groupId,
      senderId: currentUser.uid,
      senderEmail: currentUser.email ?? 'Unknown',
      message: currentText.isNotEmpty ? currentText : null,
      imageUrl: imageUrl,
      type: type,
      repliedMessage: messageToReplay,
      fileName: fileName,
      publicId: publicId,
    );

    List<String> otherMemberIds = widget.groupMemberIds
        .where((id) => id != currentUser.uid)
        .toList();

    // Create a map to increment each other member's unread count
    Map<String, dynamic> unreadUpdates = {};
    for (String memberId in otherMemberIds) {
      unreadUpdates['unreadCounts.$memberId'] = FieldValue.increment(1);
    }

    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .update({
          // Apply all unread count increments for other members
          ...unreadUpdates,
          // Explicitly set current sender's unread count to 0 for this group
          'unreadCounts.${currentUser.uid}': 0,
        });

    print("Unread counts updated for group ${widget.groupId}.");
  }

  // File Upload Logic (Similar to ChatScreen but uses GroupChatService)
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

  // upload storage
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
        await _sendMessage(
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

  // image capture function
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
        await _sendMessage(
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

  // video capture function
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
        await _sendMessage(
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

  // Message Edit/Delete Logic (adapted for groups)
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

  // edit message method
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

  Future<void> _editMessage(String messageId, String newText) async {
    try {
      await _firebaseFirestore
          .collection('groups')
          .doc(widget.groupId)
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

  // delete function
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
            .collection('groups')
            .doc(widget.groupId)
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

  // file delete from Cloudinary
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
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
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

  // Function to mark group messages as read
  Future<void> _markGroupMessagesAsRead() async {
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .update({
          'unreadCounts.${widget.currentUserId}':
              0, // Set current user's unread count to 0
        });
  }

  /// Generate a unique channel ID for the group call
  String _generateChannelId() {
    final random = Random();
    return 'group_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(10000)}';
  }

  /// Start group call
  Future<void> _startDirectGroupCall({required bool isAudio}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final currentUserID = currentUser.uid;
    final currentUserName = currentUser.email ?? currentUserID;

    // Get all online users from Firebase Realtime Database
    final dbSnapshot = await FirebaseDatabase.instance.ref('presence').get();
    if (!dbSnapshot.exists) {
      print("No online users found.");
      return;
    }

    final data = Map<String, dynamic>.from(dbSnapshot.value as Map);
    final onlineUserIDs = data.entries
        .where(
          (entry) =>
              entry.value['isOnline'] == true && entry.key != currentUserID,
        )
        .map((e) => e.key)
        .toList();

    if (onlineUserIDs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other online users to call.')),
      );
      return;
    }

    // Generate room ID
    final roomID = 'group_call_${DateTime.now().millisecondsSinceEpoch}';

    //  Send Zego invitations
    ZegoUIKitPrebuiltCallInvitationService().send(
      invitees: onlineUserIDs
          .map(
            (uid) => ZegoCallUser(uid, uid),
          ) // use UID as name for simplicity
          .toList(),
      callID: roomID,
      timeoutSeconds: 60,
      isVideoCall: !isAudio,
      notificationTitle: "Incoming ${isAudio ? 'Audio' : 'Video'} Call",
      notificationMessage: "From $currentUserName",
    );

    //  Send FCM notifications
    final notificationHandler = NotificationHandler(context);
    for (String uid in onlineUserIDs) {
      String? fcmToken = await _getReceiverFcmToken(uid);
      if (fcmToken != null) {
        await notificationHandler.sendGroupCallNotification(
          fcmToken: fcmToken,
          title: '📞 Incoming Group ${isAudio ? 'Audio' : 'Video'} Call',
          body: '$currentUserName is calling you',
          senderId: currentUserID,
          senderEmail: currentUser.email ?? currentUserID,
          channelName: roomID,
          callType: isAudio ? 'audio' : 'video',
          notificationType: 'call',
          receiverId: uid,
          inviteeIDs: onlineUserIDs,
        );
      }
    }

    // send group message
    await _groupChatService.sendGroupMessage(
      groupId: widget.groupId,
      senderId: currentUser.uid,
      senderEmail: currentUser.email ?? 'Unknown',
      message: isAudio ? "📞 Audio Call" : "🎥 Video Call",
      //imageUrl: imageUrl,
      type: "call",
      //repliedMessage: messageToReplay,
      // fileName: fileName,
      // publicId: publicId,
      isAudioCall: true,
      isVideoCall: true,
    );

    //  Log call in Firestore
    await FirebaseFirestore.instance.collection('group_calls').doc(roomID).set({
      "callerID": currentUserID,
      "callerName": currentUserName,
      "members": onlineUserIDs,
      "callType": isAudio ? "audio" : "video",
      "startTime": FieldValue.serverTimestamp(),
      "status": "ongoing",
    });

    // //  Navigate to active call screen
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ActiveGroupCallUI(
          roomID: roomID,
          currentUserID: currentUserID,
          currentUserName: currentUserName,
        ),
      ),
    );
  }

  // received fcm token
  Future<String?> _getReceiverFcmToken(String receiverId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['fcmToken'] as String?;
      }
    } catch (e) {
      print('Error fetching FCM token: $e');
    }
    return null;
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
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroupCreationScreen(
                      groupId: widget.groupId,
                      groupName: widget
                          .groupName, // Pass current group name for pre-filling
                      isEditing: true, // Indicate that it's for editing
                      // You might also need to pass existing group members, etc.
                    ),
                  ),
                );
              },
              child: CircleAvatar(
                backgroundImage:
                    (_groupPhotoURL != null && _groupPhotoURL!.isNotEmpty)
                    ? NetworkImage(_groupPhotoURL!) // Use group's photo URL
                    : null,
                child: (_groupPhotoURL == null || _groupPhotoURL!.isEmpty)
                    ? Icon(
                        Icons.group,
                        size: 40,
                        color: Colors.white,
                      ) // Default group icon
                    : null,
                backgroundColor: AppColor
                    .primaryColor, // Or a suitable group background color
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.groupName,
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
                await _startDirectGroupCall(isAudio: true);
              },
              icon: Icon(Icons.call, color: Colors.white),
            ),

            //video call button
            IconButton(
              style: IconButton.styleFrom(fixedSize: const Size(48, 48)),
              onPressed: () async {
                final currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser == null) return;
                await _startDirectGroupCall(isAudio: false);
              },
              icon: Icon(Icons.video_call, color: Colors.white),
            ),

            // more vote iconButton
            IconButton(
              style: IconButton.styleFrom(fixedSize: const Size(48, 48)),
              onPressed: () async {
                _showGroupOptions(); // Call the new method here
              },
              icon: Icon(Icons.more_vert, color: Colors.white),
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
                  .collection("groups")
                  .doc(widget.groupId)
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
                  return Center(child: Text("Say hello to your group! 👋"));
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
                      isAudioCall:
                          data['isAudioCall'], // Group calls are not directly handled here, so this might be null
                    );
                    return _buildMessageBubble(message, doc);
                  },
                );
              },
            ),
          ),
          _buildReplyPreview(),
          _buildTypingIndicator(),
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

  Widget _buildTypingIndicator() {
    if (_typingUsers.isEmpty) return const SizedBox.shrink();

    // Fetch member info to get names from UIDs
    return FutureBuilder<DocumentSnapshot>(
      future: _firebaseFirestore.collection('groups').doc(widget.groupId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }
        final groupData = snapshot.data!.data() as Map<String, dynamic>;
        final memberInfo = Map<String, dynamic>.from(
          groupData['memberInfo'] ?? {},
        );

        List<String> typingNames = [];
        _typingUsers.forEach((uid, isTyping) {
          if (isTyping) {
            final email = memberInfo[uid]?['email'] ?? uid;
            typingNames.add(email.split('@')[0]);
          }
        });

        if (typingNames.isEmpty) return const SizedBox.shrink();

        String typingText;
        if (typingNames.length == 1) {
          typingText = "${typingNames.first} is typing...";
        } else if (typingNames.length == 2) {
          typingText =
              "${typingNames.first} and ${typingNames.last} are typing...";
        } else {
          typingText =
              "${typingNames.first} and ${typingNames.length - 1} others are typing...";
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              typingText,
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ),
        );
      },
    );
  }

  String getVideoThumbnail(String videoUrl) {
    if (!videoUrl.contains("/upload/")) return "";
    return videoUrl
        .replaceFirst("/upload/", "/upload/so_0/")
        .replaceAll(".mp4", ".jpg");
  }

  // Same _buildMessageBubble as in ChatScreen, but sender name is always displayed
  Widget _buildMessageBubble(Message message, DocumentSnapshot messageDoc) {
    final bool isMe = message.isMe;
    final data = messageDoc.data() as Map<String, dynamic>;
    final bool isSystemMessage =
        data['isSystemMessage'] ?? false; // Get the system message flag
    String? systemAdminName;
    bool isMessageFromAdmin = false;

    if (isSystemMessage) {
      // For system messages, the actual senderId is stored if it's an admin action
      final String? potentialAdminId = data['senderId'];
      if (potentialAdminId != null && potentialAdminId != 'system') {
        // Check if it's not the generic 'system' sender
        // You'll need a way to get the admin's name/email based on potentialAdminId
        // This might require fetching user details or pre-populating a map
        // For simplicity, let's assume senderEmail for system message will contain admin's email
        // or you can fetch it from _groupChatService.getGroupMembersDetails
        final String? systemSenderEmail = data['senderEmail'];
        if (systemSenderEmail != null &&
            systemSenderEmail != 'system@app.com') {
          systemAdminName = systemSenderEmail.split('@')[0];
          isMessageFromAdmin = true;
        }
      }
    }

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

    return GestureDetector(
      // onLongPress: isMe ? () => _showEditDeleteOptions(messageDoc) : null,
      onLongPress: isMe && !isSystemMessage
          ? () => _showEditDeleteOptions(messageDoc)
          : null,
      child: Dismissible(
        key: Key(messageDoc.id),
        direction: DismissDirection.startToEnd,
        onDismissed: isSystemMessage
            ? null
            : (direction) {
                setState(() {
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
            if (!isSystemMessage)
              Padding(
                padding: const EdgeInsets.only(left: 10, right: 10, bottom: 4),
                child: Text(
                  message.sender.split(
                    '@',
                  )[0], // Display sender name for all messages in group
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            if (isSystemMessage)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 16.0,
                  ),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          data['text'] ??
                              "System message", // Display the system message content
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.black54,
                          ),
                        ),
                        if (isMessageFromAdmin && systemAdminName != null)
                          Row(
                            children: [
                              Text(
                                " by $systemAdminName",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.black54,
                                ),
                              ),
                              Container(
                                margin: EdgeInsets.only(left: 4),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColor.primaryColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  "Admin",
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: AppColor.primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              )
            else
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
                      child:
                          message.type ==
                              "call" // Group calls might not use this bubble type
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
                            ) // Or handle group call UI
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
                                            height:
                                                200, // Match the image height
                                            width: 200, // Match the image width
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                color: AppColor
                                                    .primaryColor, // Use your app's primary color
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
                                        onSend:
                                            null, // No send functionality from display screen here
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
                                      getVideoThumbnail(
                                        message.imageUrl ?? "",
                                      ), // Function to get video thumbnail
                                      height: 200,
                                      width: 200,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        height: 200,
                                        width: 200,
                                        color: Colors
                                            .black26, // Placeholder if thumbnail fails
                                        child: Icon(
                                          Icons.videocam_off,
                                          color: Colors.white,
                                          size: 50,
                                        ),
                                      ),
                                      loadingBuilder: (context, child, progress) {
                                        return progress == null
                                            ? child
                                            : SizedBox(
                                                height: 200,
                                                width: 200,
                                                child: Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: AppColor
                                                            .primaryColor,
                                                      ),
                                                ),
                                              );
                                      },
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
                                    final result = await OpenFilex.open(
                                      filePath,
                                    );
                                    if (result.type != ResultType.done) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
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
                    // if (readStatusIcon !=
                    //     null) // Display read status icon if available
                    //   Padding(
                    //     padding: const EdgeInsets.only(top: 4.0, right: 4.0),
                    //     child: readStatusIcon,
                    //   ),
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
          // camera button
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

          // file button
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
          // send button
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
                _repliedMessage = null;
              });
            },
          ),
        ],
      ),
    );
  }

  // show group details
  void _showGroupOptions() {
    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (_isAdmin)
                // add member options
                ListTile(
                  leading: Icon(Icons.person_add, color: AppColor.primaryColor),
                  title: const Text('Add Member'),
                  onTap: () async {
                    Navigator.pop(context); // Close the bottom sheet
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddMembersScreen(
                          groupId: widget.groupId,
                          groupName: widget.groupName,
                          currentUserId: widget.currentUserId,
                        ),
                      ),
                    );
                    // Refresh admin status just in case
                    _checkAdminStatus();
                  },
                ),
              // Remove member option
              ListTile(
                leading: const Icon(
                  Icons.person_remove,
                  color: Colors.redAccent,
                ),
                title: const Text('Remove Member'),
                onTap: () {
                  Navigator.pop(context); // Close the bottom sheet
                  _showRemoveMemberDialog();
                },
              ),

              ListTile(
                leading: Icon(Icons.people, color: AppColor.primaryColor),
                title: const Text('View Members'),
                onTap: () {
                  Navigator.pop(context); // Close the bottom sheet
                  _showViewMembersDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // remove member dialog
  Future<void> _showRemoveMemberDialog() async {
    final List<Map<String, dynamic>> members = await _groupChatService
        .getGroupMembersDetails(widget.groupId);
    // Filter out the current user and the admin (who can't remove themselves easily)
    final removableMembers = members
        .where((m) => m['uid'] != currentUser.uid)
        .toList();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Remove Member'),
          content: SizedBox(
            width: double.maxFinite,
            child: removableMembers.isEmpty
                ? const Text('No other members to remove.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: removableMembers.length,
                    itemBuilder: (context, index) {
                      final member = removableMembers[index];
                      final String? photoUrl = member['photoUrl'];
                      final String name = member['name']?.isNotEmpty == true
                          ? member['name']
                          : member['email']?.split('@')[0] ?? 'User';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              (photoUrl != null && photoUrl.isNotEmpty)
                              ? NetworkImage(photoUrl)
                              : null,
                          backgroundColor: AppColor.primaryColor,
                          child: (photoUrl == null || photoUrl.isEmpty)
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white),
                                )
                              : null,
                        ),
                        subtitle: Text(member['email'] ?? ""),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            // Confirmation dialog for removal
                            bool? confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: Colors.white,
                                title: const Text('Confirm Removal'),
                                content: Text(
                                  'Are you sure you want to remove ${member['name']}?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text(
                                      'Remove',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              try {
                                await _groupChatService.removeGroupMember(
                                  groupId: widget.groupId,
                                  userId: member['uid'],
                                  removerId: "",
                                  removerEmail: '',
                                  removedMemberName: '',
                                );
                                if (mounted) {
                                  Navigator.pop(context);
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${member['name']} removed.',
                                      ),
                                    ),
                                  );
                                  // Re-open the dialog to show updated list
                                  _showRemoveMemberDialog();
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to remove member: $e',
                                      ),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // view member dialog
  Future<void> _showViewMembersDialog() async {
    final List<Map<String, dynamic>> members = await _groupChatService
        .getGroupMembersDetails(widget.groupId);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          elevation: 50,
          backgroundColor: Colors.white,
          title: const Text('Group Members'),
          content: SizedBox(
            width: 300,
            child: members.isEmpty
                ? const Text('No members in this group.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final member = members[index];
                      final String? photoUrl = member['photoUrl'];
                      final String name = member['name']?.isNotEmpty == true
                          ? member['name']
                          : member['email']?.split('@')[0] ?? 'User';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              (photoUrl != null && photoUrl.isNotEmpty)
                              ? NetworkImage(photoUrl)
                              : null,
                          backgroundColor: AppColor.primaryColor,
                          child: (photoUrl == null || photoUrl.isEmpty)
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white),
                                )
                              : null,
                        ),
                        title: Text(member['email'] ?? ""),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
