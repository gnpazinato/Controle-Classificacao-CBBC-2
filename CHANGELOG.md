# Changelog

Todas as mudanças visíveis ao usuário são registradas aqui. O número da
versão segue **SemVer** (`MAJOR.MINOR.PATCH`) e é exibido na tela inicial
do app, abaixo da frase "Dados offline. Fotos usam internet quando houver
link."

> **Para sessões futuras do Claude Code (instruções obrigatórias):**
> Antes de fazer qualquer ajuste no projeto:
> 1. Leia o topo deste arquivo para saber a versão atual.
> 2. Leia o `lib/constants/app_version.dart` para confirmar.
> 3. Decida o bump de versão pelo tipo de mudança:
>    - **PATCH** (`X.Y.Z` → `X.Y.Z+1`): correção de bug, ajuste de texto,
>      melhoria visual pontual.
>    - **MINOR** (`X.Y.Z` → `X.Y+1.0`): novo recurso, nova tela, nova
>      regra de negócio.
>    - **MAJOR** (`X.Y.Z` → `X+1.0.0`): mudança que quebra dados antigos
>      ou redesenha o fluxo principal.
> 4. Atualize `kAppVersion` em `lib/constants/app_version.dart`.
> 5. Adicione a nova entrada no topo deste arquivo (abaixo do bloco de
>    instruções), com a data no formato `YYYY-MM-DD` e uma lista curta
>    dos ajustes.
> 6. Faça o ajuste pedido pelo usuário.

---

## 2.12.0 — 2026-08-06

- **Substituição com pré-seleção (fila de entrada).** Com a quadra
  cheia, tocar numa atleta do banco a coloca na fila de entrada — card
  laranja com o selo da ordem ("1º ENTRA", "2º ENTRA"…). Tocar em quem
  está em quadra (no desenho ou na lista) efetiva a troca com a primeira
  da fila, na mesma posição; tocar de novo numa pré-selecionada cancela.
  Com vaga em quadra ou sem fila, os gestos continuam como sempre foram.
  A fila é por equipe, sobrevive à restauração de sessão e é esvaziada
  pelos botões de limpar. Aprovado via prévia interativa.
- **Botões "Limpar" espelhados.** "Limpar Equipe A" ancorado à esquerda
  e "Limpar Equipe B" à direita — cada um do lado da lista da sua
  equipe; os botões neutros ficam no centro.
- **Aviso de atualização ao voltar pra tela inicial.** A checagem de
  nova versão agora roda também quando você volta pra tela inicial (não
  só na abertura do app) — release publicada durante a partida aparece
  sem precisar fechar e reabrir o aplicativo.

## 2.11.0 — 2026-08-06

- **Bonificação lembrada entre jogos.** A seleção Sub-16/Sub-23/feminina
  agora é salva junto com os dados da competição no tablet: marca uma
  vez e ela volta marcada nos próximos jogos, mesmo fechando o app ou
  desligando o tablet. O re-sync da planilha não apaga a escolha. Ela
  zera ao importar uma competição nova ou escolher "Começar do zero".
  O bloqueio automático (atleta sem data de nascimento) continua valendo
  e não sobrescreve a preferência salva.

## 2.10.1 — 2026-08-06

- **Badge de nome + placar da quadra 25% maior.** A pílula
  "NOME | pontos / limite" nas faixas do topo e da base da quadra ficou
  25% maior (fonte, paddings e raio, tudo proporcional) pra melhorar a
  leitura à distância. Chips, formação e margens não mudaram; opção
  aprovada via prévia HTML comparando +25/+45/+65%.

## 2.10.0 — 2026-08-06

- **Aviso persistente de bateria baixa.** Abaixo de 30% fora da tomada,
  um selinho aparece no topo de todas as telas (o app esconde a barra de
  status do Android no modo imersivo): "Bateria X% — coloque o tablet
  para carregar". Abaixo de 15% fica vermelho. O toque alterna para um
  formato compacto (ícone + %) pra não atrapalhar a partida, mas o aviso
  só some de verdade ao conectar o carregador ou recuperar a carga.
  Reage na hora ao plugar/desplugar; o nível é relido a cada minuto.

## 2.9.0 — 2026-08-05

