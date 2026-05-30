// Fábrica do http.Client usado pela transmissão. Em mobile (dart:io) ela
// contorna o certificado expirado em Androids antigos; na web devolve o
// cliente padrão (o navegador cuida do TLS). Import condicional resolve qual.
export 'broadcast_http_client_io.dart'
    if (dart.library.js_interop) 'broadcast_http_client_web.dart';
