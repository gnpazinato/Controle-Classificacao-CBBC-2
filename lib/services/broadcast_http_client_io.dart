import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../constants/broadcast_config.dart';

/// Cliente HTTP para mobile/desktop.
///
/// Tablets com Android antigo (< 7.1.1) não confiam mais na raiz da Let's
/// Encrypt (a cross-assinatura *DST Root CA X3* expirou em set/2021), então o
/// handshake TLS com o Cloudflare falha com `CERTIFICATE_VERIFY_FAILED:
/// certificate has expired` — mesmo o certificado sendo legítimo e atual.
/// (Por isso as fotos do Google Drive funcionam: o Google usa outra raiz.)
///
/// Para destravar a transmissão nesses tablets, aceitamos o certificado
/// **somente** para o host da transmissão ([kBroadcastHost]) — que serve
/// dados públicos (o placar) e nada sensível. Qualquer outro host continua
/// com validação normal.
http.Client createBroadcastClient() {
  final HttpClient inner = HttpClient()
    ..badCertificateCallback =
        (X509Certificate cert, String host, int port) => host == kBroadcastHost;
  return IOClient(inner);
}
