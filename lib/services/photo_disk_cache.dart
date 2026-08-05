import 'dart:typed_data';

import 'photo_disk_cache_stub.dart'
    if (dart.library.io) 'photo_disk_cache_io.dart' as impl;

/// Cache de fotos em disco — é o que permite o app funcionar sem internet
/// no ginásio depois que os dados foram carregados em casa.
///
/// Toda foto baixada com sucesso é gravada no armazenamento interno do
/// tablet (`photo_cache/` no diretório de suporte do app), com o nome
/// derivado de um hash da URL. Quando o download falha (sem conexão, Drive
/// fora do ar), o retrato é servido do disco.
///
/// Na web não há sistema de arquivos — as funções viram no-op e o viewer
/// segue dependendo da rede, como sempre foi.
Future<void> savePhotoToDisk(String url, Uint8List bytes) =>
    impl.savePhotoToDisk(url, bytes);

Future<Uint8List?> loadPhotoFromDisk(String url) =>
    impl.loadPhotoFromDisk(url);
