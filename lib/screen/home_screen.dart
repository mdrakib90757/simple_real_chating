import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_app/screen/profileEditScreen/profileEditScreen.dart';
import 'package:web_socket_app/utils/color.dart';
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currentUser.email ?? "No Email",
              style: TextStyle(fontSize: 15, color: Colors.white),
            ),
            Text("Online", style: TextStyle(fontSize: 10, color: Colors.white)),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Active Now",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
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
                    Navigator.pushReplacementNamed(context, '/');
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

  //active user list
  Widget _buildOnlineUsersList() {
    return SizedBox(
      height: 100,
      child: StreamBuilder(
        stream: _firebaseDatabase.ref('presence').onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
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
          if (onlineUsersUids.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  "No other users are currently online.",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }
          // Now, fetch user details (including photoURL) from Firestore for these UIDs
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where(FieldPath.documentId, whereIn: onlineUsersUids)
                .snapshots(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              if (!userSnapshot.hasData || userSnapshot.data!.docs.isEmpty) {
                return Center(child: Text("No user data available."));
              }

              final onlineUsersWithData = userSnapshot.data!.docs.map((doc) {
                final userData = doc.data() as Map<String, dynamic>;
                return {
                  'uid': doc.id,
                  'email': userData['email'] ?? 'No Email',
                  'photoUrl':
                      userData['photoUrl'], // Get photoUrl from Firestore
                };
              }).toList();

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: onlineUsersWithData.length,
                itemBuilder: (context, index) {
                  final user = onlineUsersWithData[index];
                  final email = user['email'];
                  final uid = user['uid'];
                  final photoUrl = user['photoUrl'];

                  return GestureDetector(
                    onTap: () async {
                      // Firestore check before navigating
                      final userDoc = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .get();

                      if (!userDoc.exists) {
                        // Optionally create user in Firestore
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .set({
                              'email': email,
                              'fcmTokens': [],
                              'createdAt': FieldValue.serverTimestamp(),
                              'photoUrl': null,
                            });
                        print("Receiver user created in Firestore: $uid");
                      }
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

                      await _updateChatRoomParticipantInfo(
                        currentUserId: currentUser.uid,
                        receiverId: uid,
                        participantInfo: participantInfo,
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
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
                        horizontal: 8,
                        vertical: 10,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor: AppColor.primaryColor,
                            backgroundImage:
                                (photoUrl != null && photoUrl.isNotEmpty)
                                ? NetworkImage(
                                    photoUrl,
                                  ) // Use photoUrl for online user
                                : null,
                            child: (photoUrl == null || photoUrl.isEmpty)
                                ? Icon(
                                    Icons.person,
                                    size: 25,
                                    color: Colors.white,
                                  ) // Smaller icon for consistency
                                : null,
                          ),
                          SizedBox(height: 5),
                          Text(
                            email.split('@')[0],
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15),
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

  Widget buildChatList() {
    final String currentUserId = currentUser.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_rooms')
          .where('participants', arrayContains: currentUserId)
          .orderBy('last_message_timestamp', descending: true)
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Expanded(
            child: Center(
              child: CircularProgressIndicator(
                color: AppColor.primaryColor,
                strokeWidth: 2,
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Expanded(
            child: Center(
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
            ),
          );
        }
        final chatDocs = snapshot.data!.docs;
        return Expanded(
          child: ListView.builder(
            //padding: const EdgeInsets.only(top: 8.0),
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
                  chatData['participant_info'][otherUserId];
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
                leading: CircleAvatar(
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
          ),
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
