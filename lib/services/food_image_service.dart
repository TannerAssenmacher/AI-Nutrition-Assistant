import 'dart:io';

class FoodImageService {
  static const String _cacheDirectoryName = 'ai_nutrition_food_images';
  static const Duration _retentionDuration = Duration(days: 1);

  static bool isSameLocalDay(DateTime a, DateTime b) {
    final localA = a.toLocal();
    final localB = b.toLocal();
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }

  static bool shouldShowImageForEntry(DateTime consumedAt, {DateTime? now}) {
    return isSameLocalDay(consumedAt, now ?? DateTime.now());
  }

  static Future<String?> cacheCapturedImage(File sourceFile) async {
    try {
      if (!await sourceFile.exists()) {
        return null;
      }

      final cacheDirectory = await _getCacheDirectory();
      if (!await cacheDirectory.exists()) {
        await cacheDirectory.create(recursive: true);
      }

      final extension = _fileExtension(sourceFile.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'captured_$timestamp$extension';
      final destination = File('${cacheDirectory.path}/$fileName');
      final copied = await sourceFile.copy(destination.path);
      return Uri.file(copied.path).toString();
    } catch (_) {
      return null;
    }
  }

  static Future<void> purgeExpiredCapturedImages() async {
    final cacheDirectory = await _getCacheDirectory();
    if (!await cacheDirectory.exists()) {
      return;
    }

    final cutoff = DateTime.now().subtract(_retentionDuration);
    await for (final entity in cacheDirectory.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }

      DateTime modifiedAt;
      try {
        modifiedAt = await entity.lastModified();
      } catch (_) {
        continue;
      }

      if (modifiedAt.isBefore(cutoff)) {
        try {
          await entity.delete();
        } catch (_) {
          // Best-effort cleanup only.
        }
      }
    }
  }

  static Future<Directory> _getCacheDirectory() async {
    return Directory('${Directory.systemTemp.path}/$_cacheDirectoryName');
  }

  static String _fileExtension(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == path.length - 1) {
      return '.jpg';
    }
    return path.substring(dotIndex);
  }
}
