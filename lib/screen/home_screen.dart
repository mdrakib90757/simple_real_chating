import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_app/screen/profileEditScreen/profileEditScreen.dart';
import 'package:web_socket_app/utils/color.dart';
import '../widgets/custom_search_delegate/custom_search_delegate.dart';
import 'auth_screen/signIn_screen.dart';
import 'chat_screen.dart';

enum MenuOption { onlineUsers, settings, profile }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final FirebaseDatabase _firebaseDatabase = FirebaseDatabase.instance;
  final User currentUser = FirebaseAuth.instance.currentUser!;
  String? _currentToken;
  List<Map<String, dynamic>> _chatListData = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateUserStatus(isOnline: true);
    print("Current user photo URL is: ${currentUser.photoURL}");
    _initializeUserAndNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateUserStatus(isOnline: true);
    } else {}
  }

  void _updateUserStatus({required bool isOnline}) {
    final userStatusRef = _firebaseDatabase.ref("presence/${currentUser.uid}");
    final status = {
      'isOnline': isOnline,
      'last_seen': ServerValue.timestamp,
      'email': currentUser.email,
    };
    if (isOnline) {
      userStatusRef.onDisconnect().set({
        'isOnline': false,
        'last_seen': ServerValue.timestamp,
        'email': currentUser.email,
      });
    }
    userStatusRef.set(status);
  }

  void _initializeUserAndNotifications() async {
    _updateUserStatus(isOnline: true);
    await createUserIfNotExists();
    await saveFCMToken();
  }

  Future<void> saveFCMToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));

      print("FCM token saved for user: ${user.uid}");
    }
  }

  /// Create Firestore user if not exists
  Future<void> createUserIfNotExists() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!userDoc.exists) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': user.email,
        'fcmTokens': [],
        'createdAt': FieldValue.serverTimestamp(),
      });
      print("User created in Firestore: ${user.uid}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColor.primaryColor,
        leading: Builder(
          builder: (context) => IconButton(
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
            icon: Icon(Icons.menu, color: Colors.white),
          ),
        ),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Text(
            //   currentUser.email ?? "No Email",
            //   style: TextStyle(fontSize: 15, color: Colors.white),
            // ),
            Text(
              'CHATTER',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ReusableSearchWidget(
            //   hintText: "Search chats",
            //   items: _chatListData,
            //   itemToString: (item) => item['email'],
            //   onItemSelected: (item) {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (_) => ChatScreen(
            //           receiverEmail: item['email'],
            //           receiverID: item['id'],
            //           currentUserId: currentUser.uid,
            //           receiverUserId: item['id'],
            //         ),
            //       ),
            //     );
            //   },
            // ),
            _buildOnlineUsersList(),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Chats",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            buildChatList(),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(
                "",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
              ),
              accountEmail: Text(
                currentUser.email ?? "No Email",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundImage:
                    (currentUser.photoURL != null &&
                        currentUser.photoURL!.isNotEmpty)
                    ? NetworkImage(currentUser.photoURL!)
                    : null,
                child:
                    (currentUser.photoURL == null ||
                        currentUser.photoURL!.isEmpty)
                    ? Icon(Icons.person, size: 40, color: AppColor.primaryColor)
                    : null,
              ),
              decoration: BoxDecoration(color: AppColor.primaryColor),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text("Edit Profile"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileEditScreen(),
                  ),
                );
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.exit_to_app),
              onTap: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;
                try {
                  final token = await FirebaseMessaging.instance.getToken();

                  if (token != null) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({
                          'fcmTokens': FieldValue.arrayRemove([token]),
                        });
                    print("FCM token removed on logout.");
                  }

                  await FirebaseAuth.instance.signOut();

                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                      (Route<dynamic> route) => false,
                    );
                  }
                } catch (e) {
                  print("Error during logout: $e");
                }
              },
              title: Text("Logout"),
              subtitle: Text("sign out of this account"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlineUsersList() {
    return SizedBox(
      height: 125,
      child: StreamBuilder(
        stream: _firebaseDatabase.ref('presence').onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return Center(child: Text("No users online"));
          }

          final data = Map<String, dynamic>.from(
            snapshot.data!.snapshot.value as Map,
          );
          final onlineUsersUids = <String>[];
          data.forEach((key, value) {
            if (value['isOnline'] == true && key != currentUser.uid) {
              onlineUsersUids.add(key);
            }
          });

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData || userSnapshot.data!.docs.isEmpty) {
                return Center(child: Text("No user data"));
              }

              final allUsers = userSnapshot.data!.docs.map((doc) {
                final userData = doc.data() as Map<String, dynamic>;
                return {
                  'uid': doc.id,
                  'email': userData['email'] ?? 'No Email',
                  'photoUrl': userData['photoUrl'] ?? '',
                };
              }).toList();

              // Logged-in user first
              final currentUserData = allUsers.firstWhere(
                (u) => u['uid'] == currentUser.uid,
                orElse: () => {
                  'uid': currentUser.uid,
                  'email': currentUser.email ?? "User",
                  'photoUrl': currentUser.photoURL ?? '',
                },
              );

              final onlineUsers = allUsers
                  .where((u) => onlineUsersUids.contains(u['uid']))
                  .toList();

              final usersList = [currentUserData, ...onlineUsers];

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: usersList.length,
                //  padding: EdgeInsets.symmetric(horizontal: 5, vertical: 8),
                itemBuilder: (context, index) {
                  final user = usersList[index];
                  final uid = user['uid'];
                  final email = user['email'];
                  final photoUrl = user['photoUrl'];
                  final bool isCurrentUser = uid == currentUser.uid;

                  return GestureDetector(
                    onTap: () async {
                      if (isCurrentUser) {
                        // Navigator.push(
                        //   context,
                        //   MaterialPageRoute(
                        //     builder: (context) => const ProfileEditScreen(),
                        //   ),
                        // );
                        return;
                      }

                      final receiverUserDoc = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .get();
                      if (!receiverUserDoc.exists) {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .set({
                              'email': email,
                              'fcmTokens': [],
                              'createdAt': FieldValue.serverTimestamp(),
                              'photoUrl':
                                  photoUrl, // Use the photoUrl we already have
                            }, SetOptions(merge: true));
                        print("Receiver user entry ensured in Firestore: $uid");
                      }

                      // Prepare participant info for the chat room
                      final String? currentUserPhotoUrl =
                          FirebaseAuth.instance.currentUser!.photoURL;
                      final String? receiverPhotoUrl = photoUrl;

                      final Map<String, dynamic> participantInfo = {
                        currentUser.uid: {
                          'email': currentUser.email,
                          'photoUrl': currentUserPhotoUrl,
                        },
                        uid: {'email': email, 'photoUrl': receiverPhotoUrl},
                      };

                      // Update chat room with participant info (important for chat list display)
                      await _updateChatRoomParticipantInfo(
                        currentUserId: currentUser.uid,
                        receiverId: uid,
                        participantInfo: participantInfo,
                      );

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            currentUserEmail:
                                FirebaseAuth.instance.currentUser!.email!,
                            receiverEmail: email,
                            receiverID: uid,
                            currentUserId: currentUser.uid,
                            receiverUserId: uid,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: isCurrentUser ? 35 : 30,
                                  backgroundColor: AppColor.primaryColor,

                                  backgroundImage:
                                      (photoUrl != null && photoUrl.isNotEmpty)
                                      ? NetworkImage(photoUrl)
                                      : null,
                                  child: (photoUrl == null || photoUrl.isEmpty)
                                      ? Icon(
                                          Icons.person,
                                          size: isCurrentUser ? 35 : 25,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              ),
                              if (!isCurrentUser) // green dot for online users only
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 5),
                          Text(
                            email.split('@')[0],
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                            ), // Consistent font size
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // Widget buildChatList() {
  //   final String currentUserId = currentUser.uid;
  //   return StreamBuilder<QuerySnapshot>(
  //     stream: FirebaseFirestore.instance
  //         .collection('chat_rooms')
  //         .where('participants', arrayContains: currentUserId)
  //         .orderBy('last_message_timestamp', descending: true)
  //         .snapshots(),
  //     builder: (context, snapshot) {
  //       if (!snapshot.hasData) {
  //         return Center(child: CircularProgressIndicator());
  //       }
  //
  //       final chatDocs = snapshot.data!.docs;
  //
  //
  //       _chatListData = chatDocs.map((doc) {
  //         final data = doc.data() as Map<String, dynamic>;
  //         final participants = List<String>.from(data['participants']);
  //         final otherUserId = participants.firstWhere((id) => id != currentUserId);
  //         final otherUserInfo = data['participant_info'][otherUserId];
  //         return {
  //           'id': otherUserId,
  //           'email': otherUserInfo['email'],
  //           'photoUrl': otherUserInfo['photoUrl'],
  //         };
  //       }).toList();
  //
  //
  //       if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
  //         return Center(
  //           child: Column(
  //             mainAxisAlignment: MainAxisAlignment.center,
  //             children: [
  //               Icon(
  //                 Icons.chat_bubble_outline,
  //                 size: 80,
  //                 color: Colors.grey[200],
  //               ),
  //               const SizedBox(height: 16),
  //               Text(
  //                 "Welcome to the Chat App!",
  //                 style: TextStyle(fontSize: 18, color: Colors.grey[700]),
  //               ),
  //               const SizedBox(height: 8),
  //               Text(
  //                 "Start a conversation with an active user.",
  //                 style: TextStyle(fontSize: 14, color: Colors.grey[500]),
  //               ),
  //             ],
  //           ),
  //         );
  //       }
  //       //final chatDocs = snapshot.data!.docs;
  //       return ListView.builder(
  //         shrinkWrap: true,
  //         physics: NeverScrollableScrollPhysics(),
  //         itemCount: chatDocs.length,
  //         itemBuilder: (context, index) {
  //           final chatData = chatDocs[index].data() as Map<String, dynamic>;
  //
  //           final List<String> participants = List.from(
  //             chatData['participants'],
  //           );
  //           final String otherUserId = participants.firstWhere(
  //             (id) => id != currentUserId,
  //             orElse: () => '',
  //           );
  //
  //           if (otherUserId.isEmpty) return const SizedBox.shrink();
  //
  //           final Map<String, dynamic> otherUserInfo =
  //               chatData['participant_info'][otherUserId];
  //           final String otherUserEmail =
  //               (otherUserInfo['email'] ?? '').isNotEmpty
  //               ? otherUserInfo['email']
  //               : 'Unknown User';
  //           final String? otherUserPhotoUrl = otherUserInfo['photoUrl'];
  //
  //           final Timestamp lastMessageTimestamp =
  //               chatData['last_message_timestamp'];
  //           final DateTime lastMessageTime = lastMessageTimestamp.toDate();
  //           final String formattedTime =
  //               "${lastMessageTime.hour}:${lastMessageTime.minute.toString().padLeft(2, '0')}";
  //
  //           return ListTile(
  //             contentPadding: const EdgeInsets.symmetric(
  //               horizontal: 16.0,
  //               vertical: 8.0,
  //             ),
  //             leading: Container(
  //               decoration: BoxDecoration(
  //                 shape: BoxShape.circle,
  //                 border: Border.all(color: Colors.grey.shade600)
  //               ),
  //               child: CircleAvatar(
  //                 radius: 25,
  //                 backgroundColor: AppColor.primaryColor,
  //                 backgroundImage:
  //                     (otherUserPhotoUrl != null && otherUserPhotoUrl.isNotEmpty)
  //                     ? NetworkImage(
  //                         otherUserPhotoUrl,
  //                       ) // Use otherUserPhotoUrl here!
  //                     : null,
  //                 child: (otherUserPhotoUrl == null || otherUserPhotoUrl.isEmpty)
  //                     ? Icon(
  //                         Icons.person,
  //                         size: 25,
  //                         color: Colors.white,
  //                       ) // Smaller icon for consistency
  //                     : null,
  //               ),
  //             ),
  //             title: Text(
  //               otherUserEmail.split('@')[0],
  //               style: const TextStyle(fontWeight: FontWeight.bold),
  //             ),
  //             subtitle: Text(
  //               chatData['last_message'] ?? '',
  //               maxLines: 1,
  //               overflow: TextOverflow.ellipsis,
  //             ),
  //             trailing: Text(
  //               formattedTime,
  //               style: const TextStyle(fontSize: 12, color: Colors.grey),
  //             ),
  //             onTap: () {
  //               Navigator.push(
  //                 context,
  //                 MaterialPageRoute(
  //                   builder: (_) => ChatScreen(
  //                     receiverEmail: otherUserEmail,
  //                     receiverID: otherUserId,
  //                     currentUserId: currentUserId,
  //                     receiverUserId: otherUserId,
  //                   ),
  //                 ),
  //               );
  //             },
  //           );
  //         },
  //       );
  //     },
  //   );
  // }

  Widget buildChatList() {
    final String currentUserId = currentUser.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_rooms')
          .where('participants', arrayContains: currentUserId)
          .orderBy('last_message_timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            // <--- No Expanded here
            child: CircularProgressIndicator(color: AppColor.primaryColor),
          );
        }

        final chatDocs = snapshot.data!.docs;

        _chatListData = chatDocs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final participants = List<String>.from(data['participants']);
          final otherUserId = participants.firstWhere(
            (id) => id != currentUserId,
            orElse: () => '',
          ); // Handle if current user is only participant
          final otherUserInfo =
              data['participant_info'][otherUserId] ??
              {}; // Handle null otherUserInfo
          return {
            'id': otherUserId,
            'email': otherUserInfo['email'] ?? 'Unknown',
            'photoUrl': otherUserInfo['photoUrl'] ?? '',
          };
        }).toList();

        if (chatDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 80,
                  color: Colors.grey[200],
                ),
                const SizedBox(height: 16),
                Text(
                  "Welcome to the Chat App!",
                  style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                Text(
                  "Start a conversation with an active user.",
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: chatDocs.length,
          itemBuilder: (context, index) {
            final chatData = chatDocs[index].data() as Map<String, dynamic>;

            final List<String> participants = List.from(
              chatData['participants'],
            );
            final String otherUserId = participants.firstWhere(
              (id) => id != currentUserId,
              orElse: () => '',
            );

            if (otherUserId.isEmpty) return const SizedBox.shrink();

            final Map<String, dynamic> otherUserInfo =
                chatData['participant_info'][otherUserId] ??
                {}; // Added null check
            final String otherUserEmail =
                (otherUserInfo['email'] ?? '').isNotEmpty
                ? otherUserInfo['email']
                : 'Unknown User';
            final String? otherUserPhotoUrl = otherUserInfo['photoUrl'];

            final Timestamp lastMessageTimestamp =
                chatData['last_message_timestamp'];
            final DateTime lastMessageTime = lastMessageTimestamp.toDate();
            final String formattedTime =
                "${lastMessageTime.hour}:${lastMessageTime.minute.toString().padLeft(2, '0')}";

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              leading: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade600),
                ),
                child: CircleAvatar(
                  radius: 25,
                  backgroundColor: AppColor.primaryColor,
                  backgroundImage:
                      (otherUserPhotoUrl != null &&
                          otherUserPhotoUrl.isNotEmpty)
                      ? NetworkImage(
                          otherUserPhotoUrl,
                        ) // Use otherUserPhotoUrl here!
                      : null,
                  child:
                      (otherUserPhotoUrl == null || otherUserPhotoUrl.isEmpty)
                      ? Icon(
                          Icons.person,
                          size: 25,
                          color: Colors.white,
                        ) // Smaller icon for consistency
                      : null,
                ),
              ),
              title: Text(
                otherUserEmail.split('@')[0],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                chatData['last_message'] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                formattedTime,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      currentUserEmail:
                          FirebaseAuth.instance.currentUser!.email!,
                      receiverEmail: otherUserEmail,
                      receiverID: otherUserId,
                      currentUserId: currentUserId,
                      receiverUserId: otherUserId,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _updateChatRoomParticipantInfo({
    required String currentUserId,
    required String receiverId,
    required Map<String, dynamic> participantInfo,
  }) async {
    final List<String> participants = [currentUserId, receiverId]..sort();
    final String chatRoomId = participants.join('_');

    final chatRoomRef = FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(chatRoomId);

    await chatRoomRef.set({
      'participants': participants,
      'participant_info': participantInfo,
    }, SetOptions(merge: true));
    print("Chat room participant_info updated for $chatRoomId");
  }
}
