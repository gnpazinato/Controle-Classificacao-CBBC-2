import 'dart:typed_data';

import 'template_saver_stub.dart'
    if (dart.library.io) 'template_saver_io.dart'
    if (dart.library.html) 'template_saver_web.dart' as impl;

Future<String?> defaultSaveTemplate(String filename, Uint8List bytes) =>
    impl.defaultSaveTemplate(filename, bytes);
