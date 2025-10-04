import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_app/ChatService/chatService.dart';
import 'package:web_socket_app/utils/color.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import 'package:zego_uikit/zego_uikit.dart'; // Ensure this is imported
import 'package:zego_zimkit/zego_zimkit.dart'; // Ensure this is imported
import '../utils/setting/setting.dart'; // Your ZEGOCLOUD config

Widget customAvatarBuilder(
  BuildContext context,
  Size size,
  ZegoUIKitUser? user,
  Map extraInfo,
) {
  if (user == null) return const SizedBox();

  return CircleAvatar(
    radius: size.width / 2,
    backgroundImage: NetworkImage(
      'https://via.placeholder.com/${size.width.toInt()}',
    ), // Placeholder
  );
}

// Invite button widget

Widget sendCallingInvitationButton() {
  return StreamBuilder<List<ZegoUIKitUser>>(
    stream: ZegoUIKit().getUserListStream(),
    builder: (context, snapshot) {
      return ValueListenableBuilder<List<ZIMGroupMemberInfo>>(
        valueListenable: ZIMKit().queryGroupMemberList(
          '#${ZegoUIKit().getRoom().id}',
        ),
        builder: (context, members, _) {
          final memberIDsInCall = ZegoUIKit()
              .getRemoteUsers()
              .map((user) => user.id)
              .toList();

          final membersNotInCall = members.where((member) {
            if (member.userID == ZIMKit().currentUser()!.baseInfo.userID)
              return false;
            return !memberIDsInCall.contains(member.userID);
          }).toList();

          return ZegoSendCallingInvitationButton(
            avatarBuilder: customAvatarBuilder,
            selectedUsers: ZegoUIKit()
                .getRemoteUsers()
                .map((e) => ZegoCallUser(e.id, e.name))
                .toList(),
            waitingSelectUsers: membersNotInCall
                .map((member) => ZegoCallUser(member.userID, member.userName))
                .toList(),
          );
        },
      );
    },
  );
}

class ActiveGroupCallUI extends StatelessWidget {
  final String roomID;
  final String currentUserID;
  final String currentUserName;

  const ActiveGroupCallUI({
    super.key,
    required this.roomID,
    required this.currentUserID,
    required this.currentUserName,
  });

  @override
  Widget build(BuildContext context) {
    final callConfig = ZegoUIKitPrebuiltCallConfig.groupVideoCall();
    callConfig.topMenuBar.extendButtons = [
      SizedBox(
        width: 100,
        child: sendCallingInvitationButton(),
      ), // Invite button integrated
    ];
    callConfig.duration.isVisible = true; // Added duration visibility

    return Scaffold(
      body: ZegoUIKitPrebuiltCall(
        appID: ZegoConfig.appID,
        appSign: ZegoConfig.appSign,
        userID: currentUserID,
        userName: currentUserName,
        callID: roomID,
        config: callConfig,
        plugins: [ZegoUIKitSignalingPlugin()],
        events: ZegoUIKitPrebuiltCallEvents(
          onCallEnd: (reason, extendedData) {
            print("Call ended: $reason");
            Navigator.pop(context);
          },
          onError: (error) {
            print("Call error: ${error.code} - ${error.message}");
          },
          onHangUpConfirmation: (event, defaultAction) => defaultAction(),
        ),
      ),
    );
  }
}

class GroupCallSelectionScreen extends StatefulWidget {
  // final String? receiverEmail;
  // final String? receiverID;
  // final String? currentUserId;
  // final String? receiverUserId;
  // final String? currentUserEmail;

  const GroupCallSelectionScreen({
    super.key,
    // this.receiverEmail,
    // this.receiverID,
    // this.currentUserId,
    // this.receiverUserId,
    // this.currentUserEmail,
  });

  @override
  State<GroupCallSelectionScreen> createState() =>
      _GroupCallSelectionScreenState();
}