- **Atualização por cima, sem desinstalar.** O APK agora é assinado com
  uma chave fixa, fornecida ao CI pelos secrets `KEYSTORE_BASE64` e
  `KEYSTORE_PASSWORD` (nenhum material de chave fica no repositório).
  Antes, cada build do CI saía com uma chave debug diferente e o Android
  recusava instalar por cima — era preciso desinstalar, o que apagava os
  dados e gerava um novo link de transmissão. A partir desta versão,
  instalar a atualização por cima mantém tudo: dados salvos, elenco
  offline e o link fixo do tablet. Atenção: a troca de chave exige
  desinstalar UMA última vez ao migrar da 2.8.0 (ou anterior) para esta.
- **Aviso "Nova versão disponível" na tela inicial.** O app consulta a
  release mais recente no GitHub e, havendo versão mais nova, mostra um
  cartão verde com o número da versão; o toque baixa o APK direto no
  tablet (sem baixar no computador e transferir). Sem internet, o aviso
  simplesmente não aparece.
- **CI publica o APK como GitHub Release** a cada push na main (tag
  `vX.Y.Z`) — é de lá que o botão de atualização baixa o arquivo.

## 2.8.0 — 2026-08-05

- **Sincronização automática com a planilha da nuvem.** No modo link
  (Drive/OneDrive), o app re-importa a planilha e as pastas de fotos
  sozinho: ao entrar na tela de seleção de equipes, ao voltar de uma
  partida e a cada 15 segundos em segundo plano. Alterações na planilha
  (atletas, classes, equipes novas, fotos novas ou movidas de pasta)
  aparecem sem recarregar o link na tela inicial. A partida em andamento
  nunca é alterada — os dados novos valem pro próximo jogo. Uma faixa na
  tela de configuração mostra o estado: sincronizando, sincronizada às
  HH:MM ou sem conexão (usando os dados salvos).
- **Modo offline de verdade.** Toda importação bem-sucedida grava o
  elenco completo da competição no tablet, e cada foto baixada fica
  arquivada no armazenamento interno. Sem internet no ginásio, o app
  funciona normalmente com os últimos dados sincronizados — inclusive os
  retratos em quadra. Internet instável não derruba nada: cada tentativa
  de sync que falha mantém os dados salvos e tenta de novo no próximo
  ciclo.
- **"Carregar dados da competição anterior?"** Ao abrir o app sem
  partida em andamento, ele oferece retomar a competição salva (com
  contagem de equipes e atletas) ou começar do zero. Retomando com
  internet, a planilha é sincronizada na sequência; sem internet, valem
  os dados do tablet. Ao restaurar uma sessão de partida, o elenco
  completo da competição também volta pro dropdown de equipes.

## 2.7.0 — 2026-08-05

- **Nome da equipe na quadra, com placar maior.** O quadrinho de canto deu
  lugar a uma linha única `NOME DA EQUIPE | pontos / limite` na faixa do
  topo (Equipe A, à esquerda) e da base (Equipe B, à direita), com fonte
  ~45% maior; nome longo trunca com "…" sem esconder o placar. A formação
  3+2 se aproximou do meio da quadra e os chips se afastaram lateralmente;
  foto do mesmo tamanho, número da camisa e classe ~15% maiores e estrela
  de bonificação levemente menor (não encosta mais na classe do vizinho).
  Tudo idêntico no tablet e no link de transmissão.
- **Viewer avisa quando o tablet perde a conexão.** Se o tablet ficar ~90s
  sem transmitir, o link ao vivo zera a quadra (nenhum chip) e mostra o
  aviso central "Sem conexão com o tablet"; volta ao normal sozinho quando
  o sinal retorna. Heartbeat da transmissão encurtado de 5 min para 30s e
  duas correções de bastidor: a sessão retomada volta a ser mantida viva
  pelo heartbeat mesmo sem toques na quadra, e o heartbeat não intercala
  mais com um envio em andamento. ⚠️ Exige **redeploy do Cloudflare
  Pages** (o GET da sessão agora devolve `age_ms`).

## 2.6.0 — 2026-08-03

- **Data de nascimento opcional na importação.** Atleta sem data (célula
  em branco ou coluna ausente) entra normalmente na planilha e no PDF;
  só datas preenchidas mas ilegíveis geram aviso. Em compensação, na
  configuração da partida os switches **Sub-16** e **Sub-23** ficam
  bloqueados (com o motivo exibido) enquanto houver atleta sem data de
  nascimento nas equipes envolvidas — sem como comprovar idade, não há
  bonificação por categoria. O switch de atleta feminina segue livre.
