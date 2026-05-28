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
- **Cores**: `CbbcColors` em `lib/theme/cbbc_theme.dart`. Azul cobalto
  primário, laranja basquete secundário.

## Build local / Codespaces

- `.devcontainer/post-create.sh` baixa Flutter 3.24.5 e roda
  `flutter create .` pra gerar arquivos Android/Web faltantes.
- Local: `flutter pub get && flutter analyze && flutter test &&
  flutter run -d web-server --web-port 8080`.

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

- v0.2.0 — segunda rodada de ajustes (templates anônimos, edição no
  resumo, cores de camiseta, indicador de bonificação, rotação livre,
  ícone CBBC, AppBar reposicionada).
- v0.1.0 — primeira release CBBC. Sem testes herdados do IWBF (deletados
  na migração — só `test/smoke_test.dart` valida render + bonus rules).
