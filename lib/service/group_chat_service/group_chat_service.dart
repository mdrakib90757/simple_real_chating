import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:web_socket_app/model/message_model/message_model.dart';

class GroupChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User currentUser = FirebaseAuth
      .instance
      .currentUser!; // Ensure currentUser is always available

  // Consolidated sendGroupMessage to handle all message types, including system
  Future<void> sendGroupMessage({
    required String groupId,
    required String senderId,
    required String senderEmail,
    String? message,
    String? imageUrl,
    String? type,
    RepliedMessageInfo? repliedMessage,
    String? fileName,
    String? publicId,
    bool isAudioCall = false, // Not nullable here, so can use directly
    bool isVideoCall = false, // Not nullable here, so can use directly
    bool isSystemMessage = false,
  }) async {
    final Timestamp timestamp = Timestamp.now();

    String senderDisplayName;
    String actualSenderEmail; // To store the email even for system messages
    String actualSenderId; // To store the ID even for system messages

    if (isSystemMessage) {
      senderDisplayName = "System";
      actualSenderId = "system"; // A special ID for system messages
      actualSenderEmail =
          "system@app.com"; // A special email for system messages
    } else {
      // Fetch sender's name for regular messages
      final senderDoc = await _firestore
          .collection('users')
          .doc(senderId)
          .get();
      senderDisplayName =
          senderDoc.data()?['name'] ?? senderEmail.split('@')[0];
      actualSenderId = senderId;
      actualSenderEmail = senderEmail;
    }

    // Determine the content for the 'last_message' field based on message type
    String lastMessageContent = "";
    if (isSystemMessage && message != null) {
      // System messages use their 'message' parameter as content
      lastMessageContent = message;
    } else if (message != null && message.isNotEmpty) {
      lastMessageContent = message;
    } else if (type == "image") {
      lastMessageContent = "📷 Image";
    } else if (type == "video") {
      lastMessageContent = "📹 Video";
    } else if (type == "document") {
      lastMessageContent = "📄 ${fileName ?? 'Document'}";
    } else if (type == "call") {
      // For calls, use isAudioCall/isVideoCall directly
      lastMessageContent = isAudioCall ? "📞 Audio Call" : "🎥 Video Call";
    } else {
      lastMessageContent = "New message"; // Fallback for unknown types
    }

    // Prepare the message data to be added to the subcollection
    final messageData = {
      'text':
          message, // This 'message' parameter is used for regular text or system message content
      'imageUrl': imageUrl,
      'type': type ?? (imageUrl != null ? 'image' : 'text'), // Fallback type
      'senderId': actualSenderId,
      'senderEmail': actualSenderEmail,
      'senderName': senderDisplayName, // Store the display name
      'timestamp': timestamp,
      'repliedTo': repliedMessage?.toJson(),
      'fileName': fileName,
      'publicId': publicId,
      'isAudioCall': isAudioCall,
      'isVideoCall': isVideoCall,
      'isSystemMessage': isSystemMessage, // Crucial for UI differentiation
    };

    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    final List<String> groupMembers = List<String>.from(groupDoc.data()?['members'] ?? []);

    Map<String, dynamic> unreadUpdates = {};
    for (String memberId in groupMembers) {
      // Increment unread count for all members EXCEPT the sender
      if (memberId != actualSenderId) {
        unreadUpdates['unreadCounts.$memberId'] = FieldValue.increment(1);
      } else {
        // Explicitly set sender's unread count to 0, in case it was non-zero for some reason
        unreadUpdates['unreadCounts.$memberId'] = 0;
      }
    }

    // Add message to the subcollection
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .add(messageData);

    // Update the parent group document with the last message info
    await _firestore.collection('groups').doc(groupId).update({
      'last_message': lastMessageContent,
      'lastMessageSenderName': senderDisplayName,
      'last_message_timestamp': timestamp,
      'lastMessageSentByEmail': actualSenderEmail,
      'lastMessageSenderId': actualSenderId,
    });
  }

  // Your addGroupMember method (looks fine)
  Future<void> addGroupMember({
    required String groupId,
    required String userId,
    required String userEmail,
    required String userName,
    String? photoUrl,
  }) async {
    try {
      final groupRef = _firestore.collection('groups').doc(groupId);
      await groupRef.update({
        'members': FieldValue.arrayUnion([userId]),
        'memberInfo.$userId': {
          'email': userEmail,
          'name': userName,
          'photoUrl': photoUrl,
        },
      });
      final adminUser = currentUser;
      final adminName =
          adminUser.displayName ?? adminUser.email?.split('@')[0] ?? 'Admin';

      // Send a system message when a member is added
      await sendGroupMessage(
        groupId: groupId,
        senderId: 'system', // Special ID for system
        senderEmail: 'system@app.com', // Special email for system
        isSystemMessage: true,
        message: "$userName was added to the group.",
        type: 'system',
      );

      print('User $userName ($userId) added to group $groupId');
    } catch (e) {
      print('Error adding group member: $e');
      rethrow;
    }
  }

  // Modified removeGroupMember to use the consolidated sendGroupMessage
  Future<void> removeGroupMember({
    required String groupId,
    required String userId,
    required String removerId,
    required String removerEmail,
    required String removedMemberName,
  }) async {
    try {
      final groupRef = _firestore.collection('groups').doc(groupId);

      await groupRef.update({
        'members': FieldValue.arrayRemove([userId]),
        'memberInfo.$userId': FieldValue.delete(), // Remove specific user info
      });

      // Use the consolidated sendGroupMessage for system message
      await sendGroupMessage(
        groupId: groupId,
        senderId: removerId,
        //senderId: 'system', // Special ID for system
        senderEmail: removerEmail, // Special email for system
        isSystemMessage: true,
        // message should contain the full text for the system message
        message: "$removedMemberName was removed from the group.",
        type: 'system',
      );

      print('User $userId removed from group $groupId');
    } catch (e) {
      print('Error removing group member: $e');
      rethrow;
    }
  }

  // DEPRECATED: remove sendSystemMessage, as its functionality is now in sendGroupMessage
  // Future<void> sendSystemMessage({required String groupId, required String text}) async {
  //   await _firestore
  //       .collection('groups')
  //       .doc(groupId)
  //       .collection('messages')
  //       .add({
  //     'text': text,
  //     'type': 'system',
  //     'senderId': 'system',
  //     'timestamp': FieldValue.serverTimestamp(),
  //   });
  // }

  // ... (rest of your methods: getPotentialMembers, getGroupMembersDetails, isCurrentUserGroupAdmin)
  Future<List<Map<String, dynamic>>> getPotentialMembers(
    String groupId,
    String currentUserId,
  ) async {
    try {
      // Get current group members
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      final groupMembers = List<String>.from(groupDoc.data()?['members'] ?? []);

      // Get all users
      final allUsersSnapshot = await _firestore.collection('users').get();
      final List<Map<String, dynamic>> potentialMembers = [];

      for (var doc in allUsersSnapshot.docs) {

        // if (doc.id == currentUserId) continue; // Don't add current user
        // if (groupMembers.contains(doc.id))
        //   continue; // Don't add existing members

        final userData = doc.data();
        final String userId = doc.id;
        final String userEmail = userData['email'] ?? 'No Email';
        // Safely get name, falling back to email prefix if name is null or empty
        final String userName = userData['name']?.isNotEmpty == true
            ? userData['name']!
            : userEmail.split('@')[0];

        // Filter: Don't add current user AND don't add existing members
        if (userId == currentUserId) continue;
        if (groupMembers.contains(userId)) continue;

        potentialMembers.add({
          'uid': userId,
          'email': userEmail,
          'name': userName,
          'fcmTokens': userData['fcmTokens'], // It's likely 'fcmTokens' (plural) and an array
          'photoUrl': userData['photoUrl'],
        });
      }
      return potentialMembers;
    } catch (e) {
      print('Error getting potential members: $e');
      return [];
    }
  }

  // Helper to get group members details
  Future<List<Map<String, dynamic>>> getGroupMembersDetails(String groupId,) async {
    try {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) return [];

      final List<String> memberIds = List<String>.from(
        groupDoc.data()?['members'] ?? [],
      );
      final Map<String, dynamic> memberInfo =
          groupDoc.data()?['memberInfo'] ?? {};

      final List<Map<String, dynamic>> membersDetails = [];
      for (String memberId in memberIds) {
        if (memberInfo.containsKey(memberId)) {
          membersDetails.add({
            'uid': memberId,
            'email': memberInfo[memberId]['email'],
            'name': memberInfo[memberId]['name'],
            'photoUrl': memberInfo[memberId]['photoUrl'],
          });
        } else {
          // Fallback if memberInfo is missing for some reason
          final userDoc = await _firestore
              .collection('users')
              .doc(memberId)
              .get();
          if (userDoc.exists) {
            membersDetails.add({
              'uid': userDoc.id,
              'email': userDoc.data()?['email'],
              'name':
                  userDoc.data()?['name'] ??
                  userDoc.data()?['email'].split('@')[0],
              'photoUrl': userDoc.data()?['photoUrl'],
            });
          }
        }
      }
      return membersDetails;
    } catch (e) {
      print('Error getting group members details: $e');
      return [];
    }
  }

  // Helper to check if current user is admin (assuming creator is admin)
  Future<bool> isCurrentUserGroupAdmin(String groupId) async {
    try {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      final String? creatorId = groupDoc
          .data()?['creatorId']; // Assuming you store creatorId
      return creatorId == currentUser.uid;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }
}
