// lib/services/profile_service.dart

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> uploadProfileImage(File imageFile) async {
    try {
      if (_auth.currentUser == null) return null;

      final String filePath = 'profile_pictures/${_auth.currentUser!.uid}';
      final Reference storageRef = _storage.ref().child(filePath);

      await storageRef.putFile(imageFile);

      final String downloadURL = await storageRef.getDownloadURL();
      return downloadURL;
    } catch (e) {
      print("Error uploading profile image: $e");
      return null;
    }
  }

  Future<bool> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) return false;
      if (displayName != null) await user.updateDisplayName(displayName);
      if (photoURL != null) await user.updatePhotoURL(photoURL);
      if (photoURL != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'photoUrl': photoURL,
        });
      }
      await user.reload();
      return true;
    } catch (e) {
      print("Error updating user profile: $e");
      return false;
    }
  }
}
