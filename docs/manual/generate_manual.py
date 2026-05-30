"""
Monta o Manual de Uso (PDF) do app Controle de Classificação CBBC v2.3.4.

Usa as capturas renderizadas por app_screens.py (em build/) e o ReportLab
para diagramar um documento profissional em pt-BR — Manual de Uso para a CBBC.
"""
import os
from PIL import Image, ImageDraw
import screens as S
from screens import font, text_w, text_h, phone_frame, tablet_frame, load_logo

from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm, mm
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_JUSTIFY
from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer, Image as RLImage,
                                PageBreak, Table, TableStyle, KeepTogether, Flowable)
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

HERE = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(HERE, "build")
OUT = os.path.abspath(os.path.join(HERE, "..", "Manual-Uso-Controle-Classificacao-CBBC.pdf"))

FDIR = "/usr/share/fonts/truetype/dejavu"
pdfmetrics.registerFont(TTFont("Sans", os.path.join(FDIR, "DejaVuSans.ttf")))
pdfmetrics.registerFont(TTFont("Sans-Bold", os.path.join(FDIR, "DejaVuSans-Bold.ttf")))
pdfmetrics.registerFont(TTFont("Sans-Oblique", "/usr/share/fonts/truetype/freefont/FreeSansOblique.ttf"))
pdfmetrics.registerFontFamily("Sans", normal="Sans", bold="Sans-Bold", italic="Sans-Oblique")

BLUE = colors.Color(*[c / 255 for c in S.BLUE])
BLUE_DEEP = colors.Color(*[c / 255 for c in S.BLUE_DEEP])
ORANGE = colors.Color(*[c / 255 for c in S.ORANGE])
TEXT = colors.Color(*[c / 255 for c in S.TEXT])
TEXT2 = colors.Color(*[c / 255 for c in S.TEXT2])
SLATE50 = colors.Color(*[c / 255 for c in S.SLATE50])
SLATE100 = colors.Color(*[c / 255 for c in S.SLATE100])
SLATE200 = colors.Color(*[c / 255 for c in S.SLATE200])
BLUE_SOFT = colors.Color(*[c / 255 for c in S.BLUE_SOFT])
SUCCESS = colors.Color(*[c / 255 for c in S.SUCCESS])

# ---------------------------------------------------------------------------
# Anotações (marcadores numerados) sobre as capturas
# ---------------------------------------------------------------------------
def annotate(png_name, points, frame="phone"):
    """Carrega build/<png>, desenha marcadores numerados em points
    [(x,y),...] (coords da imagem base) e envolve na moldura do dispositivo.
    Devolve caminho do PNG temporário."""
    img = Image.open(os.path.join(BUILD, png_name)).convert("RGB")
    d = ImageDraw.Draw(img)
    r = 22
    for i, (x, y) in enumerate(points, 1):
        d.ellipse([x - r, y - r, x + r, y + r], fill=S.ORANGE, outline=(255, 255, 255), width=4)
        f = font(30, bold=True)
        w = text_w(d, str(i), f)
        d.text((x - w / 2, y - text_h(f) / 2 - 2), str(i), font=f, fill=(255, 255, 255))
    if frame == "phone":
        framed = phone_frame(img)
    elif frame == "tablet":
        framed = tablet_frame(img)
    else:
        framed = img.convert("RGBA")
    out = os.path.join(BUILD, "_a_" + png_name)
    framed.convert("RGB").save(out)
    return out


def framed_path(png_name, frame="phone"):
    return annotate(png_name, [], frame=frame)


def rl_image(path, width_cm):
    img = Image.open(path)
    w = width_cm * cm
    h = w * img.height / img.width
    return RLImage(path, width=w, height=h)


