
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_app/model/message_model/message_model.dart';
import 'package:web_socket_app/utils/color.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firebaseFirestore = FirebaseFirestore.instance;
  final _textController = TextEditingController();
  final _scrollController= ScrollController();
  final User currentUser = FirebaseAuth.instance.currentUser!;




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(onPressed: () {
        }, icon: Icon(Icons.menu,color: AppColor.primaryColor,)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Chatter",style: TextStyle(
              fontSize: 15
            ),),
            Text("Chatter",style: TextStyle(
              fontSize: 8
            ),),
          ],
        ),
        actions: [
          IconButton(onPressed: () {
          }, icon: Icon(Icons.more_vert,color: AppColor.primaryColor,))
        ],
      ),
      body: Column(
        children: [
          Expanded(
           child: StreamBuilder<QuerySnapshot>(
      stream: _firebaseFirestore.collection("message").orderBy("timestamp",descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(child: Text("No messages yet!"));
            }
            final messages = snapshot.data!.docs;
          return  ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: EdgeInsets.all(16.0),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final doc = messages[index];
                final data = doc.data() as Map<String, dynamic>;
                final message = Message(
                  sender: data['sender'],
                  text: data['text'],
                  isMe: data['sender'] == currentUser.email,
                );
               return _buildMessageBubble(message);
              },
            );
          },
           )
          ),
         _buildMessageComposer()
        ],
      ),
    );
  }

  // we will be build these helper methods
  Widget _buildMessageBubble(Message message){
    final bool isMe = message.isMe;
    //placeHolder for now
    return Column(
      crossAxisAlignment: isMe? CrossAxisAlignment.end:CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10, right: 10, bottom: 4),
          child: Text(
            message.sender,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16,vertical: 10),
          decoration: BoxDecoration(
            color: isMe?AppColor.primaryColor:Color(0xFFF1F1F1),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: isMe ? const Radius.circular(20) : Radius.zero,
              bottomRight: isMe ? Radius.zero : const Radius.circular(20),
            ),
          ),
          child: Text(
           message.text,style: TextStyle(
            color: isMe ? Colors.white : Colors.black87,
            fontSize: 16,
          ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
  
  Widget _buildMessageComposer(){
    return Container(
      
      padding: EdgeInsets.symmetric(horizontal: 12.0,vertical: 8.0),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(child: TextField(
            controller: _textController,
            decoration: InputDecoration(
              hintText: "Type your message here",
              filled: true,
              fillColor:  Color(0xFFF1F1F1),
              contentPadding: EdgeInsets.symmetric(vertical: 10.0,horizontal: 20.0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30.0),
                borderSide: BorderSide.none
              )
            ),
          )
          ),
          SizedBox(width: 8.0,),
          GestureDetector(
            onTap: () {
    if(_textController.text.isNotEmpty){
    _firebaseFirestore.collection("message").add({
    "text":_textController.text,
    "sender":currentUser.email,
    "timestamp":FieldValue.serverTimestamp()
    });
    _textController.clear();
    if (_scrollController.hasClients) {
    _scrollController.animateTo(
    0.0,
    duration: Duration(milliseconds: 300),
    curve: Curves.easeOut,);
    }
    }
    },
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColor.primaryColor,
                shape: BoxShape.circle
              ),
              child: Icon(
                Icons.send,
                color: Colors.white,
              ),
            ),
          )
        ],
      ),
    );
  }
  
  
}
