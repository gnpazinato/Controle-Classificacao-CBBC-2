import 'dart:typed_data';

/// Web: sem sistema de arquivos — cache de fotos em disco é no-op.
Future<void> savePhotoToDisk(String url, Uint8List bytes) async {}

Future<Uint8List?> loadPhotoFromDisk(String url) async => null;
