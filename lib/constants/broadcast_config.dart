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

/// Intervalo do "heartbeat": reenvia o estado atual de tempos em tempos.
///
/// Cumpre dois papéis: mantém a sessão viva no servidor (que expira após
/// 24h sem uso) e serve de **sinal de vida** pro viewer — que marca a
/// transmissão como congelada após [kViewerStaleAfter] sem gravação nova.
/// 30s ⇒ ~2.880 writes/dia por sessão, desprezível no free tier do D1.
const Duration kBroadcastHeartbeat = Duration(seconds: 30);

/// Idade máxima do último envio antes de o viewer considerar o tablet sem
/// conexão (3 heartbeats perdidos) e zerar a quadra com o aviso.
const Duration kViewerStaleAfter = Duration(seconds: 90);

/// `true` se o `age_ms` devolvido pelo servidor indica tablet sem transmitir.
///
/// `null`/ausente/tipo inesperado ⇒ nunca stale — cobre a Function antiga
/// (ainda sem `age_ms`) publicada antes do redeploy do Cloudflare Pages.
bool broadcastAgeIsStale(Object? ageMs) =>
    ageMs is num && ageMs > kViewerStaleAfter.inMilliseconds;

/// Monta a URL pública do viewer para um código de sessão.
String broadcastViewerUrl(String code) => '$kBroadcastBaseUrl/v/$code';
