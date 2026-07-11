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
      withReadStream: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.single;
    final sourcePath = file.path;
    final dir = await getApplicationDocumentsDirectory();
    final target = File(
      '${dir.path}${Platform.pathSeparator}${_safeFileName(file.name, sourcePath)}',
    );
    await target.parent.create(recursive: true);

    if (sourcePath != null && sourcePath.isNotEmpty) {
      final source = File(sourcePath);
      try {
        if (await source.exists()) {
          if (source.path != target.path) {
            await source.copy(target.path);
          }

          return target.path;
        }
      } on FileSystemException {
        // Some providers expose a path but only allow streamed reads.
      }
    }

    final readStream = file.readStream;
    if (readStream != null) {
      final sink = target.openWrite();
      await readStream.pipe(sink);
      return target.path;
    }

    final bytes = file.bytes;
    if (bytes != null) {
      await target.writeAsBytes(bytes, flush: true);
      return target.path;
    }

    throw const FileSystemException('Selected audio file is not available.');
  }
}

String _safeFileName(String pickerName, String? sourcePath) {
  final fallbackName = sourcePath == null
      ? 'imported-audio'
      : sourcePath.replaceAll('\\', '/').split('/').last;
  final candidate = pickerName.trim().isEmpty
      ? fallbackName
      : pickerName.trim();
  final sanitized = candidate.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');

  return sanitized.isEmpty ? 'imported-audio' : sanitized;
}