- **Casamento de fotos mais esperto.** A foto agora casa também quando a
  planilha traz o nome abreviado e o arquivo traz o nome completo
  ("GUSTAVO LASMAR" ↔ "Gustavo Freitas Lasmar.png"). Conectores ("de",
  "da", "dos"...) são ignorados na comparação e palavras com 5+ letras
  toleram uma única diferença de grafia ("Vitor" ↔ "Victor",
  "Henirque" ↔ "Henrique") — grafia exata continua vencendo a
  aproximada quando as duas existem no elenco. Sobrenomes divergentes do
  mesmo atleta também casam quando o primeiro nome é único no clube
  ("Wandemberg Nejaim.png" ↔ "WANDEMBERG DO NASCIMENTO"); com dois
  atletas de mesmo primeiro nome em dúvida, a foto fica sem dono e vira
  aviso, sem impedir a importação.

## 2.5.1 — 2026-07-07

- **Foto da comissão técnica cortada como a das atletas.** O avatar
  redondo do viewer agora usa o mesmo detector de rosto dos chips da
  quadra (recorte "rosto + ombros"), eliminando a faixa de fundo vazia
  que sobrava acima da cabeça em fotos tiradas de longe.

## 2.5.0 — 2026-07-07

- **Link de transmissão fixo por tablet.** O link da quadra deixa de ser
  por partida: é criado uma vez, fica salvo no tablet e é retomado
  automaticamente em toda partida nova (trocar equipes, voltar, fechar o
  app ou reiniciar o tablet não muda o link). Só é gerado um código novo
  se a transmissão ficar 24 horas sem uso (fim da competição) ou se o
  usuário tocar em "Encerrar". Até 3 tablets/quadras podem transmitir ao
  mesmo tempo (o servidor aceita 6 sessões, com margem pra links antigos
  ainda não expirados). ⚠️ Exige redeploy das Functions no Cloudflare
  Pages (o TTL de 24h vive em `functions/api/session.js`).
- **Página pública completa.** O link agora mostra, além da quadra ao
  vivo: o cabeçalho com placar da classificação, a relação completa de
  atletas das duas equipes nas laterais (com quem está em quadra
  destacado, igual à tela do tablet) e a **comissão técnica** de cada
  equipe embaixo da relação — foto redonda (quando houver), nome e
  função. Nenhum botão operacional aparece. Em telas estreitas
  (celular em pé) o conteúdo vira uma coluna rolável. A tela do tablet
  segue sem a comissão técnica.
- **Heartbeat da transmissão corrigido.** O reenvio periódico agora
  reutiliza o último estado enviado, mantendo a sessão viva no servidor
  mesmo sem toques na quadra.
- **Texto da home.** Botão renomeado para "Importar por link (Google
  Drive ou OneDrive)".

## 2.4.1 — 2026-07-07

- **Comissão técnica no padrão visual da lista.** No resumo da
  importação, cada membro da comissão usa os mesmos retângulos das
  linhas de atleta: o campo do nome ocupa o espaço restante e o campo
  da função fica alinhado à lateral direita (os dois editáveis).
  Substitui o pontilhado da 2.4.0.
- **Último link importado fica salvo.** O campo do diálogo "Importar
  por link" abre preenchido com o último link usado — mesmo depois de
  fechar o app ou desligar/reiniciar o tablet. "Começar do zero" não
  apaga o link.

## 2.4.0 — 2026-07-07

- **Importação por link do Google Drive/OneDrive.** Novo card na tela
  inicial: cole o link público de uma **planilha** (arquivo .xlsx/PDF ou
  Google Planilhas) ou de uma **pasta**. Com pasta, o app localiza a
  planilha na raiz e procura, em uma subpasta por equipe, as fotos de
  atletas e comissão técnica — associadas pelo nome do arquivo (ex.:
  `Gabriela.jpg` ou `Gabriela Giolo.png` → atleta "Gabriela Giolo"). As
  fotos aparecem em quadra quando a pessoa entra em jogo. O link precisa
  estar compartilhado como "qualquer pessoa com o link" (OneDrive
  pessoal; SharePoint corporativo exige login e não é suportado). No
  Android o recurso funciona por completo; no navegador o Google Drive
  pode bloquear o acesso (CORS).
- **Comissão técnica na planilha.** Nova coluna `função` (aceita também
  `cargo`/`role`): linhas com valor diferente de "atleta" (ex.:
  "Técnico", "Fisioterapeuta") entram como comissão técnica — só o nome
  é obrigatório. No resumo da importação, os membros aparecem no fim da
  lista de cada equipe no formato `Nome …… Função`. Eles não aparecem na
  tela de jogo.
- Modelos de planilha atualizados com a coluna `função` e exemplos de
  comissão técnica.
- Avisos de importação novos: pasta de fotos não encontrada para uma
  equipe e fotos sem correspondência de nome.

