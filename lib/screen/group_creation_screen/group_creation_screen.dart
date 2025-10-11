import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:web_socket_app/utils/color.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

class GroupCreationScreen extends StatefulWidget {
  final String? groupId;
  final String? groupName;
  final String? groupPhotoURL;
  final bool isEditing;
  const GroupCreationScreen({
    super.key,
    this.groupId,
    this.groupName,
    this.groupPhotoURL,
    this.isEditing = false,
  });

  @override
  State<GroupCreationScreen> createState() => _GroupCreationScreenState();
}

class _GroupCreationScreenState extends State<GroupCreationScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  List<Map<String, dynamic>> _selectedMembers = [];
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;
  XFile? _pickedGroupImage;
  String? _currentGroupPhotoURL;

  final String cloudinaryCloudName = "dlqufneob";
  final String cloudinaryUploadPreset = "chat_app_unsigned";

  @override
  void initState() {
    super.initState();
    // If editing, pre-fill group name and photo
    if (widget.isEditing) {
      _groupNameController.text = widget.groupName ?? '';
      _currentGroupPhotoURL = widget.groupPhotoURL;
      _fetchGroupMembersForEditing(); // Fetch existing members
    } else {
      // Add current user as the first member by default for new group creation
      if (currentUser != null) {
        _selectedMembers.add({
          'uid': currentUser!.uid,
          'email': currentUser!.email ?? 'You',
          'photoUrl': currentUser!.photoURL,
        });
      }
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  // Fetch existing members when editing a group
  Future<void> _fetchGroupMembersForEditing() async {
    if (widget.groupId == null) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final doc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get();
      if (doc.exists) {
        final data = doc.data();
        final List<String> memberUids = List<String>.from(
          data?['members'] ?? [],
        );
        final Map<String, dynamic> memberInfo = Map<String, dynamic>.from(
          data?['memberInfo'] ?? {},
        );

        List<Map<String, dynamic>> fetchedMembers = [];
        for (String uid in memberUids) {
          final info = memberInfo[uid];
          if (info != null) {
            fetchedMembers.add({
              'uid': uid,
              'email': info['email'] ?? 'Unknown User',
              'photoUrl': info['photoUrl'],
            });
          }
        }
        setState(() {
          _selectedMembers.clear();
          _selectedMembers.addAll(fetchedMembers);
        });
      }
    } catch (e) {
      print("Error fetching group members for editing: $e");
      _showSnackBar("Failed to load group members for editing.");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Image Picking and Upload Logic
  Future<void> _pickGroupImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _pickedGroupImage = image;
      });
    }
  }

  // update Storage in Cloudinary
  Future<String?> _uploadGroupImageToCloudinary(String filePath) async {
    setState(() => _isLoading = true);
    final url = Uri.parse(
      "https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload",
    );
    try {
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = cloudinaryUploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', filePath));
      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonMap = json.decode(responseData);
        return jsonMap['secure_url']; // Return the secure URL of the uploaded image
      } else {
        print("Image upload failed with status: ${response.statusCode}");
        final errorBody = await response.stream.bytesToString();
        print("Error response: $errorBody");
        _showSnackBar("Failed to upload group image.");
        return null;
      }
    } catch (e) {
      print("Error uploading group image: $e");
      _showSnackBar("Error uploading group image: $e");
      return null;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Group Creation/Update Logic
  Future<void> _handleGroupAction() async {
    if (currentUser == null) {
      _showSnackBar("You must be logged in to perform this action.");
      return;
    }
    if (_groupNameController.text.trim().isEmpty) {
      _showSnackBar("Please enter a group name.");
      return;
    }
    if (_selectedMembers.isEmpty) {
      _showSnackBar("Please add at least one member (including yourself).");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String? finalGroupPhotoURL = _currentGroupPhotoURL;

    if (_pickedGroupImage != null) {
      finalGroupPhotoURL = await _uploadGroupImageToCloudinary(
        _pickedGroupImage!.path,
      );
      if (finalGroupPhotoURL == null) {
        _showSnackBar(
          "Failed to upload group image. Group not created/updated.",
        );
        setState(() => _isLoading = false);
        return;
      }
    }

    try {
      final String groupId = widget.isEditing
          ? widget.groupId!
          : const Uuid().v4();

      // Ensure current user is in members
      final List<String> memberUids = _selectedMembers
          .map((m) => m['uid'] as String)
          .toList();
      if (!memberUids.contains(currentUser!.uid)) {
        memberUids.add(currentUser!.uid);
      }

      final Map<String, dynamic> memberInfo = {};
      for (var member in _selectedMembers) {
        memberInfo[member['uid']] = {
          'email': member['email'],
          'photoUrl': member['photoUrl'],
        };
      }

      final Map<String, dynamic> groupData = {
        'id': groupId,
        'name': _groupNameController.text.trim(),
        'creatorId': currentUser!.uid,
        'members': memberUids,
        'memberInfo': memberInfo,
        'groupPhotoURL': finalGroupPhotoURL,
        'last_message': null,
        'last_message_timestamp': FieldValue.serverTimestamp(), // <-- fix
        'last_message_sender_id': null,
        'last_message_sender_name': null,
      };

      if (widget.isEditing) {
        groupData['updatedAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .update(groupData);
        _showSnackBar(
          "Group '${_groupNameController.text.trim()}' updated successfully!",
        );
      } else {
        groupData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .set(groupData);
        _showSnackBar(
          "Group '${_groupNameController.text.trim()}' created successfully!",
        );
      }

      Navigator.pop(context, true); // Return "refresh needed"
    } catch (e) {
      print("Error during group action: $e");
      _showSnackBar(
        "Failed to ${widget.isEditing ? 'update' : 'create'} group: $e",
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Future<void> _handleGroupAction() async {
  //   if (currentUser == null) {
  //     _showSnackBar("You must be logged in to perform this action.");
  //     return;
  //   }
  //   if (_groupNameController.text.trim().isEmpty) {
  //     _showSnackBar("Please enter a group name.");
  //     return;
  //   }
  //   if (_selectedMembers.length < 1) {
  //     // Changed to 1, as creator is always a member
  //     _showSnackBar("Please add at least one member (including yourself).");
  //     return;
  //   }
  //
  //   setState(() {
  //     _isLoading = true;
  //   });
  //
  //   String? finalGroupPhotoURL =
  //       _currentGroupPhotoURL; // Start with existing or null
  //
  //   if (_pickedGroupImage != null) {
  //     finalGroupPhotoURL = await _uploadGroupImageToCloudinary(
  //       _pickedGroupImage!.path,
  //     );
  //     if (finalGroupPhotoURL == null) {
  //       _showSnackBar(
  //         "Failed to upload group image. Group not created/updated.",
  //       );
  //       setState(() => _isLoading = false);
  //       return;
  //     }
  //   }
  //
  //   try {
  //     final String groupId = widget.isEditing
  //         ? widget.groupId!
  //         : const Uuid().v4();
  //     // Ensure current user is in members
  //     final List<String> memberUids = _selectedMembers
  //         .map((m) => m['uid'] as String)
  //         .toList();
  //     if (!memberUids.contains(currentUser!.uid)) {
  //       memberUids.add(currentUser!.uid);
  //     }
  //
  //     final Map<String, dynamic> memberInfo = {};
  //     for (var member in _selectedMembers) {
  //       memberInfo[member['uid']] = {
  //         'email': member['email'],
  //         'photoUrl': member['photoUrl'],
  //       };
  //     }
  //
  //     final Map<String, dynamic> groupData = {
  //       'id': groupId,
  //       'name': _groupNameController.text.trim(),
  //       'creatorId': currentUser!
  //           .uid, // Creator remains the same even if edited by another admin
  //       'members': memberUids,
  //       'memberInfo': memberInfo,
  //       'groupPhotoURL': finalGroupPhotoURL, // Save the group photo URL
  //     };
  //
  //     if (widget.isEditing) {
  //       groupData['updatedAt'] = FieldValue.serverTimestamp();
  //       await FirebaseFirestore.instance
  //           .collection('groups')
  //           .doc(groupId)
  //           .update(groupData);
  //       _showSnackBar(
  //         "Group '${_groupNameController.text.trim()}' updated successfully!",
  //       );
  //     } else {
  //       groupData['createdAt'] = FieldValue.serverTimestamp();
  //       groupData['last_message'] = null;
  //       groupData['last_message_timestamp'] = null;
  //       groupData['last_message_sender_id'] = null;
  //       groupData['last_message_sender_name'] = null;
  //       await FirebaseFirestore.instance
  //           .collection('groups')
  //           .doc(groupId)
  //           .set(groupData);
  //       _showSnackBar(
  //         "Group '${_groupNameController.text.trim()}' created successfully!",
  //       );
  //     }
  //
  //     Navigator.pop(context); // Go back to previous screen
  //   } catch (e) {
  //     print("Error during group action: $e");
  //     _showSnackBar(
  //       "Failed to ${widget.isEditing ? 'update' : 'create'} group: $e",
  //     );
  //   } finally {
  //     setState(() {
  //       _isLoading = false;
  //     });
  //   }
  // }

  ///
  // Future<void> _createGroup() async {
  //   if (currentUser == null) {
  //     _showSnackBar("You must be logged in to create a group.");
  //     return;
  //   }
  //   if (_groupNameController.text.trim().isEmpty) {
  //     _showSnackBar("Please enter a group name.");
  //     return;
  //   }
  //   if (_selectedMembers.length < 2) {
  //     _showSnackBar("Please add at least one other member to the group.");
  //     return;
  //   }
  //
  //   setState(() {
  //     _isLoading = true;
  //   });
  //   String? finalGroupPhotoURL =
  //       _currentGroupPhotoURL; // Start with existing or null
  //
  //   if (_pickedGroupImage != null) {
  //     finalGroupPhotoURL = await _uploadGroupImageToCloudinary(
  //       _pickedGroupImage!.path,
  //     );
  //     if (finalGroupPhotoURL == null) {
  //       _showSnackBar(
  //         "Failed to upload group image. Group not created/updated.",
  //       );
  //       setState(() => _isLoading = false);
  //       return;
  //     }
  //   }
  //   try {
  //     final String groupId = const Uuid().v4(); // Generate unique group ID
  //     final List<String> memberUids = _selectedMembers
  //         .map((m) => m['uid'] as String)
  //         .toList();
  //     print('Creating group with members: $memberUids');
  //
  //     // Prepare member info for easy access
  //     final Map<String, dynamic> memberInfo = {};
  //     for (var member in _selectedMembers) {
  //       memberInfo[member['uid']] = {
  //         'email': member['email'],
  //         'photoUrl': member['photoUrl'],
  //       };
  //     }
  //
  //     await FirebaseFirestore.instance.collection('groups').doc(groupId).set({
  //       'id': groupId,
  //       'name': _groupNameController.text.trim(),
  //       'creatorId': currentUser!.uid,
  //       'members': memberUids,
  //       'memberInfo': memberInfo,
  //       'createdAt': FieldValue.serverTimestamp(),
  //       'last_message': null,
  //       'last_message_timestamp': null,
  //       'last_message_sender_id': null,
  //       'last_message_sender_name': null,
  //     });
  //
  //     _showSnackBar(
  //       "Group '${_groupNameController.text.trim()}' created successfully!",
  //     );
  //     Navigator.pop(context); // Go back to previous screen (HomeScreen)
  //   } catch (e) {
  //     print("Error creating group: $e");
  //     _showSnackBar("Failed to create group: $e");
  //   } finally {
  //     setState(() {
  //       _isLoading = false;
  //     });
  //   }
  // }
  ///
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // add member function
  Future<void> _addMembers() async {
    final selected = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectUsersForGroupScreen(
          excludedUids: _selectedMembers
              .map((m) => m['uid'] as String)
              .toList(),
        ),
      ),
    );

    if (selected != null && selected.isNotEmpty) {
      setState(() {
        _selectedMembers = selected;
      });
    }
  }

  // remove member function
  void _removeMember(String uid) {
    if (uid == currentUser!.uid) {
      _showSnackBar("You cannot remove yourself from the group creation list.");
      return;
    }
    setState(() {
      _selectedMembers.removeWhere((member) => member['uid'] == uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Create New Group',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColor.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickGroupImage,
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: AppColor.primaryColor.withOpacity(0.2),
                  backgroundImage: _pickedGroupImage != null
                      ? FileImage(File(_pickedGroupImage!.path))
                            as ImageProvider<Object>?
                      : (_currentGroupPhotoURL != null &&
                                _currentGroupPhotoURL!.isNotEmpty
                            ? NetworkImage(_currentGroupPhotoURL!)
                                  as ImageProvider<Object>?
                            : null),
                  child:
                      (_pickedGroupImage == null &&
                          (_currentGroupPhotoURL == null ||
                              _currentGroupPhotoURL!.isEmpty))
                      ? Icon(
                          Icons.camera_alt,
                          size: 40,
                          color: AppColor.primaryColor,
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _groupNameController,
              decoration: InputDecoration(
                labelText: 'Group Name',
                hintText: 'e.g., Family Chat, Project Team',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.group_add),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Members:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _addMembers,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Members'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColor.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _selectedMembers.length,
                itemBuilder: (context, index) {
                  final member = _selectedMembers[index];
                  final bool isCreator = member['uid'] == currentUser!.uid;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            (member['photoUrl'] != null &&
                                member['photoUrl'].isNotEmpty)
                            ? NetworkImage(member['photoUrl']) as ImageProvider
                            : null,
                        child:
                            (member['photoUrl'] == null ||
                                member['photoUrl'].isEmpty)
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                        backgroundColor: AppColor.primaryColor,
                      ),
                      title: Text(member['email'].split('@')[0]),
                      subtitle: isCreator ? const Text('Group Creator') : null,
                      trailing: isCreator
                          ? const Icon(Icons.star, color: Colors.amber)
                          : IconButton(
                              icon: const Icon(
                                Icons.remove_circle,
                                color: Colors.red,
                              ),
                              onPressed: () => _removeMember(member['uid']),
                            ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: _isLoading
                  ? CircularProgressIndicator(color: AppColor.primaryColor)
                  : ElevatedButton(
                      onPressed: _handleGroupAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColor.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Create Group',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper screen to select users from the existing user base
class SelectUsersForGroupScreen extends StatefulWidget {
  final List<String> excludedUids;
  const SelectUsersForGroupScreen({super.key, required this.excludedUids});

  @override
  State<SelectUsersForGroupScreen> createState() =>
      _SelectUsersForGroupScreenState();
}

class _SelectUsersForGroupScreenState extends State<SelectUsersForGroupScreen> {
  final List<Map<String, dynamic>> _tempSelectedUsers = [];

  @override
  Widget build(BuildContext context) {
    // Get the full height of the screen
    final mediaQuery = MediaQuery.of(context);
    final double screenHeight = mediaQuery.size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context, _tempSelectedUsers);
          },
          icon: Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: const Text(
          'Select Group Members',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColor.primaryColor,
      ),
      // Wrap the Column with a Sized Box that takes up most of the screen height
      body: SizedBox(
        // Set a height for the content, e.g., 90% of screen height
        // Adjust this value based on how much space you want the AppBar and bottom button to take.
        height: screenHeight * 0.9, // This will constrain the Column's height
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: AppColor.primaryColor,
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No users found.'));
                  }

                  final users = snapshot.data!.docs
                      .map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return {
                          'uid': doc.id,
                          'email': data['email'] ?? 'No Email',
                          'photoUrl': data['photoUrl'] ?? '',
                        };
                      })
                      .where(
                        (user) => !widget.excludedUids.contains(user['uid']),
                      )
                      .toList();

                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return CheckboxListTile(
                        title: Text(user['email'].split('@')[0]),
                        secondary: CircleAvatar(
                          backgroundImage:
                              (user['photoUrl'] != null &&
                                  user['photoUrl'].isNotEmpty)
                              ? NetworkImage(user['photoUrl']) as ImageProvider
                              : null,
                          child:
                              (user['photoUrl'] == null ||
                                  user['photoUrl'].isEmpty)
                              ? const Icon(Icons.person, color: Colors.white)
                              : null,
                          backgroundColor: AppColor.primaryColor,
                        ),
                        value: _tempSelectedUsers.any(
                          (sUser) => sUser['uid'] == user['uid'],
                        ),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _tempSelectedUsers.add(user);
                            } else {
                              _tempSelectedUsers.removeWhere(
                                (sUser) => sUser['uid'] == user['uid'],
                              );
                            }
                          });
                        },
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, _tempSelectedUsers);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Select', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
