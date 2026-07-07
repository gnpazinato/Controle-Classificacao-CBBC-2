# Controle de Classificação CBBC — contexto auto-carregado

> Lido automaticamente no início de cada sessão.

## O que é

Fork do IWBF Team Points Control adaptado para a CBBC (Confederação
Brasileira de Basquetebol em Cadeira de Rodas). UI 100% pt-BR.

## Convenções principais

- **Clube no lugar de país.** Sem bandeira, sem `CountryResolverService`.
  Campos do modelo são `clubName` e `fullName` (não `surname/firstName`).
- **Mixed gender é permitido.** Não há dialog/alerta de "gender
  mismatch". `Team` não carrega gênero.
- **Bonificação** vive em `BonusRules` (campo `_bonusRules` de
  `MatchState`). Quando há atleta qualificado em quadra, o
  `effectiveLimitTeamX` sobe para `kBonusPointCeiling = 15.0`.
- **Parsers**: `SpreadsheetParserService` (xlsx) e `PdfParserService`
  (PDF texto-extraível via `syncfusion_flutter_pdf`). Os dois usam
  `canonicalField` de `lib/services/column_mapping.dart` para
  mapear cabeçalhos pt-BR/EN → campo canônico.
- **Comissão técnica**: coluna `função` (`funcao`/`cargo`/`role`) na
  planilha. Valor ≠ "atleta" vira `StaffMember` (só nome obrigatório),
  guardado em `Team.staff`. Aparece no resumo da importação (nome ……
  função), nunca em quadra.
- **Importação por link**: `LinkImportService`
  (`lib/services/link_import_service.dart`) aceita link público de
  planilha OU pasta (Google Drive via `embeddedfolderview`, sem chave de
  API; OneDrive pessoal via `api.onedrive.com/v1.0/shares/u!<token>`).
  Em pasta: planilha na raiz + subpasta de fotos por equipe; fotos
  casadas por nome de arquivo em `roster_photo_matcher.dart`.
- **Cores**: `CbbcColors` em `lib/theme/cbbc_theme.dart`. Azul cobalto
  primário, laranja basquete secundário.

## Build local / Codespaces

- `.devcontainer/post-create.sh` baixa Flutter 3.32.0 e roda
  `flutter create .` pra gerar arquivos Android/Web faltantes.
- Local: `flutter pub get && flutter analyze && flutter test &&
  flutter run -d web-server --web-port 8080`.
- **Codespace Alpine (musl)**: o post-create instala `gcompat` pro Dart
  rodar. Limitação conhecida: testes de widget que montam `MaterialApp`
  podem estourar a pilha nesse ambiente (thread musl pequena) — o
  smoke_test falha localmente mesmo em árvore limpa. O suite completo é
  validado no CI (ubuntu).

## CI

- Workflow `.github/workflows/build-apk.yml` roda em push pra main /
  feat/* / fix/*. Gera APK release não-assinado (keystore debug).

## Versionamento (OBRIGATÓRIO antes de qualquer ajuste)

A cada rodada de ajustes:

1. Leia o topo do `CHANGELOG.md` e o `lib/constants/app_version.dart`
   pra saber a versão atual.
2. Faça os ajustes pedidos pelo usuário.
3. Atualize `kAppVersion` em `lib/constants/app_version.dart` aplicando
   o bump correto:
   - **PATCH** (`X.Y.Z` → `X.Y.Z+1`): bug/ajuste de texto/visual.
   - **MINOR** (`X.Y.Z` → `X.Y+1.0`): novo recurso/tela/regra.
   - **MAJOR** (`X.Y.Z` → `X+1.0.0`): quebra dados antigos ou redesenha
     o fluxo principal.
4. Adicione a entrada nova no topo do `CHANGELOG.md` (data
   `YYYY-MM-DD` + lista curta dos ajustes).
5. Não pergunte ao usuário se ele quer atualizar a versão — ele já
   pediu uma vez (essa convenção foi acordada). Apenas atualize.

A versão é exibida na home (abaixo da frase "Dados offline. Fotos usam
internet quando houver link.").

## Estado

- Histórico completo no `CHANGELOG.md` (fonte da verdade de versões).
- v2.5.0 — link de transmissão fixo por tablet (credenciais persistidas
  no `CacheService`, retomadas via `BroadcastService.resume`; TTL de 24h
  no servidor — mudanças em `functions/` exigem redeploy do Cloudflare
  Pages) + viewer público com placar, relação de atletas e comissão
  técnica (widgets compartilhados `match_header.dart` e
  `team_roster_list.dart`).
- v2.4.x — importação por link do Drive/OneDrive (planilha ou pasta com
  fotos por equipe, último link persistido) + comissão técnica via
  coluna `função`.
- v0.1.0 — primeira release CBBC, migrada do IWBF Team Points Control.