## 2.3.4 — 2026-05-29

- **Fotos das jogadoras agora carregam no viewer web.** O carregamento das
  fotos usava `NetworkAssetBundle`, que depende de `dart:io` e **não funciona
  no Flutter Web** (compilava, mas falhava em runtime → silhueta). Trocado por
  `package:http`, que funciona nas duas plataformas (fetch na web, cliente
  nativo no Android). Combinado com a reescrita pro `lh3.googleusercontent.com`
  (v2.3.3), as fotos aparecem na transmissão. O carregamento no tablet segue
  pela mesma engine de antes.

## 2.3.3 — 2026-05-29

- **Corrige o link público que abria a quadra e voltava pra tela inicial.**
  A rota `/v/<codigo>` empilhava a home (Splash) atrás do viewer e, após
  ~2,5s, o timer do Splash trocava o viewer pela tela inicial. Agora a rota
  inicial é resolvida por `onGenerateInitialRoutes`, abrindo **somente** o
  viewer — ele permanece na tela.
- **Fotos das jogadoras agora aparecem no viewer web.** O endpoint
  `drive.google.com/uc` não envia CORS (e bloqueia o navegador), então as
  fotos sumiam na página pública. O viewer passa a reescrever as URLs do
  Drive para `lh3.googleusercontent.com/d/<id>`, que serve a imagem com CORS.
  Vale só para a transmissão; o app no tablet continua usando o link normal.

## 2.3.2 — 2026-05-29

- **Corrige a transmissão em tablets com Android antigo.** O handshake TLS
  com o Cloudflare falhava com `CERTIFICATE_VERIFY_FAILED: certificate has
  expired` — porque a raiz da Let's Encrypt (DST Root X3) expirou em 2021 e
  não é mais reconhecida em Androids antigos (as fotos do Drive funcionavam
  por usarem outra raiz). Agora o app aceita o certificado **somente** para o
  host da transmissão (dado público), destravando a transmissão nesses
  tablets sem afetar nenhuma outra conexão.
- **Nome oficial "Controle Classificação CBBC" em todos os lugares**: ícone e
  info do app no Android, título em janelas recentes, cabeçalho das telas,
  PWA e título/descrição da web.

## 2.3.1 — 2026-05-29

- **Nome do app** alterado de "Controle CBBC" para **"Controle Classificação
  CBBC"** (ícone no tablet, PWA e título web).
- **Mensagem de erro da transmissão mais honesta.** Antes, qualquer falha ao
  iniciar a transmissão dizia "sem internet" — mesmo quando o problema era
  outro (timeout, DNS, etc.). Agora mostra o erro real e distingue timeout,
  facilitando o diagnóstico quando a transmissão não inicia no tablet.

## 2.3.0 — 2026-05-29

- **Transmissão pública da quadra ao vivo (novo recurso).** Um botão
  discreto na barra superior da tela de jogo (ícone de transmissão) inicia,
  com um toque, uma transmissão pública só da quadra — chips das atletas e
  placar nos cantos, sem barras nem botões. Abre uma janelinha (pop-up) com
  **QR code** e o **link copiável**; o mesmo botão reabre a janelinha quando
  fechada. O link tem a forma `…/v/<codigo>` (código de 5 caracteres).
  - **Funciona só online**, igual às fotos do Google Drive: sem internet, o
    app segue 100% normal e o botão apenas avisa que precisa de conexão.
  - A página pública atualiza em tempo quase real (~1s) e suporta vários
    espectadores ao mesmo tempo (ideal para espelhar no OBS → YouTube).
  - **Encerrar** na janelinha derruba a transmissão; ela também expira
    sozinha após 1h sem atividade.
  - Backend serverless no Cloudflare Pages + D1 (free tier). O widget da
    quadra foi extraído para `lib/widgets/court_view.dart` e é reusado
    idêntico na tela de jogo e no viewer público — sem mudança visual na
    partida.

## 2.2.1 — 2026-05-29

- **Correção do crop em fotos tiradas "de longe".** Algumas atletas
  (sobretudo as fotos de corpo inteiro/sentadas em cadeira, com a
  cabeça pequena e bastante parede em volta) apareciam com o rosto
  fora do enquadramento — o recorte caía num canto vazio da foto ou
  pegava a imagem inteira. Causa: em fundos cinza com vinheta/sombra
  nos cantos, os pixels escuros das bordas eram confundidos com a
  atleta, jogando o centro e o topo detectados pra fora dela.
  - A detecção do sujeito agora **ignora uma margem horizontal** (a
    atleta nunca encosta na borda lateral do retrato) e exige uma
    **sequência contígua** de pixels — ruído espalhado nos cantos não
    forma sequência e é descartado.
  - Com a detecção robusta, o mesmo enquadramento padronizado
    (rosto + ombros) passa a valer pros quatro formatos de foto: só
    rosto, close-up (torso + rosto), enquadramento médio e foto de
    longe. As fotos que já cortavam bem **não mudaram**.