# ---------------------------------------------------------------------------
# Diagrama de fluxo
# ---------------------------------------------------------------------------
def flow_diagram():
    W, H = 2000, 360
    img = Image.new("RGB", (W, H), (255, 255, 255))
    d = ImageDraw.Draw(img)
    steps = ["Carregar\nplanilha / PDF", "Conferir\natletas", "Configurar\npartida",
             "Quadra\nao vivo", "Transmitir\n(QR / link)"]
    n = len(steps)
    bw, bh = 320, 150
    gap = (W - n * bw) / (n + 1)
    y = (H - bh) / 2
    for i, st in enumerate(steps):
        x = gap + i * (bw + gap)
        col = S.ORANGE if i == n - 1 else S.BLUE
        d.rounded_rectangle([x, y, x + bw, y + bh], radius=20, fill=col)
        for j, ln in enumerate(st.split("\n")):
            f = font(34, bold=True)
            w = text_w(d, ln, f)
            d.text((x + bw / 2 - w / 2, y + bh / 2 - 38 + j * 44), ln, font=f, fill=(255, 255, 255))
        if i < n - 1:
            ax = x + bw + gap / 2
            d.polygon([(ax - 18, y + bh / 2 - 18), (ax - 18, y + bh / 2 + 18),
                       (ax + 16, y + bh / 2)], fill=S.BLUE_DEEP)
    p = os.path.join(BUILD, "_flow.png")
    img.save(p)
    return p


# ---------------------------------------------------------------------------
# Estilos
# ---------------------------------------------------------------------------
styles = getSampleStyleSheet()
H1 = ParagraphStyle("H1", fontName="Sans-Bold", fontSize=19, textColor=BLUE_DEEP,
                    spaceBefore=6, spaceAfter=10, leading=23)
H2 = ParagraphStyle("H2", fontName="Sans-Bold", fontSize=13.5, textColor=BLUE,
                    spaceBefore=12, spaceAfter=5, leading=17)
BODY = ParagraphStyle("BODY", fontName="Sans", fontSize=10.3, textColor=TEXT,
                      leading=15.5, alignment=TA_JUSTIFY, spaceAfter=6)
BULLET = ParagraphStyle("BULLET", parent=BODY, leftIndent=16, bulletIndent=2,
                        spaceAfter=3, alignment=TA_LEFT)
CAP = ParagraphStyle("CAP", fontName="Sans-Oblique", fontSize=8.8, textColor=TEXT2,
                     alignment=TA_CENTER, spaceBefore=4, spaceAfter=12, leading=12)
NUMHEAD = ParagraphStyle("NUMHEAD", fontName="Sans-Bold", fontSize=10.3, textColor=BLUE_DEEP,
                         leading=15, spaceAfter=2)


def bullets(items, style=BULLET):
    return [Paragraph(f'<font color="#E87B2B">●</font>&nbsp;&nbsp;{t}', style) for t in items]


def numbered(items):
    out = []
    for i, t in enumerate(items, 1):
        out.append(Paragraph(
            f'<font name="Sans-Bold" color="#E87B2B">{i}.</font>&nbsp;&nbsp;{t}', BULLET))
    return out


def callout(title, items, bg=BLUE_SOFT, border=BLUE):
    rows = [[Paragraph(f'<b>{title}</b>', NUMHEAD)]]
    inner = []
    for i, t in enumerate(items, 1):
        inner.append(Paragraph(
            f'<font name="Sans-Bold" color="#1F66B6">{i}</font>&nbsp;&nbsp;{t}',
            ParagraphStyle("ci", parent=BODY, alignment=TA_LEFT, spaceAfter=3, fontSize=9.6, leading=13.5)))
    rows.append([inner])
    t = Table(rows, colWidths=[None])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), colors.Color(*[c / 255 for c in (0xEC, 0xF2, 0xF9)])),
        ("BOX", (0, 0), (-1, -1), 0.8, border),
        ("LINEBELOW", (0, 0), (0, 0), 0.6, SLATE200),
        ("LEFTPADDING", (0, 0), (-1, -1), 10),
        ("RIGHTPADDING", (0, 0), (-1, -1), 10),
        ("TOPPADDING", (0, 0), (-1, -1), 7),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
    ]))
    return KeepTogether([Spacer(1, 0.1 * cm), t])


