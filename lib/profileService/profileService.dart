import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ProfileService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cloudinary configuration
  static const String _cloudName = "dlqufneob";
  static const String _uploadPreset = "chat_app_unsigned";

  Future<String?> uploadProfileImage(File imageFile) async {
    try {
      final url = Uri.parse(
        "https://api.cloudinary.com/v1_1/$_cloudName/image/upload",
      );

      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonMap = json.decode(responseData);
        final imageUrl = jsonMap['secure_url'];
        return imageUrl;
      } else {
        print(
          "Cloudinary image upload failed with status: ${response.statusCode}",
        );
        final errorBody = await response.stream.bytesToString();
        print("Cloudinary error response: $errorBody");
        return null;
      }
    } catch (e) {
      print("Error uploading profile image to Cloudinary: $e");
      return null;
    }
  }

  Future<bool> updateUserProfile({String? name, String? photoURL}) async {
    final User? currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      print("No user logged in.");
      return false;
    }

    try {
      // Update Firebase Auth profile
      if (name != null || photoURL != null) {
        await currentUser.updateDisplayName(name);
        await currentUser.updatePhotoURL(photoURL);
        await currentUser.reload();
      }

      // Update Firestore user document
      final DocumentReference userRef = _firestore
          .collection('users')
          .doc(currentUser.uid);
      final Map<String, dynamic> updateData = {};
      if (name != null) updateData['name'] = name;
      if (photoURL != null) updateData['photoUrl'] = photoURL;

      if (updateData.isNotEmpty) {
        await userRef.update(updateData);
      }

      return true;
    } catch (e) {
      print("Error updating user profile: $e");
      return false;
    }
  }
}
