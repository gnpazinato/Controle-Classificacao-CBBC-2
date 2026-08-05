/// Versão visível do app — exibida na tela inicial e atualizada a cada
/// rodada de ajustes documentados em `CHANGELOG.md`.
///
/// Formato semântico **MAJOR.MINOR.PATCH**:
/// - `MAJOR`: mudança que quebra dados antigos (cache, formato de planilha).
/// - `MINOR`: novos recursos sem quebra.
/// - `PATCH`: correções e ajustes pontuais.
///
/// Convenção (lida por humanos e por sessões futuras do Claude Code):
/// 1. Antes de qualquer ajuste, leia este arquivo e o `CHANGELOG.md`.
/// 2. Decida se a mudança é MAJOR, MINOR ou PATCH.
/// 3. Atualize [kAppVersion] aqui **e** adicione a entrada correspondente
///    no topo do `CHANGELOG.md` antes (ou junto) do commit.
const String kAppVersion = '2.9.0';
