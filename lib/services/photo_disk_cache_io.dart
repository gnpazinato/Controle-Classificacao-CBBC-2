import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Directory? _cached;

Future<Directory> _cacheDir() async {
  final Directory? existing = _cached;
  if (existing != null) return existing;
  final Directory base = await getApplicationSupportDirectory();
  final Directory dir = Directory('${base.path}/photo_cache');
  await dir.create(recursive: true);
  _cached = dir;
  return dir;
}

/// Nome de arquivo estável derivado da URL: FNV-1a 64 bits em hex +
/// comprimento da URL (colisão só se hash E tamanho coincidirem).
String _fileNameFor(String url) {
  int hash = 0xcbf29ce484222325;
  for (final int unit in url.codeUnits) {
    hash ^= unit;
    hash *= 0x100000001b3;
  }
  return 'p${url.length}_${hash.toUnsigned(60).toRadixString(16)}.img';
}

Future<void> savePhotoToDisk(String url, Uint8List bytes) async {
  try {
    final Directory dir = await _cacheDir();
    final File file = File('${dir.path}/${_fileNameFor(url)}');
    await file.writeAsBytes(bytes, flush: true);
  } catch (_) {
    // Disco cheio ou sem permissão: segue sem cache — foto continua
    // funcionando enquanto houver internet.
  }
}

Future<Uint8List?> loadPhotoFromDisk(String url) async {
  try {
    final Directory dir = await _cacheDir();
    final File file = File('${dir.path}/${_fileNameFor(url)}');
    if (!await file.exists()) return null;
    return await file.readAsBytes();
  } catch (_) {
    return null;
  }
}
