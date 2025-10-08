import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'package:web_socket_app/screen/group_call_screen/group_call_screen.dart';
import 'package:web_socket_app/screen/profileEditScreen/profileEditScreen.dart';
import 'package:web_socket_app/utils/color.dart';
import '../model/group_model/group_model.dart';
import '../widgets/custom_search_delegate/custom_search_delegate.dart';
import 'auth_screen/signIn_screen.dart';
import 'chat_screen.dart';
import 'group_chat_screen/group_chat_screen.dart';
import 'group_creation_screen/group_creation_screen.dart';

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
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isDeviceConnected = false; // Track device's internet status

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateUserStatus(isOnline: true);
    print("Current user photo URL is: ${currentUser.photoURL}");
    _initializeUserAndNotifications();
    _initializeConnectivity();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateUserStatus(isOnline: true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _updateUserStatus(isOnline: false);
    }
  }

  // initialize connectivity monitoring
  void _initializeConnectivity() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    _updateConnectionStatus(connectivityResult);

    // connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      _updateConnectionStatus(results);
    });
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    bool connected =
        results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.wifi);
    if (_isDeviceConnected != connected) {
      setState(() {
        _isDeviceConnected = connected;
      });
      // Update Firebase Realtime Database based on device connectivity
      _updateUserStatus(isOnline: _isDeviceConnected);
    }
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
          //crossAxisAlignment: CrossAxisAlignment.start,
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
        backgroundColor: Colors.white,
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
              leading: const Icon(Icons.group_add_sharp),
              title: const Text("Create group"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GroupCreationScreen(),
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
        builder: (context, AsyncSnapshot<DatabaseEvent> presenceSnapshot) {
          if (!presenceSnapshot.hasData ||
              presenceSnapshot.data?.snapshot.value == null) {
            return Center(child: Text("Loading users..."));
          }

          final rawPresenceData = presenceSnapshot.data!.snapshot.value;
          final presenceData = (rawPresenceData is Map)
              ? Map<String, dynamic>.from(rawPresenceData)
              : {};

          // final onlineUsersUids = <String>[];
          // data.forEach((key, value) {
          //   if (value['isOnline'] == true && key != currentUser.uid) {
          //     onlineUsersUids.add(key);
          //   }
          // });

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

              // // Logged-in user first
              // final currentUserData = allUsers.firstWhere(
              //   (u) => u['uid'] == currentUser.uid,
              //   orElse: () => {
              //     'uid': currentUser.uid,
              //     'email': currentUser.email ?? "User",
              //     'photoUrl': currentUser.photoURL ?? '',
              //   },
              // );
              //
              // final onlineUsers = allUsers
              //     .where((u) => onlineUsersUids.contains(u['uid']))
              //     .toList();
              //
              // final usersList = [currentUserData, ...onlineUsers];

              // Combine presence data with Firestore user data
              final List<Map<String, dynamic>> usersWithStatus = [];
              for (var user in allUsers) {
                final String uid = user['uid'];
                final userPresence = presenceData[uid];
                final bool isOnline = userPresence?['isOnline'] == true;
                final int? lastSeenTimestamp = userPresence?['last_seen'];

                usersWithStatus.add({
                  ...user,
                  'isOnline': isOnline,
                  'last_seen': lastSeenTimestamp,
                });
              }

              // Sort users: current user first, then truly online users, then offline users by last_seen
              usersWithStatus.sort((a, b) {
                // Current user always first
                if (a['uid'] == currentUser.uid) return -1;
                if (b['uid'] == currentUser.uid) return 1;

                // Online users before offline users
                if (a['isOnline'] && !b['isOnline']) return -1;
                if (!a['isOnline'] && b['isOnline']) return 1;

                // If both are online or both are offline, sort by last_seen (most recent first)
                final int? aLastSeen = a['last_seen'];
                final int? bLastSeen = b['last_seen'];
                if (aLastSeen == null && bLastSeen == null) return 0;
                if (aLastSeen == null)
                  return 1; // Put users without last_seen at the end
                if (bLastSeen == null) return -1;
                return bLastSeen.compareTo(
                  aLastSeen,
                ); // Descending order (most recent first)
              });

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: usersWithStatus.length,
                //  padding: EdgeInsets.symmetric(horizontal: 5, vertical: 8),
                itemBuilder: (context, index) {
                  final user = usersWithStatus[index];
                  final uid = user['uid'];
                  final email = user['email'];
                  final photoUrl = user['photoUrl'];
                  final bool isCurrentUser = uid == currentUser.uid;
                  final bool isUserOnline = user['isOnline'];
                  final int? lastSeenMillis = user['last_seen'];

                  String statusText = '';
                  if (isCurrentUser) {
                    statusText = "You";
                  } else if (isUserOnline) {
                    statusText = "Online";
                  } else if (lastSeenMillis != null) {
                    final DateTime lastSeenTime =
                        DateTime.fromMillisecondsSinceEpoch(lastSeenMillis);
                    final Duration difference = DateTime.now().difference(
                      lastSeenTime,
                    );

                    if (difference.inDays > 0) {
                      statusText = DateFormat.MMMd().add_jm().format(
                        lastSeenTime,
                      ); // e.g., "Oct 26, 10:30 AM"
                    } else if (difference.inHours > 0) {
                      statusText = "${difference.inHours}h ago";
                    } else if (difference.inMinutes > 0) {
                      statusText = "${difference.inMinutes}m ago";
                    } else {
                      statusText = "Just now";
                    }
                  } else {
                    statusText = "Offline"; // Fallback if no last_seen
                  }

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
                              if (!isUserOnline) // green dot for online users only
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
                            style: TextStyle(fontSize: 12),
                          ),
                          Text(
                            statusText, // Display the status text
                            style: TextStyle(fontSize: 10, color: Colors.grey),
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
  //   // final String currentUserId = currentUser.uid;
  //   //
  //   // return StreamBuilder<List<DocumentSnapshot>>(
  //   //   stream: _combinedChatAndGroupStreams(currentUserId),
  //   //   builder: (context, snapshot) {
  //   //     if (!snapshot.hasData) {
  //   //       return Center(
  //   //         child: CircularProgressIndicator(color: AppColor.primaryColor),
  //   //       );
  //   //     }
  //   //
  //   //     final combinedDocs = snapshot.data!;
  //   //
  //   //     if (combinedDocs.isEmpty) {
  //   //       return Center(
  //   //         child: Column(
  //   //           mainAxisAlignment: MainAxisAlignment.center,
  //   //           children: [
  //   //             Icon(
  //   //               Icons.chat_bubble_outline,
  //   //               size: 80,
  //   //               color: Colors.grey[200],
  //   //             ),
  //   //             const SizedBox(height: 16),
  //   //             Text(
  //   //               "Welcome to the Chat App!",
  //   //               style: TextStyle(fontSize: 18, color: Colors.grey[700]),
  //   //             ),
  //   //             const SizedBox(height: 8),
  //   //             Text(
  //   //               "Start a conversation or create a group.",
  //   //               style: TextStyle(fontSize: 14, color: Colors.grey[500]),
  //   //             ),
  //   //           ],
  //   //         ),
  //   //       );
  //   //     }
  //
  //
  //   final String currentUserId = currentUser.uid;
  //
  //   return StreamBuilder<Map<String, dynamic>>( // Use the new combined stream type
  //     stream: _combinedDataStream(currentUserId), // Call the new combined stream
  //     builder: (context, snapshot) {
  //       if (!snapshot.hasData) {
  //         return Center(
  //           child: CircularProgressIndicator(color: AppColor.primaryColor),
  //         );
  //       }
  //
  //       final List<DocumentSnapshot> combinedDocs = snapshot.data!['combinedDocs'];
  //       final Map<String, dynamic> presenceData = snapshot.data!['presenceData'];
  //
  //       if (combinedDocs.isEmpty) {
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
  //                 "Start a conversation or create a group.",
  //                 style: TextStyle(fontSize: 14, color: Colors.grey[500]),
  //               ),
  //             ],
  //           ),
  //         );
  //       }
  //
  //
  //
  //
  //       return ListView.builder(
  //         shrinkWrap: true,
  //         physics: NeverScrollableScrollPhysics(),
  //         itemCount: combinedDocs.length,
  //         itemBuilder: (context, index) {
  //           final doc = combinedDocs[index];
  //           final data = doc.data() as Map<String, dynamic>;
  //
  //           if (doc.reference.parent!.id == 'chat_rooms') {
  //             // This is a one-on-one chat
  //             final List<String> participants = List.from(data['participants']);
  //             final String otherUserId = participants.firstWhere(
  //               (id) => id != currentUserId,
  //               orElse: () => '',
  //             );
  //
  //             if (otherUserId.isEmpty) return const SizedBox.shrink();
  //
  //             final Map<String, dynamic> otherUserInfo =
  //                 data['participant_info'][otherUserId] ?? {};
  //             final String otherUserEmail =
  //                 (otherUserInfo['email'] ?? '').isNotEmpty
  //                 ? otherUserInfo['email']
  //                 : 'Unknown User';
  //             final String? otherUserPhotoUrl = otherUserInfo['photoUrl'];
  //
  //             final Timestamp? lastMessageTimestamp =
  //                 data['last_message_timestamp'] as Timestamp?;
  //             final DateTime? lastMessageTime = lastMessageTimestamp?.toDate();
  //             final String formattedTime = lastMessageTime != null
  //                 ? "${lastMessageTime.hour}:${lastMessageTime.minute.toString().padLeft(2, '0')}"
  //                 : '';
  //
  //
  //             // Get presence data for the other user
  //             final userPresence = presenceData[otherUserId];
  //             final bool isUserOnline = userPresence?['isOnline'] == true;
  //             final int? lastSeenMillis = userPresence?['last_seen'];
  //
  //             String onlineStatusText = '';
  //             if (isUserOnline) {
  //               onlineStatusText = "Online";
  //             } else if (lastSeenMillis != null) {
  //               final DateTime lastSeenTime = DateTime.fromMillisecondsSinceEpoch(lastSeenMillis);
  //               final Duration difference = DateTime.now().difference(lastSeenTime);
  //
  //               if (difference.inDays > 0) {
  //                 onlineStatusText = "Last seen ${DateFormat.MMMd().add_jm().format(lastSeenTime)}"; // e.g., "Last seen Oct 26, 10:30 AM"
  //               } else if (difference.inHours > 0) {
  //                 onlineStatusText = "Last seen ${difference.inHours}h ago";
  //               } else if (difference.inMinutes > 0) {
  //                 onlineStatusText = "Last seen ${difference.inMinutes}m ago";
  //               } else {
  //                 onlineStatusText = "Last seen just now";
  //               }
  //             } else {
  //               onlineStatusText = "Offline"; // Fallback if no last_seen
  //             }
  //
  //
  //             return ListTile(
  //               contentPadding: const EdgeInsets.symmetric(
  //                 horizontal: 16.0,
  //                 vertical: 8.0,
  //               ),
  //               leading: CircleAvatar(
  //                 radius: 25,
  //                 backgroundColor: AppColor.primaryColor,
  //                 backgroundImage:
  //                     (otherUserPhotoUrl != null &&
  //                         otherUserPhotoUrl.isNotEmpty)
  //                     ? NetworkImage(otherUserPhotoUrl)
  //                     : null,
  //                 child:
  //                     (otherUserPhotoUrl == null || otherUserPhotoUrl.isEmpty)
  //                     ? Icon(Icons.person, size: 25, color: Colors.white)
  //                     : null,
  //               ),
  //
  //                 if (isUserOnline) // Green dot for online status
  //             Positioned(
  //               bottom: 0,
  //               right: 0,
  //               child: Container(
  //                 width: 12,
  //                 height: 12,
  //                 decoration: BoxDecoration(
  //                   color: Colors.green,
  //                   shape: BoxShape.circle,
  //                   border: Border.all(
  //                     color: Colors.white,
  //                     width: 2,
  //                   ),
  //                 ),
  //               ),
  //             ),
  //           ],
  //           )
  //               title: Text(
  //                 otherUserEmail.split('@')[0],
  //                 style: const TextStyle(fontWeight: FontWeight.bold),
  //               ),
  //               subtitle: Text(
  //                 data['last_message'] ?? '',
  //                 maxLines: 1,
  //                 overflow: TextOverflow.ellipsis,
  //               ),
  //               trailing: Text(
  //                 formattedTime,
  //                 style: const TextStyle(fontSize: 12, color: Colors.grey),
  //               ),
  //               onTap: () {
  //                 Navigator.push(
  //                   context,
  //                   MaterialPageRoute(
  //                     builder: (_) => ChatScreen(
  //                       currentUserEmail:
  //                           FirebaseAuth.instance.currentUser!.email!,
  //                       receiverEmail: otherUserEmail,
  //                       receiverID: otherUserId,
  //                       currentUserId: currentUserId,
  //                       receiverUserId: otherUserId,
  //                     ),
  //                   ),
  //                 );
  //               },
  //             );
  //
  //           } else if (doc.reference.parent!.id == 'groups') {
  //             // This is a group chat
  //             final Group group = Group.fromFirestore(doc);
  //             final DateTime? lastMessageTime = group.lastMessageTimestamp
  //                 ?.toDate();
  //             final String formattedTime = lastMessageTime != null
  //                 ? "${lastMessageTime.hour}:${lastMessageTime.minute.toString().padLeft(2, '0')}"
  //                 : '';
  //             final String? groupPhotoURL = data['groupPhotoURL'] as String?;
  //             return ListTile(
  //               contentPadding: const EdgeInsets.symmetric(
  //                 horizontal: 16.0,
  //                 vertical: 8.0,
  //               ),
  //               leading: CircleAvatar(
  //                 radius: 25,
  //                 backgroundColor: AppColor.primaryColor,
  //                 // Use NetworkImage if groupPhotoURL is available and not empty
  //                 backgroundImage: (groupPhotoURL != null && groupPhotoURL.isNotEmpty)
  //                     ? NetworkImage(groupPhotoURL) as ImageProvider<Object>?
  //                     : null, // Otherwise, it will fallback to the child icon
  //                 child: (groupPhotoURL == null || groupPhotoURL.isEmpty)
  //                     ? const Icon(Icons.group, size: 25, color: Colors.white)
  //                     : null, // Show default icon only if no photo URL
  //
  //               ),
  //               title: Text(
  //                 group.name,
  //                 style: const TextStyle(fontWeight: FontWeight.bold),
  //               ),
  //               subtitle: Text(
  //                 group.lastMessage ?? 'No messages yet',
  //                 maxLines: 1,
  //                 overflow: TextOverflow.ellipsis,
  //               ),
  //               trailing: Text(
  //                 formattedTime,
  //                 style: const TextStyle(fontSize: 12, color: Colors.grey),
  //               ),
  //               onTap: () {
  //                 Navigator.push(
  //                   context,
  //                   MaterialPageRoute(
  //                     builder: (_) => GroupChatScreen(
  //                       groupId: group.id,
  //                       groupName: group.name,
  //                       currentUserId: currentUserId,
  //                       groupMemberIds: [],
  //                     ),
  //                   ),
  //                 );
  //               },
  //             );
  //           }
  //           return const SizedBox.shrink(); // Should not happen
  //         },
  //       );
  //     },
  //   );
  // }

  // Modify _combinedChatAndGroupStreams to also return presence data

  Widget buildChatList() {
    final String currentUserId = currentUser.uid;

    return StreamBuilder<Map<String, dynamic>>(
      // Use the new combined stream type
      stream: _combinedDataStream(
        currentUserId,
      ), // Call the new combined stream
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(color: AppColor.primaryColor),
          );
        }

        final List<DocumentSnapshot> combinedDocs =
            snapshot.data!['combinedDocs'];
        final Map<String, dynamic> presenceData =
            snapshot.data!['presenceData'];

        if (combinedDocs.isEmpty) {
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
                  "Start a conversation or create a group.",
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: combinedDocs.length,
          itemBuilder: (context, index) {
            final doc = combinedDocs[index];
            final data = doc.data() as Map<String, dynamic>;

            if (doc.reference.parent!.id == 'chat_rooms') {
              // This is a one-on-one chat
              final List<String> participants = List.from(data['participants']);
              final String otherUserId = participants.firstWhere(
                (id) => id != currentUserId,
                orElse: () => '',
              );

              if (otherUserId.isEmpty) return const SizedBox.shrink();

              final Map<String, dynamic> otherUserInfo =
                  data['participant_info'][otherUserId] ?? {};
              final String otherUserEmail =
                  (otherUserInfo['email'] ?? '').isNotEmpty
                  ? otherUserInfo['email']
                  : 'Unknown User';
              final String? otherUserPhotoUrl = otherUserInfo['photoUrl'];

              final Timestamp? lastMessageTimestamp =
                  data['last_message_timestamp'] as Timestamp?;
              final DateTime? lastMessageTime = lastMessageTimestamp?.toDate();
              final String lastMessageFormattedTime = lastMessageTime != null
                  ? "${lastMessageTime.hour}:${lastMessageTime.minute.toString().padLeft(2, '0')}"
                  : '';

              // Get presence data for the other user
              final userPresence = presenceData[otherUserId];
              final bool isUserOnline = userPresence?['isOnline'] == true;
              final int? lastSeenMillis = userPresence?['last_seen'];

              String onlineStatusText = '';
              if (isUserOnline) {
                onlineStatusText = "Online";
              } else if (lastSeenMillis != null) {
                final DateTime lastSeenTime =
                    DateTime.fromMillisecondsSinceEpoch(lastSeenMillis);
                final Duration difference = DateTime.now().difference(
                  lastSeenTime,
                );

                // Display "Xm ago" only if within 1 hour
                if (difference.inHours < 1) {
                  // This is the core change
                  if (difference.inMinutes > 0) {
                    onlineStatusText = "${difference.inMinutes}m ago";
                  } else {
                    onlineStatusText = "Just now";
                  }
                } else {
                  // If more than 1 hour, use the "Last seen" format
                  onlineStatusText =
                      "Last seen ${DateFormat.MMMd().add_jm().format(lastSeenTime)}";
                }
              } else {
                onlineStatusText = "Offline"; // Fallback if no last_seen
              }

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                leading: Stack(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: AppColor.primaryColor,
                      backgroundImage:
                          (otherUserPhotoUrl != null &&
                              otherUserPhotoUrl.isNotEmpty)
                          ? NetworkImage(otherUserPhotoUrl)
                          : null,
                      child:
                          (otherUserPhotoUrl == null ||
                              otherUserPhotoUrl.isEmpty)
                          ? Icon(Icons.person, size: 25, color: Colors.white)
                          : null,
                    ),
                  ],
                ),
                title: Text(
                  otherUserEmail.split('@')[0],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['last_message'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      onlineStatusText, // Display the online/last seen status
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                trailing: Text(
                  lastMessageFormattedTime,
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
            } else if (doc.reference.parent!.id == 'groups') {
              // This is a group chat
              final Group group = Group.fromFirestore(doc);
              final DateTime? lastMessageTime = group.lastMessageTimestamp
                  ?.toDate();
              final String formattedTime = lastMessageTime != null
                  ? "${lastMessageTime.hour}:${lastMessageTime.minute.toString().padLeft(2, '0')}"
                  : '';
              final String? groupPhotoURL = data['groupPhotoURL'] as String?;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                leading: CircleAvatar(
                  radius: 25,
                  backgroundColor: AppColor.primaryColor,
                  backgroundImage:
                      (groupPhotoURL != null && groupPhotoURL.isNotEmpty)
                      ? NetworkImage(groupPhotoURL) as ImageProvider<Object>?
                      : null,
                  child: (groupPhotoURL == null || groupPhotoURL.isEmpty)
                      ? const Icon(Icons.group, size: 25, color: Colors.white)
                      : null,
                ),
                title: Text(
                  group.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  group.lastMessage ?? 'No messages yet',
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
                      builder: (_) => GroupChatScreen(
                        groupId: group.id,
                        groupName: group.name,
                        currentUserId: currentUserId,
                        groupMemberIds: [],
                      ),
                    ),
                  );
                },
              );
            }
            return const SizedBox.shrink(); // Should not happen
          },
        );
      },
    );
  }

  Stream<Map<String, dynamic>> _combinedDataStream(String currentUserId) {
    final Stream<QuerySnapshot> chatRoomsStream = FirebaseFirestore.instance
        .collection('chat_rooms')
        .where('participants', arrayContains: currentUserId)
        .orderBy('last_message_timestamp', descending: true)
        .snapshots();

    final Stream<QuerySnapshot> groupsStream = FirebaseFirestore.instance
        .collection('groups')
        .where('members', arrayContains: currentUserId)
        .orderBy('last_message_timestamp', descending: true)
        .snapshots();

    final Stream<DatabaseEvent> presenceStream = _firebaseDatabase
        .ref('presence')
        .onValue;

    return Rx.combineLatest3(chatRoomsStream, groupsStream, presenceStream, (
      QuerySnapshot chatSnapshot,
      QuerySnapshot groupSnapshot,
      DatabaseEvent presenceEvent,
    ) {
      final List<DocumentSnapshot> allDocs = [];
      allDocs.addAll(chatSnapshot.docs);
      allDocs.addAll(groupSnapshot.docs);

      allDocs.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;

        final Timestamp? aTimestamp = aData['last_message_timestamp'];
        final Timestamp? bTimestamp = bData['last_message_timestamp'];

        if (aTimestamp == null && bTimestamp == null) return 0;
        if (aTimestamp == null) return 1;
        if (bTimestamp == null) return -1;

        return bTimestamp.compareTo(aTimestamp);
      });

      final rawPresenceData = presenceEvent.snapshot.value;
      final presenceData = (rawPresenceData is Map)
          ? Map<String, dynamic>.from(rawPresenceData)
          : {};

      return {'combinedDocs': allDocs, 'presenceData': presenceData};
    });
  }

  // stream combiner function
  Stream<List<DocumentSnapshot>> _combinedChatAndGroupStreams(
    String currentUserId,
  ) {
    final Stream<QuerySnapshot> chatRoomsStream = FirebaseFirestore.instance
        .collection('chat_rooms')
        .where('participants', arrayContains: currentUserId)
        .orderBy('last_message_timestamp', descending: true)
        .snapshots();

    final Stream<QuerySnapshot> groupsStream = FirebaseFirestore.instance
        .collection('groups')
        .where('members', arrayContains: currentUserId)
        .orderBy('last_message_timestamp', descending: true)
        .snapshots();

    return Rx.combineLatest2(chatRoomsStream, groupsStream, (
      QuerySnapshot chatSnapshot,
      QuerySnapshot groupSnapshot,
    ) {
      final List<DocumentSnapshot> allDocs = [];
      allDocs.addAll(chatSnapshot.docs);
      allDocs.addAll(groupSnapshot.docs);

      allDocs.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;

        final Timestamp? aTimestamp = aData['last_message_timestamp'];
        final Timestamp? bTimestamp = bData['last_message_timestamp'];

        if (aTimestamp == null && bTimestamp == null) return 0;
        if (aTimestamp == null) return 1;
        if (bTimestamp == null) return -1;

        return bTimestamp.compareTo(aTimestamp);
      });

      return allDocs;
    });
  }

  Future<void> _updateChatRoomParticipantInfo({
    required String currentUserId,
    required String receiverId,
    required Map<String, dynamic> participantInfo,
  }) async {
    final List<String> participants = [currentUserId, receiverId]..sort();
    final String chatRoomId = participants.join('_');

    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(chatRoomId)
        .set({
          'participants': participants,
          'participant_info': participantInfo,
        }, SetOptions(merge: true));

    print("Chat room participant_info updated for $chatRoomId");
  }
}
