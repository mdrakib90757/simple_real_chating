import 'package:cloud_firestore/cloud_firestore.dart';

class Group {
  final String id;
  final String name;
  final String creatorId;
  final List<String> members;
  final Map<String, dynamic> memberInfo;
  final Timestamp createdAt;
  String? lastMessage;
  Timestamp? lastMessageTimestamp;
  String? lastMessageSenderId;

  Group({
    required this.id,
    required this.name,
    required this.creatorId,
    required this.members,
    required this.memberInfo,
    required this.createdAt,
    this.lastMessage,
    this.lastMessageTimestamp,
    this.lastMessageSenderId,
  });

  factory Group.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Group(
      id: doc.id,
      name: data['name'] ?? 'Unnamed Group',
      creatorId: data['creatorId'] ?? '',
      members: List<String>.from(data['members'] ?? []),
      memberInfo: Map<String, dynamic>.from(data['memberInfo'] ?? {}),
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : Timestamp.now(), // fallback if missing
      lastMessage: data['last_message'] as String?,
      lastMessageTimestamp:
          data['last_message_timestamp'] != null &&
              data['last_message_timestamp'] is Timestamp
          ? data['last_message_timestamp'] as Timestamp
          : null,
      lastMessageSenderId: data['last_message_sender_id'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'creatorId': creatorId,
      'members': members,
      'memberInfo': memberInfo,
      'createdAt': createdAt,
      'last_message': lastMessage,
      'last_message_timestamp': lastMessageTimestamp,
      'last_message_sender_id': lastMessageSenderId,
    };
  }
}
