import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Implementação Android/iOS/desktop do saver de templates.
Future<String?> defaultSaveTemplate(String filename, Uint8List bytes) async {
  final String? path = await FilePicker.platform.saveFile(
    dialogTitle: 'Salvar modelo CBBC',
    fileName: filename,
    type: FileType.custom,
    allowedExtensions: <String>['xlsx'],
    bytes: bytes,
  );
  return path;
}
