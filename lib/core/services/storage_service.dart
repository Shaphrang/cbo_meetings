//lib\core\services\storage_service.dart
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class StorageService {

final supabase = Supabase.instance.client;

Future<String> uploadImage(File file) async {

final fileName =
    "${DateTime.now().millisecondsSinceEpoch}.jpg";

try {

  await supabase.storage
      .from('meeting_photos')
      .upload(
        fileName,
        file,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: false,
        ),
      );

  final publicUrl = supabase.storage
      .from('meeting_photos')
      .getPublicUrl(fileName);

  return publicUrl;

} catch (e) {

  debugPrint("Image upload failed: $e");
  rethrow;
}
}
}