## 2.2.0 — 2026-05-29

- **Crop inteligente com detecção de close-up.** Algoritmo de
  enquadramento reescrito em duas frentes:
  1. **Cor de fundo adaptativa.** Antes assumia fundo branco
     (saturação < 22). Agora amostra os pixels das bordas
     superior/laterais e calcula a cor mediana do fundo. Funciona com
     fundos coloridos (verde, azul, cinza), escuros ou texturizados —
     resolve o "crop ruim" em fotos onde o background não era branco.
  2. **Branch close-up.** Antes de cortar, mede se a altura ideal do
     enquadramento (rosto + ombros) já não cabe na foto. Se a foto
     **já veio em close**, pula o crop vertical e só recentraliza no
     rosto — evita cortar nos olhos em fotos tipo 3×4 que já vêm bem
     enquadradas.
- **Badge de classe mais elegante.** Pill ~13 % menor, borda branca
  fina (1.1 px) pra destacar sobre a foto, raio de canto maior
  (0.34 × tamanho), fonte w800 com letter-spacing levemente negativo
  e sombra mais sutil. O overhang lateral caiu de 0.70 → 0.50, então
  o badge não invade mais o chip vizinho na linha de 3 atletas da
  frente.
- **Teste visual de regressão do crop.** Novo `portrait_crop_visual_
  test.dart` gera 6 "fotos" sintéticas (close-up, rosto distante,
  fundo branco/verde/cinza, cabelo encostado no topo) e produz uma
  grade em `test/_artifacts/portrait_crop_cases.png` mostrando o
  retângulo escolhido sobre a original e o resultado no chip. Permite
  detectar regressões visuais a olho nu antes de qualquer mudança no
  algoritmo.

## 2.1.0 — 2026-05-28

- **Quadra interativa: toque na foto da jogadora pra remover.** Antes só
  dava pra remover pela lista lateral. Agora a quadra é totalmente
  interativa — o mesmo `togglePlayer` é disparado pelo chip em quadra
  com `InkWell` recortado no formato do retrato. Funciona em paralelo
  com o tap nas listas laterais (não substitui — soma).
- **Enquadramento padronizado das fotos.** Algoritmo de crop facial
  reescrito para sempre mostrar **rosto + pescoço + ombros + um pouco
  da camiseta**, com escala derivada da largura da cabeça detectada
  (não mais da altura total do sujeito). Atletas que ficavam coladas
  no rosto (Gabriela 21, Geisa 22, Maria do Carmo 89) passam a sair
  com o mesmo "tamanho aparente" das que já estavam boas (Ivanilde 4,
  Paola 41, Bruna 9, Adrienne 11). Mínimo 38 % e máximo 65 % da altura
  da foto pra evitar crops minúsculos quando a detecção falhar.
- **Badge da classe na cor da camiseta, sem borda, deslocado pra cima.**
  O retângulo branco com a classe da atleta passou a:
  1. usar `JerseyColor.fill` (mesma cor que o número da camisa) com
     o número da classe pintado em `numberColor`;
  2. perder a borda branca e a estria azul vertical — só uma sombra sutil;
  3. subir 14 % da altura do chip (de `top: 0.18 × h` pra `0.04 × h`)
     e deslocar mais pra esquerda (de `-55 %` pra `-70 %` do badge),
     longe do rosto da atleta.
- **Layout responsivo da quadra.** Tudo dentro do retângulo da quadra
  escala em **percentual da largura da quadra** (não mais em pixels
  fixos): score badge dos cantos com `fontSize = w × 0.034`,
  `padding = w × 0.022 × 0.014`, `margem = w × 0.018`; chips com
  `slotMaxWidth = w × 0.22` e `slotMaxHeight = h × 0.16` sem clamps
  absolutos. Em tablets paisagem (~400 px de largura de quadra) e
  retrato (~600 px), o badge fica proporcional aos chips e não invade
  a foto das atletas das extremidades.
