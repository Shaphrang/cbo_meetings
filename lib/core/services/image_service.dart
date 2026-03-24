//lib\core\services\image_service.dart
import 'dart:io';
import 'package:image/image.dart' as img;

class ImageService {

  Future<File> compress(File file) async {

    final bytes = await file.readAsBytes();

    final image = img.decodeImage(bytes);

    if (image == null) {
      return file;
    }

    int quality = 75;
    late List<int> compressed;

    do {

      compressed = img.encodeJpg(image, quality: quality);
      quality -= 5;

    } while (compressed.length > 200 * 1024 && quality > 20);

    final compressedFile = File(file.path);

    await compressedFile.writeAsBytes(compressed);

    return compressedFile;
  }
}