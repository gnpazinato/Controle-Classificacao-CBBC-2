# Controle de Classificação CBBC

App para comissários de quadra conferirem a soma dos pontos funcionais
das equipes em jogos de basquetebol em cadeira de rodas. Os dados da
partida seguem offline; links públicos de foto usam internet quando
existirem. Adaptado pela CBBC (Confederação Brasileira de Basquetebol
em Cadeira de Rodas) a partir do projeto IWBF Team Points Control.

## Diferenças em relação ao IWBF original

- Interface 100% em pt-BR e identidade visual CBBC (azul cobalto +
  laranja basquete).
- Equipes são **clubes** (sem bandeira de país).
- **Sem restrição de gênero entre equipes** — competições mistas são
  permitidas naturalmente.
- Tela de setup tem três checkboxes opcionais de bonificação:
  **Sub-16**, **Sub-23** e **Atleta feminina**. Quando ligados, a
  equipe pode chegar a **15.0 pontos** sem alerta enquanto houver
  atleta da categoria em quadra. Hard cap = 15.0.
- Aceita **planilha .xlsx ou PDF** (texto extraível) com colunas:
  `clube, classe, atleta, camisa, data de nascimento, genero, foto`.

## Como rodar no GitHub Codespaces

1. Crie um repositório `Controle-Classificacao-CBBC` no GitHub.
2. Suba todo o conteúdo desta pasta.
3. Clique em **Code → Codespaces → Create codespace on main**.
4. Aguarde o post-create baixar o Flutter (≈ 2-3 min na primeira vez).
5. No terminal do Codespace:

   ```bash
   flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0
   ```

   O Codespaces abre automaticamente uma URL com a versão Web. Use
   essa URL pra testar no navegador (celular ou desktop). Os dados
   funcionam offline depois do primeiro load; fotos remotas precisam
   de internet para carregar.

## Como gerar o APK Android

O workflow `.github/workflows/build-apk.yml` roda em cada push e
publica o APK release como **artifact** do GitHub Actions. Para baixar:

1. Vá em **Actions** no GitHub.
2. Abra o último run de `Build Android APK`.
3. Em **Artifacts**, baixe `controle-classificacao-cbbc-apk`.

O APK não está assinado para Play Store (usa keystore debug). Para
publicação oficial, gere uma keystore e configure `signingConfigs` em
`android/app/build.gradle`.

## Estrutura

- `lib/screens/` — telas (load, summary, setup, lineup, missing).
- `lib/models/` — Player, Team, MatchState, BonusRules.
- `lib/services/` — parser xlsx, parser PDF, template, cache.
- `lib/widgets/` — logo header, jersey icon, retrato do atleta.
- `lib/theme/cbbc_theme.dart` — paleta e tema Material 3.
- `assets/images/cbbc-logo.png` — logo CBBC oficial.

## Modelo da planilha

Aba única `Atletas`:

| clube           | classe | atleta              | camisa | data de nascimento | genero | foto |
| --------------- | ------ | ------------------- | ------ | ------------------ | ------ | ---- |
| ADD Vitória     | 4,5    | João Silva          | 10     | 15/04/1995         | M      | link público |
| Cruzeiro CR     | 1,0    | Mariana Ribeiro     | 4      | 22/09/2002         | F      | link público |

Ou uma aba por clube (omite a coluna `clube`). Baixe os modelos
diretamente do botão **Baixar modelo** na home do app.

## Licença

Uso interno CBBC. Código base sob a mesma licença do projeto original.
