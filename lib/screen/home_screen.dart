import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
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
      print("✅ User created in Firestore: ${user.uid}");
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

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildOnlineUsersList(),
            Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[200]),
            SizedBox(height: 20),
            Text(
              "Welcome to the Chat App!",
              style: TextStyle(fontSize: 18, color: Colors.grey[700]),
            ),
            SizedBox(height: 10),
            Text(
              "Click the menu on the top right to see online users.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
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
            Divider(),
            SizedBox(height: 30),
            ListTile(
              leading: Icon(Icons.exit_to_app),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/');
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
          final onlineUsers = <Map<String, dynamic>>[];

          data.forEach((key, value) {
            if (value['isOnline'] == true && key != currentUser.uid) {
              onlineUsers.add({
                'uid': key,
                'email': value['email'] ?? 'No Email',
              });
            }
          });

          if (onlineUsers.isEmpty) {
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

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: onlineUsers.length,
            itemBuilder: (context, index) {
              final user = onlineUsers[index];
              final email = user['email'];
              final uid = user['uid'];

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
                        });
                    print("Receiver user created in Firestore: $uid");
                  }

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
                        child: Icon(Icons.person, color: Colors.white),
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
      ),
    );
  }
}
