import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Service that lets the user import a local audio file.
class MusicImportService {
  /// Opens the platform file picker and returns a local path when a supported file is selected.
  Future<String?> pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowCompression: false,
      withData: false,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.single;
    if (file.path == null) {
      return null;
    }

    final source = File(file.path!);
    final dir = await getApplicationDocumentsDirectory();
    final target = File('${dir.path}/${file.name}');
    if (!await target.exists()) {
      await source.copy(target.path);
    }
    return target.path;
  }
}
