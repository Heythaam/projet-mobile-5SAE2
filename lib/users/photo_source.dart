import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum PhotoChoice { camera, gallery }

/// Takes or picks a profile photo and keeps a copy inside the app's own
/// folder, so the photo stays after the original is deleted from the gallery.
abstract class PhotoSource {
  /// The path of the saved copy, or null when the player cancelled. Throws
  /// [PhotoException] with a message ready to show when it fails.
  Future<String?> pick(PhotoChoice choice);

  /// Deletes a copy made by [pick]. Never throws.
  Future<void> delete(String path);
}

class PhotoException implements Exception {
  const PhotoException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ImagePickerPhotoSource implements PhotoSource {
  ImagePickerPhotoSource({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> pick(PhotoChoice choice) async {
    try {
      final picked = await _picker.pickImage(
        source: choice == PhotoChoice.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 640,
        maxHeight: 640,
        imageQuality: 85,
      );
      if (picked == null) return null;
      final folder = await getApplicationDocumentsDirectory();
      // A new name each time, so the old photo is never shown from the cache.
      final target = p.join(
        folder.path,
        'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await File(picked.path).copy(target);
      return target;
    } on Object {
      throw const PhotoException(
        'Could not get that photo. Check the camera and photo permissions.',
      );
    }
  }

  @override
  Future<void> delete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on Object {
      // A leftover file is harmless.
    }
  }
}