- **Testes de layout responsivo + screenshots automáticos.** Novo
  `test/court_simulation_test.dart` renderiza a quadra simulada em
  quatro viewports (320×600, 400×750, 600×1124, 800×1500) e valida
  geometricamente que os score badges não sobrepõem os chips das
  extremidades. Cada teste exporta um PNG em `test/_artifacts/` pra
  inspeção visual antes do build do APK. Novo
  `test/lineup_layout_test.dart` valida que `onTap` no chip dispara
  callback e que badges escalam com o tamanho do chip.

## 2.0.4 — 2026-05-28

- **Linha de fundo das duas equipes mais próxima do centro.** As 2
  atletas atrás passaram de `y = 0.31` (Equipe A) / `y = 0.69`
  (Equipe B) para `y = 0.37` / `y = 0.63`. O gap interno de cada equipe
  cresceu de ~0.08 (apertado) para ~0.14, e o vão central entre as
  equipes caiu de ~0.28 (~260 px vazios) para ~0.16 (~148 px) — a
  quadra fica mais preenchida sem aproximar demais as equipes
  (separação clara, como pedido).

## 2.0.3 — 2026-05-28

- **Pré-cache de fotos das atletas em quadra.** Ao abrir a tela de
  partida, o app já dispara em background o download + crop facial das
  fotos das duas equipes (todas as atletas, não só as 5 titulares).
  Carregamento é feito em **lotes de 6 paralelos**, sequenciais — gentil
  com a rede do tablet e evita rate-limit do Drive em ~24 requests
  simultâneos. Quando o usuário coloca uma atleta em quadra, a foto
  aparece sem o "delay de internet" — vem do cache síncrono já populado.
  Tela continua interativa durante o pré-cache (fire-and-forget).
- **Mais espaçamento entre as 3 atletas lado a lado.** Linha de frente
  passou de `x = 0.28 / 0.50 / 0.72` para `x = 0.22 / 0.50 / 0.78`
  (gap calculado de ~1 px → ~31 px entre badges das chips vizinhas).
  Linha de fundo (2 atletas) ficou em `0.36 / 0.64` (já confortável).

## 2.0.2 — 2026-05-28

- **Novas artes de quadra (`quadra1.png` clara, `quadra2.png` escura).**
  Substituem as antigas `court.png` e `wbk-court2.png`. Os originais
  vieram em 4096 × 2192 (~5 MB cada) e foram redimensionados para
  1700 × 910 (~1,1–1,5 MB) para enxugar o APK. Ambos são landscape e
  passam pelo `quarterTurns: 1` para caber no container vertical.
- **Placar dos cantos visível.** Os badges de placar (canto superior
  esquerdo e inferior direito da quadra) passaram a ser renderizados
  por último no Stack, ficando acima dos chips quando houver
  sobreposição. Também ganharam tamanho um pouco maior, fonte mais
  forte e sombra "botão flutuante" no mesmo padrão dos chips — sem
  borda azul fininha.
- **Atletas mais centralizadas em quadra.** As 3 atletas da linha de
  frente passam a ocupar `x = 0.28 / 0.50 / 0.72` (antes 0.20/0.50/0.80)
  e as 2 da linha de fundo `x = 0.36 / 0.64` (antes 0.32/0.68). Linha
  de frente também desceu de `y=0.10` para `y=0.13`, abrindo espaço
  pros cantos sem invadir o garrafão.
- **Número da camisa mais pra fora do rosto.** Badge da camisa passou
  de `-14 %` para `-45 %` do tamanho fora do retrato — quase todo o
  badge fica do lado de fora, deixando o rosto livre.
- **Sem flash de várias fotos ao tirar atleta da quadra.** Adicionada
  `ValueKey(player.id)` em cada `_CourtPlayerSlot`: ao remover uma
  jogadora, o Flutter casa os widgets remanescentes por identidade
  (não por posição na lista), então outras fotos não recarregam.
- **Cache síncrono de retratos.** A foto resolvida fica num mapa
  síncrono além do mapa de futures; ao montar um chip com URL
  já carregado em alguma rodada anterior, a foto aparece sem o frame
  de silhueta intermediário.

## 2.0.1 — 2026-05-28

- **Quadra com orientação correta.** Rotação agora depende da imagem
  escolhida: `wbk-court2.png` (clara, já portrait) é renderizada sem
  rotação; `court.png` (antiga, landscape) ganha o `quarterTurns: 1`
  histórico. Corrige o efeito de "faixa estreita" que aparecia na 2.0.0.
- **Toggle de estilo da quadra (clara/escura) em tempo real.** Duas
  bolinhas miniatura abaixo da quadra alternam o piso instantaneamente
  (assets pré-carregados via `precacheImage`, sem flicker).
