import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

class ImageStorageService {
  /// Compresses an image file to reduce storage size and upload time.
  /// Returns the compressed [File] or null if compression fails.
  static Future<File?> compressImage(File file) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmssSSS').format(DateTime.now());
      final targetPath = p.join(
        tempDir.path,
        '${timestamp}_compressed.jpg',
      );

      // Compress the image
      // quality: 70 provides a good balance between size and visual fidelity
      // minWidth/minHeight: Resizes the image if it exceeds these dimensions
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 1280,
        minHeight: 1280,
      );

      if (result == null) return null;
      return File(result.path);
    } catch (e) {
      print('Error compressing image: $e');
      return null;
    }
  }

  /// Uploads the file to Firebase Storage and returns the download URL.
  /// Stores images under: users/{userId}/meal_logs/{timestamp}.jpg
  static Future<String?> uploadMealImage({
    required File file,
    required String userId,
  }) async {
    try {
      final timestamp = DateFormat('yyyyMMdd_HHmmssSSS').format(DateTime.now());
      final fileName = '$timestamp.jpg';
      final destination = 'users/$userId/meal_logs/$fileName';

      final ref = FirebaseStorage.instance.ref(destination);

      final uploadTask = ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  /// Helper to compress and upload in one step
  static Future<String?> processAndUploadImage(File originalFile, String userId) async {
    final compressed = await compressImage(originalFile);
    if (compressed == null) return null;

    final url = await uploadMealImage(file: compressed, userId: userId);

    // Cleanup temp file to save space
    try {
      if (await compressed.exists()) {
        await compressed.delete();
      }
    } catch (_) {}

    return url;
  }
}