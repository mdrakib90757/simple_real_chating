import 'package:flutter/material.dart';
import 'package:web_socket_app/service/group_chat_service/group_chat_service.dart';
import 'package:web_socket_app/utils/color.dart';

class AddMembersScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String currentUserId;

  const AddMembersScreen({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<AddMembersScreen> {
  final GroupChatService _groupChatService = GroupChatService();
  late Future<List<Map<String, dynamic>>> _potentialMembersFuture;
  List<Map<String, dynamic>> _selectedMembers = [];

  @override
  void initState() {
    super.initState();
    // Initialize _potentialMembersFuture to fetch users NOT already in the group
    _potentialMembersFuture = _groupChatService.getPotentialMembers(
      widget.groupId,
      widget.currentUserId,
    );
  }

  void _toggleMemberSelection(Map<String, dynamic> user) {
    setState(() {
      final String userId = user['uid'];
      final int existingIndex = _selectedMembers.indexWhere(
        (member) => member['uid'] == userId,
      );

      if (existingIndex != -1) {
        _selectedMembers.removeAt(existingIndex);
      } else {
        _selectedMembers.add(user);
      }
    });
  }

  Future<void> _addSelectedMembers() async {
    if (_selectedMembers.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please select members to add.')));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: AppColor.primaryColor),
      ),
    );

    try {
      for (var member in _selectedMembers) {
        await _groupChatService.addGroupMember(
          groupId: widget.groupId,
          userId: member['uid'],
          userEmail: member['email'],
          userName: member['name'], // Ensure 'name' is passed
          photoUrl: member['photoUrl'],
        );
      }
      if (mounted) {
        Navigator.pop(context); // Pop loading indicator
        Navigator.pop(context, true); // Pop AddMembersScreen with success
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Members added successfully!')));
      }
    } catch (e) {
      print('Error adding members to group: $e');
      if (mounted) {
        Navigator.pop(context); // Pop loading indicator
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add members: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Add Members to ${widget.groupName}',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColor.primaryColor,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          if (_selectedMembers.isNotEmpty)
            IconButton(
              icon: Icon(Icons.check, color: Colors.white),
              onPressed: _addSelectedMembers,
              tooltip: 'Add Selected Members',
            ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _potentialMembersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: AppColor.primaryColor),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No other users to add.'));
          }

          final potentialMembers = snapshot.data!;
          return ListView.builder(
            itemCount: potentialMembers.length,
            itemBuilder: (context, index) {
              final user = potentialMembers[index];
              final bool isSelected = _selectedMembers.any(
                (selected) => selected['uid'] == user['uid'],
              );
              final String? photoUrl = user['photoUrl'];
              // Safely get name, falling back to email prefix if name is null or empty
              final String name = user['name']?.isNotEmpty == true
                  ? user['name']! // Use '!' because we checked for not null and not empty
                  : user['email']?.split('@')[0] ?? 'User';

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
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
                title: Text(name), // Display the user's name or email prefix
                subtitle: Text(user['email']), // Always show email as subtitle
                trailing: isSelected
                    ? Icon(Icons.check_circle, color: AppColor.primaryColor)
                    : Icon(Icons.radio_button_unchecked),
                onTap: () => _toggleMemberSelection(user),
              );
            },
          );
        },
      ),
    );
  }
}