- **Quadra maior + formação 3+2.** Em tablet, o flex da quadra subiu de
  `3:4:3` para `3:5:3`. Os 5 atletas de cada equipe passam a ocupar uma
  linha de 3 perto do garrafão + uma linha de 2 mais atrás (antes era
  2+2+1, que aglomerava as equipes no meio campo).
- **Chips sem moldura.** Removida a borda branca fina e o fundo branco
  ao redor dos retratos — restou só a sombra projetada para o chip
  parecer flutuar. Espaçamento entre chips foi recalibrado.
- **Badge de classe sai do rosto.** A "tab" da classe funcional passa a
  ficar a ~60 % fora do retrato, deixando o rosto totalmente livre.
- **Silhueta em vez de iniciais.** Enquanto a foto não carrega (ou se
  o link estiver indisponível), o chip mostra um ícone de silhueta
  humana sobre o gradiente azul cobalto, no lugar das iniciais.
- **Fix: foto fantasma ao trocar atleta.** O retrato anterior já não
  aparece por um instante quando o slot recebe uma jogadora diferente;
  agora o `FutureBuilder` é recriado por URL.
- **Placar espelho na quadra.** Pequenos badges nos cantos (Equipe A em
  cima à esquerda, Equipe B embaixo à direita) repetem
  `total / limite` da partida — feedback visual da pontuação para o
  público durante a transmissão. Quando estoura o limite o badge fica
  vermelho com glow, sem texto extra de "Limite excedido" (sem espaço
  na quadra).

## 2.0.0 — 2026-05-28

- **Design moderno de transmissão (Broadcast Style).** Renovação visual
  dos chips dos atletas em quadra, pensados para transmissões de
  partidas no YouTube/streaming.
- **Adeus moldura grossa.** Remoção da borda branca espessa ao redor das
  fotos, substituída por contorno milimétrico em cinza-slate e sombra
  projetada com `MaskFilter.blur` que dá efeito de flutuação sobre a
  quadra.
- **Badges tridimensionais ampliados (~15%).** Aumento proporcional das
  fotos e badges. O indicador de classe funcional ganhou gradiente
  off-white, formato com cantos assimétricos e faixa lateral em azul
  cobalto (estilo placar esportivo); o número da camisa virou círculo
  perfeito de alto contraste.
- **Estrela de bonificação premium.** O indicador de bônus em quadra
  passou a usar gradiente laranja-basquete, estrela interna branca e
  glow suave ao redor.
- **Nova quadra amadeirada (clara) e Auto Broadcast Dim.** A quadra
  padrão passa a ser `assets/images/wbk-court2.png` (piso claro, garrafões
  em azul cobalto, círculo central azul); a antiga `court.png` segue no
  projeto reservada para um futuro seletor de tema claro/escuro em
  tempo real. Novo filtro inteligente: quando há atletas em quadra, o
  piso é levemente esmaecido (76 % de opacidade + overlay off-white)
  para priorizar a leitura de rostos, nomes e números na transmissão;
  quadra vazia continua em opacidade cheia.
- **Avatar de fallback CBBC.** Atletas sem foto importada agora aparecem
  em gradiente azul cobalto institucional com iniciais brancas em vez do
  fundo cinza neutro.

## 0.5.0 — 2026-05-28

- **Fotos dos atletas em quadra.** Chips da quadra passam a usar retrato
  em moldura moderna quando há link de foto importado.
- **Recorte automático do rosto.** O app baixa a imagem, detecta a área
  do atleta contra o fundo claro e enquadra rosto/pescoço/ombros no
  estilo 3x4; se a foto falhar, mostra iniciais na mesma moldura.
- **Badges sobre a foto.** Classe funcional aparece em badge branco,
  camisa usa a cor do uniforme escolhido com contraste automático, e
  atleta bonificado recebe estrela laranja.
- **Planilha com coluna de foto.** Parsers e modelos `.xlsx` aceitam
  links públicos em `foto`/`photo_url`/Google Drive; a tela de resumo
  permite adicionar, editar ou remover o link.
- **Internet opcional para fotos.** APK release passa a pedir permissão
  de internet, mantendo os dados da partida offline.

## 0.4.0 — 2026-05-27

- **Splash screen institucional.** Logo CBBC + texto
  "Confederação Brasileira de Basquetebol em Cadeira de Rodas"
  sobre fundo branco por ~2,5 s, com transição em fade para a tela
  inicial.