class HRule(Flowable):
    def __init__(self, width, color=SLATE200, thickness=0.8):
        super().__init__()
        self.width = width
        self.color = color
        self.thickness = thickness

    def draw(self):
        self.canv.setStrokeColor(self.color)
        self.canv.setLineWidth(self.thickness)
        self.canv.line(0, 0, self.width, 0)


# ---------------------------------------------------------------------------
# Cabeçalho / rodapé das páginas internas
# ---------------------------------------------------------------------------
def header_footer(canvas, doc):
    canvas.saveState()
    w, h = A4
    # rodapé
    canvas.setStrokeColor(SLATE200)
    canvas.setLineWidth(0.6)
    canvas.line(2 * cm, 1.4 * cm, w - 2 * cm, 1.4 * cm)
    canvas.setFont("Sans", 8)
    canvas.setFillColor(TEXT2)
    canvas.drawString(2 * cm, 1.0 * cm, "Controle de Classificação CBBC — Manual de Uso (v2.3.4)")
    canvas.drawRightString(w - 2 * cm, 1.0 * cm, f"Página {doc.page}")
    # cabeçalho discreto
    canvas.setFillColor(BLUE_DEEP)
    canvas.setFont("Sans-Bold", 8)
    canvas.drawString(2 * cm, h - 1.15 * cm, "CONFEDERAÇÃO BRASILEIRA DE BASQUETEBOL EM CADEIRA DE RODAS")
    canvas.setStrokeColor(SLATE200)
    canvas.line(2 * cm, h - 1.35 * cm, w - 2 * cm, h - 1.35 * cm)
    canvas.restoreState()


def cover_page(canvas, doc):
    canvas.saveState()
    w, h = A4
    canvas.setFillColor(colors.white)
    canvas.rect(0, 0, w, h, fill=1, stroke=0)
    # faixa superior
    canvas.setFillColor(BLUE)
    canvas.rect(0, h - 0.9 * cm, w, 0.9 * cm, fill=1, stroke=0)
    canvas.setFillColor(ORANGE)
    canvas.rect(0, h - 1.1 * cm, w, 0.2 * cm, fill=1, stroke=0)
    # logo
    logo = os.path.join(BUILD, "_cover_logo.png")
    canvas.drawImage(logo, w / 2 - 3.4 * cm, h - 8.2 * cm, 6.8 * cm, 6.8 * cm,
                     mask="auto", preserveAspectRatio=True)
    canvas.setFillColor(BLUE_DEEP)
    canvas.setFont("Sans-Bold", 26)
    canvas.drawCentredString(w / 2, h - 10.0 * cm, "Manual de Uso do Aplicativo")
    canvas.setFont("Sans-Bold", 18)
    canvas.setFillColor(BLUE)
    canvas.drawCentredString(w / 2, h - 11.1 * cm, "Controle de Classificação CBBC")
    canvas.setFont("Sans", 12.5)
    canvas.setFillColor(TEXT2)
    canvas.drawCentredString(w / 2, h - 12.4 * cm, "Conferência da pontuação funcional por equipe")
    canvas.drawCentredString(w / 2, h - 13.0 * cm, "no basquetebol em cadeira de rodas")
    # caixa de destaque
    canvas.setFillColor(SLATE50)
    canvas.setStrokeColor(BLUE)
    canvas.roundRect(3 * cm, h - 19.2 * cm, w - 6 * cm, 4.4 * cm, 10, fill=1, stroke=1)
    canvas.setFillColor(BLUE_DEEP)
    canvas.setFont("Sans-Bold", 11)
    canvas.drawCentredString(w / 2, h - 15.7 * cm, "Manual de Uso para a CBBC")
    canvas.setFillColor(TEXT)
    canvas.setFont("Sans", 10)
    lines = [
        "Guia de operação do aplicativo para os classificadores da CBBC durante",
        "as partidas. Demonstra todas as funcionalidades por meio de uma",
        "simulação de uso real (Supercopa — IREFES × ADESUL).",
    ]
    for i, ln in enumerate(lines):
        canvas.drawCentredString(w / 2, h - (16.5 + i * 0.62) * cm, ln)
    # rodapé capa
    canvas.setFillColor(BLUE_DEEP)
    canvas.setFont("Sans-Bold", 11)
    canvas.drawCentredString(w / 2, 2.6 * cm, "Versão 2.3.4")
    canvas.setFont("Sans", 9.5)
    canvas.setFillColor(TEXT2)
    canvas.drawCentredString(w / 2, 2.0 * cm, "Confederação Brasileira de Basquetebol em Cadeira de Rodas")
    canvas.setFillColor(ORANGE)
    canvas.rect(0, 0, w, 0.35 * cm, fill=1, stroke=0)
    canvas.restoreState()


