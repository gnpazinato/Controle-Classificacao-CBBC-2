import 'package:http/http.dart' as http;

/// Na web o navegador faz a validação TLS — basta o cliente padrão.
http.Client createBroadcastClient() => http.Client();