class _GroupCallSelectionScreenState extends State<GroupCallSelectionScreen> {
  final FirebaseDatabase _firebaseDatabase = FirebaseDatabase.instance;
  final User currentUser = FirebaseAuth.instance.currentUser!;
  List<Map<String, dynamic>> _selectedUsers = [];
  final ChatService chatService = ChatService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },

          icon: Icon(Icons.arrow_back, color: Colors.white),
        ),
        backgroundColor: AppColor.primaryColor,
        title: const Text(
          'CHATTER',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 25,
          ),
        ),
        actions: [
          const SizedBox(width: 10),
          if (_selectedUsers.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.call, color: Colors.white),
              onPressed: () {
                _startGroupCall(isAudio: true);
              },
            ),
          const SizedBox(width: 10),
          if (_selectedUsers.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.video_call, color: Colors.white),
              onPressed: () {
                _startGroupCall(isAudio: false);
              },
            ),
        ],
      ),
      body: StreamBuilder(
        stream: _firebaseDatabase.ref('presence').onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return const Center(child: Text("No users online"));
          }

          final data = Map<String, dynamic>.from(
            snapshot.data!.snapshot.value as Map,
          );
          final onlineUserIDs = <String>[];
          data.forEach((key, value) {
            if (value['isOnline'] == true && key != currentUser.uid) {
              onlineUserIDs.add(key);
            }
          });

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData || userSnapshot.data!.docs.isEmpty) {
                return const Center(child: Text("Loading user data..."));
              }

              final allUsers = userSnapshot.data!.docs.map((doc) {
                final userData = doc.data() as Map<String, dynamic>;
                return {
                  'uid': doc.id,
                  'email': userData['email'] ?? 'No Email',
                  'photoUrl': userData['photoUrl'] ?? '',
                };
              }).toList();

              final onlineUsersData = allUsers
                  .where((u) => onlineUserIDs.contains(u['uid']))
                  .toList();

              if (onlineUsersData.isEmpty) {
                return const Center(
                  child: Text("There are no other users online except you.।"),
                );
              }

              return ListView.builder(
                itemCount: onlineUsersData.length,
                itemBuilder: (context, index) {
                  final user = onlineUsersData[index];
                  final String userID = user['uid'];
                  final String userName = user['email'].split('@')[0];
                  final String photoUrl = user['photoUrl'] ?? '';

                  return CheckboxListTile(
                    secondary: CircleAvatar(
                      backgroundImage: (photoUrl.isNotEmpty)
                          ? NetworkImage(photoUrl)
                          : null,
                      child: (photoUrl.isEmpty)
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(userName),
                    value: _selectedUsers.any(
                      (selectedUser) => selectedUser['uid'] == userID,
                    ),
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedUsers.add(user);
                        } else {
                          _selectedUsers.removeWhere(
                            (selectedUser) => selectedUser['uid'] == userID,
                          );
                        }
                      });
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _startGroupCall({required bool isAudio}) async {
    if (_selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one member')),
      );
      return;
    }
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final String roomID = 'group_call_${DateTime.now().millisecondsSinceEpoch}';
    final String currentUserID = currentUser.uid;
    final String currentUserName = currentUser.email ?? currentUser.uid;

    ZegoUIKitPrebuiltCallInvitationService().send(
      invitees: _selectedUsers
          .map((user) => ZegoCallUser(user['uid'], user['email'].split('@')[0]))
          .toList(),
      callID: roomID,
      timeoutSeconds: 60,
      isVideoCall: !isAudio,
      notificationTitle: "Incoming ${isAudio ? 'Audio' : 'Video'} Call",
      notificationMessage: "From ${currentUser.email ?? currentUser.uid}",
    );

    for (var user in _selectedUsers) {
      await chatService.sendMessage(
        context: context,
        senderId: currentUserID,
        receiverId: user['uid'],
        message:
            "Group&${isAudio ? "📞 Audio Call" : "🎥 Video Call"} Call Started ",
        type: "group_call",
        isAudioCall: isAudio,
        callRoomID: roomID,
      );
    }

    // firebase document update
    await FirebaseFirestore.instance.collection('group_calls').doc(roomID).set({
      "callerID": currentUserID,
      "callerName": currentUserName,
      "members": _selectedUsers.map((user) => user['uid']).toList(),
      "callType": isAudio ? "audio" : "video",
      "startTime": FieldValue.serverTimestamp(),
      "status": "ongoing",
    });

    if (!mounted) {
      print("Widget unmounted, cannot perform navigation.");
      return; // Exit if the widget is no longer in the tree
    }

    // navigate to ActiveGroupCallUI
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
}