- **Fullscreen "modo vídeo".** App sobe em `SystemUiMode.immersiveSticky`:
  barras de status e navegação ficam ocultas (swipe da borda traz
  temporariamente) — mais área útil para a quadra.
- **Tela sempre acesa.** Wakelock global ativado no `main()` (antes só
  ficava ligado na tela de quadra). A tela não apaga em nenhuma etapa
  do uso do app. O wakelock libera sozinho quando o app vai pra
  background e re-ativa no resume.
- **APK com versão no nome.** Workflow do GitHub Actions agora gera
  `controle-classificacao-cbbc-v0.4.0.apk` (lê o número do
  `pubspec.yaml`). `versionCode`/`versionName` do `build.gradle` passam
  a vir de `pubspec.yaml` automaticamente.

## 0.3.0 — 2026-05-26

- **Refresh visual estilo SaaS premium.** Paleta institucional CBBC
  mantida (azul cobalto + laranja), mas com fundo Slate 50, cards
  brancos com sombra suave, inputs arredondados e borda discreta.
- Home: botão de carregar arquivo virou cartão tapável com ícone de
  nuvem em destaque; modelos de planilha agrupados em um único card
  "Modelos de referência" com botões lado a lado; ícone discreto na
  frase "App offline".
- Resumo da importação: cabeçalho com badges separados de Clubes e
  Atletas, status de sucesso/erro com fundo pastel próprio, blocos de
  avisos/erros com faixa lateral colorida (vermelho/laranja).
- Configuração da partida: cada equipe envolvida em card próprio com
  título e barra azul à esquerda; bonificações agora usam interruptores
  (`SwitchListTile`) em vez de checkboxes; campos de formulário herdam
  o novo estilo Slate dos inputs.
- Quadra: soma de pontos de classificação fica em destaque (fonte 26pt
  em negrito, números com largura tabular para não "saltar"); quando o
  limite é excedido a célula ganha um glow vermelho animado; quadra
  com moldura refinada e sombra suave; atleta selecionado tem barra
  lateral azul + fundo azul translúcido com transição animada; botões
  operacionais ganharam ícones padronizados e altura mínima maior em
  celulares (acessibilidade); dropdown de pontuação máxima saiu do
  cabeçalho e virou ícone de ajustes no `AppBar`, liberando espaço
  vertical para a quadra.
- Templates `.xlsx`: colunas agora abrem com largura suficiente para o
  conteúdo (sem precisar puxar manualmente coluna por coluna).

## 0.2.0 — 2026-05-26

- Templates `.xlsx` agora usam dados anônimos (`Equipe A/B/...`,
  `Atleta 1/2/...`) e incluem célula para data de término da competição.
- Regra de bonificação sub-16/sub-23 considera a data de término da
  competição: vale o limite até o atleta completar 17/24 anos.
- Indicador de bonificação (estrelinha laranja) ao lado do nome do
  atleta bonificado em quadra e na lista de atletas.
- Tela de resumo da importação: edição em linha única (camisa, nome,
  data de nascimento, gênero, classe), exclusão de atleta (com
  confirmação), edição do nome da equipe (ícone de lápis) e exclusão
  da equipe inteira (ícone de lixeira).
- Tela de configuração da partida: seletor de cor da camiseta para
  cada equipe (5 cores escuras), tooltips explicativos nas opções de
  bonificação, exibição/edição da data de hoje e da data de término da
  competição. Removido o texto "Hard cap = 15".
- Tela de jogo: removidos os rótulos duplicados "Equipe A/B" sobre o
  placar; dica dentro da quadra passa a usar o nome do clube
  selecionado; cor da camiseta vinda do setup é refletida nos chips e
  ícones.
- Botões operacionais (limpar Equipe A/B, trocar equipes, etc.)
  diminuem em telas estreitas (< 720 px) para não atrapalhar a lista
  de atletas.
- AppBar com logo CBBC à esquerda do título (em vez de empilhado),
  ligeiramente maior e mais legível.
- Suporte a rotação automática (retrato e paisagem).
- Ícone do app passa a usar a logotipo CBBC azul transparente em vez
  do ícone padrão do Flutter.
- Arquivo `CHANGELOG.md` + `lib/constants/app_version.dart` para
  rastrear versões a cada rodada de ajustes.

## 0.1.0 — primeira release CBBC

- Fork inicial do IWBF Team Points Control adaptado para CBBC
  (português, clube no lugar de país, mixed gender permitido).
- Parsers de planilha `.xlsx` e PDF.
- Tela de quadra ao vivo com controle de pontos e bonificação.
