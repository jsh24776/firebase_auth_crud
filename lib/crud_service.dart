import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

/// Handles Firestore CRUD + Cloudinary image upload.
/// Data path: users/{uid}/items/{itemId}
///   -> { name, quantity, imageUrl, isFavorite, createdAt }
class CrudService {
  // TODO: replace with your own values from the Cloudinary dashboard
  static const String _cloudName = 'wi8exu5z';
  static const String _uploadPreset = 'messiGoat';  

  final CloudinaryPublic _cloudinary =
      CloudinaryPublic(_cloudName, _uploadPreset, cache: false);
  final ImagePicker _picker = ImagePicker();

  CollectionReference<Map<String, dynamic>> get items => FirebaseFirestore
      .instance
      .collection('users')
      .doc(FirebaseAuth.instance.currentUser!.uid)
      .collection('items');

  // ---------- PICK IMAGE ----------
  /// Opens the gallery. Returns null if the user cancels.
  Future<File?> pickImageForAddItem() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (pickedFile == null) return null;
    return File(pickedFile.path);
  }

  // ---------- UPLOAD IMAGE ----------
  /// Uploads the file to Cloudinary and returns the image URL.
  Future<String> uploadImage(File file) async {
    final response = await _cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        file.path,
        resourceType: CloudinaryResourceType.Image,
      ),
    );
    return response.secureUrl;
  }

  // ---------- CREATE ----------
  Future<void> addItem(String name, int quantity, {String? imageUrl}) async {
    await items.add({
      'name': name,
      'quantity': quantity,
      'imageUrl': imageUrl ?? '',
      'isFavorite': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------- UPDATE ----------
  Future<void> updateItem(String id, String name, int quantity,
      {String? imageUrl}) async {
    final data = <String, dynamic>{'name': name, 'quantity': quantity};
    if (imageUrl != null) data['imageUrl'] = imageUrl; // only if a new image
    await items.doc(id).update(data);
  }

  Future<void> toggleFavorite(String id, bool isFavorite) async {
    await items.doc(id).update({'isFavorite': !isFavorite});
  }

  // ---------- DELETE ----------
  Future<void> deleteItem(String id) async {
    await items.doc(id).delete();
  }
}