# ---------------------------------------------------------------------------
# Conteúdo
# ---------------------------------------------------------------------------
def build():
    # logo da capa (fundo transparente -> branco)
    logo = load_logo(h=600)
    bg = Image.new("RGBA", logo.size, (255, 255, 255, 255))
    bg.alpha_composite(logo)
    bg.convert("RGB").save(os.path.join(BUILD, "_cover_logo.png"))

    doc = SimpleDocTemplate(OUT, pagesize=A4,
                            leftMargin=2 * cm, rightMargin=2 * cm,
                            topMargin=1.7 * cm, bottomMargin=1.7 * cm,
                            title="Manual de Uso — Controle de Classificação CBBC v2.3.4",
                            author="CBBC")
    usable = A4[0] - 4 * cm
    story = []

    def P(t, s=BODY):
        story.append(Paragraph(t, s))

    def sp(x=0.3):
        story.append(Spacer(1, x * cm))

    def fig(path, width_cm, caption):
        story.append(Spacer(1, 0.2 * cm))
        story.append(KeepTogether([rl_image(path, width_cm), Paragraph(caption, CAP)]))

    # ---- Capa ----
    story.append(Spacer(1, 1))
    story.append(PageBreak())

    # ---- Sumário / Apresentação ----
    P("Apresentação", H1)
    P("O <b>Controle de Classificação CBBC</b> é um aplicativo desenvolvido para os "
      "<b>classificadores da CBBC</b> acompanharem, em tempo real, a soma dos "
      "<b>pontos funcionais</b> das equipes durante as partidas de basquetebol em "
      "cadeira de rodas. A cada atleta em quadra, o app soma automaticamente as classes "
      "funcionais e avisa imediatamente quando o limite permitido é ultrapassado — "
      "eliminando erros de conta manual e dando mais segurança e agilidade ao trabalho.")
    P("Além do controle, a versão 2.3.4 introduz a <b>transmissão ao vivo da quadra</b>: "
      "com um toque, o app gera um <b>QR Code e um link público</b> que qualquer pessoa "
      "abre no navegador para ver o posicionamento e o placar de pontos em tempo quase "
      "real — ideal para a mesa e o público.")
    sp(0.2)
    P("Conteúdo", H2)
    story.extend(bullets([
        "1. Visão geral e fluxo de uso",
        "2. Abertura e tela inicial",
        "3. Carregamento e conferência dos atletas (planilha .xlsx ou PDF)",
        "4. Configuração da partida (equipes, camisetas, pontuação, bonificações)",
        "5. Quadra ao vivo — operação durante o jogo",
        "6. Transmissão ao vivo com QR Code e página pública",
        "7. Regras de pontuação e bonificação",
        "8. Boas práticas, requisitos e privacidade",
    ]))
    sp(0.2)
    P("Os registros de tela deste manual reproduzem uma <b>simulação de uso real</b> da "
      "Supercopa, com as equipes <b>IREFES</b> e <b>ADESUL</b> a partir da planilha oficial "
      "de atletas.", ParagraphStyle("note", parent=BODY, fontSize=9.4, textColor=TEXT2))
    story.append(PageBreak())

    # ---- 1. Visão geral ----
    P("1. Visão geral e fluxo de uso", H1)
    P("O uso do aplicativo segue cinco etapas simples, sempre na mesma ordem. Os dados da "
      "partida funcionam <b>100% offline</b>; a internet só é necessária para carregar as "
      "<b>fotos</b> das atletas e para a <b>transmissão ao vivo</b> — recursos opcionais.")
    story.append(rl_image(flow_diagram(), usable / cm))
    story.append(Paragraph("Fluxo completo: da planilha à transmissão pública da quadra.", CAP))
    P("Principais benefícios", H2)
    story.extend(bullets([
        "<b>Soma automática</b> dos pontos funcionais das cinco atletas em quadra, por equipe.",
        "<b>Alerta visual e por vibração</b> assim que o limite de pontos é excedido.",
        "<b>Bonificações</b> (Sub-16, Sub-23 e atleta feminina) aplicadas automaticamente, "
        "elevando o teto para 15,0 pontos quando há atleta da categoria em quadra.",
        "<b>Identificação por foto</b>, número de camisa e classe de cada atleta na quadra.",
        "<b>Funciona offline</b> — não depende de internet para conferir a partida.",
        "<b>Transmissão pública</b> da quadra por QR Code / link, sem instalar nada no "
        "dispositivo do espectador.",
        "Aceita <b>planilha .xlsx ou PDF</b> e mantém a sessão salva caso o app seja fechado.",
    ]))
    story.append(PageBreak())

    # ---- 2. Abertura e tela inicial ----
    P("2. Abertura e tela inicial", H1)
    P("Ao abrir, o app exibe a identidade visual da CBBC e segue para a tela inicial, onde "
      "a partida é iniciada e os modelos de planilha podem ser baixados.")
    t = Table([[rl_image(framed_path("splash.png"), 6.2),
                rl_image(annotate("home.png", [(95, 595), (330, 978), (650, 978), (240, 1414)]), 6.2)]],
              colWidths=[usable / 2, usable / 2])
    t.setStyle(TableStyle([("ALIGN", (0, 0), (-1, -1), "CENTER"), ("VALIGN", (0, 0), (-1, -1), "TOP")]))
    story.append(t)
    story.append(Paragraph("À esquerda, a tela de abertura. À direita, a tela inicial.", CAP))
    story.append(callout("Tela inicial — passo a passo", [
        "<b>Carregar planilha (.xlsx) ou PDF</b> — abre o seletor de arquivos para importar a "
        "lista de atletas e iniciar a conferência.",
        "<b>Baixar modelo “Aba única”</b> — planilha-modelo com todos os clubes em uma só aba.",
        "<b>Baixar modelo “Por clube”</b> — planilha-modelo com uma aba para cada clube.",
        "<b>Versão do app e aviso “Dados offline”</b> — confirmam que a partida funciona sem internet.",
    ]))
    story.append(PageBreak())

    # ---- 3. Carregamento e conferência ----
    P("3. Carregamento e conferência dos atletas", H1)
    P("A planilha (ou PDF) deve conter as colunas <b>clube, classe, atleta, camisa, data de "
      "nascimento, gênero</b> e, opcionalmente, <b>foto</b> (link público). O app reconhece "
      "cabeçalhos em português e inglês. Após o carregamento, a tela de <b>Resumo da importação</b> "
      "mostra tudo o que foi lido e permite ajustar qualquer dado antes do jogo.")
    fig(annotate("validation.png", [(75, 250), (688, 250), (560, 558), (390, 688), (415, 1561)]),
        7.2, "Resumo da importação — Supercopa: 4 clubes e 42 atletas reconhecidos.")
    story.append(callout("Resumo da importação", [
        "<b>Contadores</b> de clubes e atletas encontrados no arquivo.",
        "<b>Selo de status</b> — verde quando o arquivo está pronto; vermelho quando há erros.",
        "<b>Renomear / excluir</b> equipe diretamente na lista.",
        "<b>Edição rápida</b> de cada atleta: camisa, nome, foto, nascimento, gênero e classe.",
        "<b>Continuar</b> — avança para a configuração da partida (habilita só sem erros).",
    ]))
    P("Quando há informações faltando", H2)
    P("Se algum dado obrigatório estiver ausente (por exemplo, classe funcional ou data de "
      "nascimento), o app destaca o problema e indica exatamente qual atleta e linha corrigir, "
      "evitando que a partida comece com dados incompletos.")
    fig(framed_path("missing.png"), 8.2,
        "Tela “Dados pendentes”: erros agrupados por tipo, com clube, atleta e linha.")
    story.append(PageBreak())

    # ---- 4. Configuração ----
    P("4. Configuração da partida", H1)
    P("Nesta tela definem-se as duas equipes do confronto, as cores das camisetas, a pontuação "
      "máxima e as bonificações válidas para a competição. Na simulação, configuramos "
      "<b>IREFES (Equipe A)</b> contra <b>ADESUL (Equipe B)</b>.")
    fig(annotate("setup.png", [(560, 216), (640, 331), (600, 704), (620, 792), (560, 1000), (600, 1252)]),
        7.0, "Configuração da partida IREFES × ADESUL, com bonificação Sub-23 ativada.")
    story.append(callout("Configuração da partida", [
        "<b>Equipe A e Equipe B</b> — selecionadas entre os clubes importados.",
        "<b>Cor da camiseta</b> de cada equipe — usada nos ícones e chips em quadra.",
        "<b>Pontuação máxima por equipe</b> — limite padrão de 14,0 (ajustável de 7,0 a 16,0).",
        "<b>Bonificações da competição</b> — Sub-16, Sub-23 e atleta feminina.",
        "<b>Sub-23 ativada</b> — atletas da categoria recebem destaque e elevam o teto para 15,0.",
        "<b>Datas de referência</b> — conferidas com o tablet; usadas no cálculo das idades.",
    ]))
    story.append(PageBreak())

    # ---- 5. Quadra ao vivo ----
    P("5. Quadra ao vivo — operação durante o jogo", H1)
    P("É a tela principal, usada durante a partida. Em tablet, mostra as duas listas de atletas "
      "nas laterais e a <b>quadra</b> ao centro. Toca-se no nome (ou na foto em quadra) para "
      "colocar ou retirar uma atleta; o app soma os pontos e atualiza o placar instantaneamente.")
    fig(annotate("live_normal.png",
                 [(2150, 70), (2230, 70), (690, 168), (180, 270), (770, 800)], frame="tablet"),
        usable / cm, "Quadra ao vivo (tablet) — IREFES 13,5 e ADESUL 13,5, ambas dentro do limite de 14,0.")
    story.append(callout("Quadra ao vivo", [
        "<b>Botão de transmissão</b> — inicia/abre a transmissão pública (seção 6).",
        "<b>Ajuste de pontuação máxima</b> — altera o limite sem sair da partida.",
        "<b>Placar por equipe</b> — soma atual / limite; fica vermelho ao exceder.",
        "<b>Listas das equipes</b> — toque para colocar/retirar atletas (máx. 5 por equipe).",
        "<b>Quadra</b> — mostra as atletas posicionadas, com foto, número e classe; "
        "abaixo, o seletor de estilo de quadra (clara/escura).",
    ]))
    P("Alerta de limite excedido", H2)
    P("Quando a soma das cinco atletas ultrapassa o limite, o placar daquela equipe fica "
      "<b>vermelho</b> com a mensagem <b>“Limite excedido.”</b> e o tablet <b>vibra</b> — "
      "o erro é percebido na hora, mesmo sem olhar a tela.")
    fig(framed_path("live_exceeded.png", frame="tablet"), usable / cm,
        "IREFES com 15,0 pontos para um limite de 14,0: placar vermelho e aviso de limite excedido.")
    story.append(PageBreak())

    P("Bonificação em quadra", H2)
    P("Com uma bonificação ativa (aqui, Sub-23), as atletas da categoria aparecem com uma "
      "<b>estrela laranja</b> na lista e na quadra. Enquanto houver ao menos uma delas em "
      "quadra, o <b>teto da equipe sobe para 15,0</b> pontos sem gerar alerta — o placar mostra "
      "“/ 15.0” com a estrela.")
    fig(framed_path("live_bonus.png", frame="tablet"), usable / cm,
        "Bonificação Sub-23 em quadra: teto elevado para 15,0 e estrela ao lado das atletas da categoria.")
    P("Operação no celular", H2)
    P("Em telas menores, a quadra é organizada em três abas — <b>Equipe A</b>, <b>Quadra</b> e "
      "<b>Equipe B</b> — preservando todas as funções.")
    fig(framed_path("live_phone.png"), 7.4,
        "Mesma partida em um celular: navegação por abas, com o placar sempre visível no topo.")
    story.append(PageBreak())

    # ---- 6. Transmissão ----
    P("6. Transmissão ao vivo com QR Code", H1)
    P("Novidade da versão 2.3, a transmissão pública permite <b>espelhar a quadra</b> para "
      "qualquer pessoa, sem instalar nada. Ao tocar no <b>ícone de transmissão</b> na barra "
      "superior, o app cria a sessão e exibe uma janela com <b>QR Code</b> e <b>link</b> "
      "(no formato <font name=\"Sans-Bold\">…/v/&lt;código&gt;</font>). Basta apontar a câmera "
      "ou copiar o link.")
    fig(framed_path("broadcast.png", frame="tablet"), usable / cm,
        "Janela de transmissão: QR Code e link público copiável, sobre a partida em andamento.")
    story.append(callout("Como transmitir", [
        "Toque no <b>ícone de transmissão</b> (canto superior direito). Ele fica <b>laranja</b> "
        "enquanto a transmissão está no ar.",
        "Mostre o <b>QR Code</b> para o público ou <b>copie o link</b> para enviar/colar no OBS.",
        "A página pública atualiza em <b>~1 segundo</b> e aceita <b>vários espectadores</b> ao mesmo tempo.",
        "Toque em <b>Encerrar</b> para finalizar; a sessão também expira sozinha após 1 hora de inatividade.",
    ]))
    P("A transmissão funciona <b>apenas com internet</b> — exatamente como as fotos das atletas. "
      "Sem conexão, a partida segue 100% normal e o botão apenas avisa que é preciso estar online.",
      ParagraphStyle("n2", parent=BODY, fontSize=9.4, textColor=TEXT2))
    story.append(PageBreak())

    P("A página pública (no navegador)", H2)
    P("Quem abre o link vê <b>somente a quadra</b> — chips das atletas e o placar nos cantos — "
      "sobre fundo preto, sem botões nem menus. É a página ideal para projetar, capturar no OBS "
      "ou compartilhar com o público.")
    fig(framed_path("viewer.png", frame="browser"), 9.5,
        "Página pública /v/<código> aberta no navegador: a mesma quadra ao vivo, pronta para transmissão.")
    story.append(callout("Página pública", [
        "Abre em <b>qualquer navegador</b> (celular, computador ou TV) — não precisa do app.",
        "Mostra <b>posicionamento, fotos, números, classes</b> e o <b>placar de pontos</b> de cada equipe.",
        "Reflete <b>em tempo quase real</b> cada toque feito pelo classificador no tablet.",
        "Não expõe dados sensíveis nem controles — é somente visualização.",
    ]))
    story.append(PageBreak())

    # ---- 7. Regras ----
    P("7. Regras de pontuação e bonificação", H1)
    P("O app segue o padrão de classes funcionais adotado pela CBBC. Cada atleta possui uma "
      "classe de <b>1,0 a 4,5</b> (em incrementos de 0,5). A pontuação da equipe é a soma das "
      "classes das <b>cinco atletas em quadra</b>.")
    data = [["Conceito", "Como funciona no app"],
            ["Classes funcionais", "1,0 · 1,5 · 2,0 · 2,5 · 3,0 · 3,5 · 4,0 · 4,5"],
            ["Atletas em quadra", "Até 5 por equipe; a soma das classes é o total da equipe."],
            ["Limite padrão", "14,0 pontos (configurável de 7,0 a 16,0)."],
            ["Limite excedido", "Placar vermelho, mensagem de alerta e vibração do tablet."],
            ["Bonificação", "Sub-16, Sub-23 e/ou atleta feminina, definidas na configuração."],
            ["Teto com bonificação", "15,0 pontos enquanto houver atleta bonificada em quadra."],
            ["Cálculo da idade", "Pela data de término da competição (datas de referência)."]]
    tb = Table(data, colWidths=[usable * 0.32, usable * 0.68])
    tb.setStyle(TableStyle([
        ("FONT", (0, 0), (-1, 0), "Sans-Bold", 10),
        ("FONT", (0, 1), (-1, -1), "Sans", 9.6),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("BACKGROUND", (0, 0), (-1, 0), BLUE),
        ("TEXTCOLOR", (0, 1), (0, -1), BLUE_DEEP),
        ("FONT", (0, 1), (0, -1), "Sans-Bold", 9.6),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, SLATE50]),
        ("GRID", (0, 0), (-1, -1), 0.5, SLATE200),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("TOPPADDING", (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
    ]))
    story.append(tb)
    sp(0.3)
    P("Sobre as bonificações", H2)
    story.extend(bullets([
        "<b>Sub-16</b>: vale enquanto a atleta não completa 17 anos até o término da competição.",
        "<b>Sub-23</b>: vale enquanto a atleta não completa 24 anos até o término da competição.",
        "<b>Atleta feminina</b>: para competições masculinas que concedem bonificação a atletas femininas.",
        "A estrela laranja (na lista e na quadra) indica, durante o jogo, quais atletas se enquadram "
        "na bonificação ativa.",
    ]))
    story.append(PageBreak())

    # ---- 8. Boas práticas ----
    P("8. Boas práticas, requisitos e privacidade", H1)
    P("Recomendações para o uso em quadra", H2)
    story.extend(bullets([
        "Prepare a planilha com antecedência e confira o <b>Resumo da importação</b> antes do jogo.",
        "Garanta que todas as atletas tenham <b>classe funcional</b> preenchida — é o dado que soma os pontos.",
        "Para usar fotos e transmissão, conecte o tablet à <b>internet</b> antes da partida.",
        "Confirme as <b>datas de referência</b> para que as bonificações por idade sejam calculadas corretamente.",
        "Mantenha o tablet carregado: a tela permanece ligada durante a partida.",
    ]))
    P("Requisitos", H2)
    story.extend(bullets([
        "<b>Tablet ou celular Android</b> (recomendado tablet para a visão completa da quadra).",
        "<b>Conferência da partida</b>: funciona totalmente offline.",
        "<b>Fotos e transmissão ao vivo</b>: exigem conexão com a internet.",
        "Arquivo de atletas em <b>.xlsx</b> ou <b>PDF</b> com texto selecionável.",
    ]))
    P("Privacidade e segurança", H2)
    story.extend(bullets([
        "Os dados da partida ficam <b>no próprio dispositivo</b> (sessão salva localmente).",
        "A transmissão publica <b>apenas a quadra</b> (posições, números, classes e placar) — "
        "sem expor a planilha ou dados pessoais sensíveis.",
        "Cada transmissão usa um <b>código aleatório</b> e <b>expira sozinha</b> após 1 hora de inatividade; "
        "pode ser encerrada a qualquer momento.",
    ]))
    sp(0.4)
    story.append(HRule(usable))
    sp(0.3)
    P("Este manual acompanha a versão <b>2.3.4</b> do aplicativo Controle de Classificação CBBC. "
      "As telas reproduzem fielmente a interface do app em uma simulação real da Supercopa "
      "(IREFES × ADESUL). Em dispositivos conectados à internet, os retratos azuis das atletas "
      "são substituídos pelas <b>fotos reais</b> carregadas dos links da planilha.",
      ParagraphStyle("fin", parent=BODY, fontSize=9.6, textColor=TEXT2))
    sp(0.2)
    P("Confederação Brasileira de Basquetebol em Cadeira de Rodas (CBBC)",
      ParagraphStyle("fin2", parent=BODY, fontName="Sans-Bold", fontSize=10, textColor=BLUE_DEEP,
                     alignment=TA_CENTER))

    doc.build(story, onFirstPage=cover_page, onLaterPages=header_footer)
    print("PDF gerado:", OUT, os.path.getsize(OUT), "bytes")


if __name__ == "__main__":
    build()
