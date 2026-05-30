/// Configuração da transmissão pública da quadra ao vivo.
///
/// A transmissão é **opcional** e só funciona quando o tablet está online —
/// exatamente como as fotos puxadas do Google Drive. Sem internet, o app
/// segue 100% funcional e nada disto é acionado.
library;

/// Host do projeto Cloudflare Pages que hospeda o viewer e as Functions.
///
/// ⚠️ Precisa bater com o nome do projeto criado no Cloudflare Pages. Se você
/// criar o projeto com outro nome, troque **apenas** esta linha. O link
/// público gerado tem a forma `https://<host>/v/<codigo>`.
const String kBroadcastHost = 'cbbc-quadra-live.pages.dev';

/// Base completa (https) derivada de [kBroadcastHost].
const String kBroadcastBaseUrl = 'https://$kBroadcastHost';

/// Intervalo do "heartbeat": reenvia o estado atual de tempos em tempos para
/// manter a sessão viva no servidor (que expira após 1h de inatividade).
const Duration kBroadcastHeartbeat = Duration(minutes: 5);

/// Monta a URL pública do viewer para um código de sessão.
String broadcastViewerUrl(String code) => '$kBroadcastBaseUrl/v/$code';
