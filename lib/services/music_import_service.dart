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
    final sourcePath = file.path;
    if (sourcePath == null || sourcePath.isEmpty) {
      return null;
    }

    final source = File(sourcePath);
    final dir = await getApplicationDocumentsDirectory();
    final target = File(
      '${dir.path}${Platform.pathSeparator}${_safeFileName(file.name, sourcePath)}',
    );

    if (source.path != target.path) {
      await source.copy(target.path);
    }

    return target.path;
  }
}

String _safeFileName(String pickerName, String sourcePath) {
  final fallbackName = sourcePath.replaceAll('\\', '/').split('/').last;
  final candidate = pickerName.trim().isEmpty
      ? fallbackName
      : pickerName.trim();
  final sanitized = candidate.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');

  return sanitized.isEmpty ? 'imported-audio' : sanitized;
}
