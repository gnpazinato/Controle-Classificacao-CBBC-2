"""Construtores das telas do app para o manual (usam screens.py)."""
import os
from PIL import Image, ImageDraw
import screens as S
from screens import (font, text_w, text_h, center_text, draw_wrapped, rrect,
                     icon_cloud_upload, icon_download, icon_star, icon_check_circle,
                     icon_error, icon_groups, icon_ball, icon_play, icon_tune,
                     icon_swap, icon_copy, icon_qr_small, icon_cast, icon_edit,
                     jersey_icon, court_board, appbar, status_bar, load_logo,
                     phone_frame, tablet_frame, browser_frame)

PHONE_W = 760
BUILD = os.path.join(os.path.dirname(os.path.abspath(__file__)), "build")
os.makedirs(BUILD, exist_ok=True)

# --------------------------------------------------------------------------
# Rosters (planilha Supercopa) — IREFES x ADESUL
# --------------------------------------------------------------------------
IREFES = [
    {"n": 4, "name": "Ivanilde Candida da Silva", "c": "3.5", "cv": 3.5},
    {"n": 5, "name": "Paula Leticia Ricardo Silva", "c": "2.0", "cv": 2.0, "u23": True},
    {"n": 9, "name": "Bruna Rodrigues Rosa", "c": "2.0", "cv": 2.0},
    {"n": 13, "name": "Evilania de Morais Sousa", "c": "4.0", "cv": 4.0},
    {"n": 14, "name": "Jessica Silva Santana", "c": "2.5", "cv": 2.5},
    {"n": 21, "name": "Valdirene Nascimento Santos", "c": "3.0", "cv": 3.0},
    {"n": 25, "name": "Gabriela dos Santos Oliveira", "c": "2.5", "cv": 2.5},
    {"n": 41, "name": "Paola Klokler", "c": "3.5", "cv": 3.5},
    {"n": 89, "name": "Maria do Carmo Q. de Almeida", "c": "4.0", "cv": 4.0},
    {"n": 93, "name": "Lais Aguiar de Lima", "c": "4.5", "cv": 4.5},
    {"n": 99, "name": "Maria de Fatima da Silva", "c": "4.0", "cv": 4.0},
]
ADESUL = [
    {"n": 1, "name": "Adrielly de Jesus Ragel", "c": "3.5", "cv": 3.5},
    {"n": 2, "name": "Samilli S. Gonçalves Teixeira", "c": "1.0", "cv": 1.0},
    {"n": 3, "name": "Renata Alves Frutuoso", "c": "4.0", "cv": 4.0},
    {"n": 4, "name": "Ana Kelvia Silva de Lima", "c": "1.0", "cv": 1.0},
    {"n": 5, "name": "Maria Anastácia N. de Oliveira", "c": "1.0", "cv": 1.0},
    {"n": 6, "name": "Laura Vitória de S. Nauderer", "c": "1.5", "cv": 1.5, "u23": True},
    {"n": 7, "name": "Rebeca Soares Freires", "c": "2.0", "cv": 2.0, "u23": True},
    {"n": 8, "name": "Maria Angelina C. de Souza", "c": "4.0", "cv": 4.0},
    {"n": 9, "name": "Fabiane Ferreira da Silva", "c": "4.5", "cv": 4.5},
    {"n": 10, "name": "Oara Uchoa Assuncao", "c": "4.0", "cv": 4.0},
    {"n": 12, "name": "Lia Maria Soares Martins", "c": "4.5", "cv": 4.5},
]


def _new(w, h, bg=S.SLATE50):
    img = Image.new("RGB", (w, h), bg)
    return img, ImageDraw.Draw(img)


# --------------------------------------------------------------------------
def splash():
    img, d = _new(PHONE_W, 1500, S.WHITE)
    status_bar(img)
    logo = load_logo(h=320)
    img.paste(logo, (int(PHONE_W / 2 - logo.width / 2), 430), logo)
    f = font(30, bold=True)
    for i, ln in enumerate(["CONFEDERAÇÃO BRASILEIRA DE",
                            "BASQUETEBOL EM CADEIRA DE RODAS"]):
        center_text(d, PHONE_W / 2, 820 + i * 46, ln, f, S.BLUE_DEEP)
    return img


def home():
    img, d = _new(PHONE_W, 1500)
    status_bar(img)
    y = 90
    logo = load_logo(h=190)
    img.paste(logo, (int(PHONE_W / 2 - logo.width / 2), y), logo)
    y += 205
    center_text(d, PHONE_W / 2, y, "Controle de Classificação CBBC", font(34, bold=True), S.BLUE_DEEP)
    y += 50
    for ln in S.wrap(d, "Basquetebol em cadeira de rodas — controle de pontos por equipe", font(24), PHONE_W - 120):
        center_text(d, PHONE_W / 2, y, ln, font(24), S.TEXT2); y += 34
    y += 16
    for ln in S.wrap(d, "Carregue a planilha ou PDF de referência dos atletas para iniciar uma partida.", font(25), PHONE_W - 90):
        center_text(d, PHONE_W / 2, y, ln, font(25), S.TEXT); y += 36
    y += 24
    # upload card
    card = [40, y, PHONE_W - 40, y + 300]
    rrect(d, card, 18, fill=(0xEC, 0xF2, 0xF9))
    rrect(d, card, 18, outline=S.BLUE, width=2)
    cyc = y + 70
    d.ellipse([PHONE_W / 2 - 46, cyc - 46, PHONE_W / 2 + 46, cyc + 46], fill=S.WHITE)
    icon_cloud_upload(d, PHONE_W / 2, cyc, 56, S.BLUE)
    center_text(d, PHONE_W / 2, y + 150, "Carregar planilha (.xlsx) ou PDF", font(27, bold=True), S.BLUE_DEEP)
    for i, ln in enumerate(S.wrap(d, "Toque para escolher o arquivo de referência dos atletas.", font(23), PHONE_W - 160)):
        center_text(d, PHONE_W / 2, y + 200 + i * 32, ln, font(23), S.TEXT2)
    y = card[3] + 28
    # templates card
    tcard = [40, y, PHONE_W - 40, y + 200]
    rrect(d, tcard, 16, fill=S.WHITE, outline=S.SLATE200, width=2)
    d.text((70, y + 26), "Modelos de referência", font=font(25, bold=True), fill=S.BLUE_DEEP)
    for i, lab in enumerate(["Aba única", "Por clube"]):
        bx = [70 + i * 320, y + 90, 70 + i * 320 + 280, y + 160]
        rrect(d, bx, 12, outline=S.BLUE_DEEP, width=2)
        icon_download(d, bx[0] + 60, (bx[1] + bx[3]) / 2, 28, S.BLUE_DEEP)
        d.text((bx[0] + 95, (bx[1] + bx[3]) / 2 - 16), lab, font=font(24, bold=True), fill=S.BLUE_DEEP)
    # footer
    fy = 1380
    center_text(d, PHONE_W / 2, fy, "Dados offline. Fotos usam internet quando houver link.", font(21), S.TEXT2)
    center_text(d, PHONE_W / 2, fy + 34, "Versão 2.3.4", font(21), S.TEXT2)
    return img


def stat_badge(d, box, icon_fn, value, label):
    rrect(d, box, 12, fill=(0xEA, 0xF1, 0xF8), outline=S.BLUE, width=2)
    cy = (box[1] + box[3]) / 2
    d.ellipse([box[0] + 16, cy - 26, box[0] + 68, cy + 26], fill=S.WHITE)
    icon_fn(d, box[0] + 42, cy, 30, S.BLUE)
    d.text((box[0] + 86, cy - 30), value, font=font(36, bold=True), fill=S.BLUE_DEEP)
    d.text((box[0] + 86, cy + 12), label, font=font(20, bold=True), fill=S.TEXT2)


def validation_summary():
    img, d = _new(PHONE_W, 1640)
    status_bar(img)
    h = appbar(img, "Resumo da importação")
    y = h + 26
    # header card
    card = [30, y, PHONE_W - 30, y + 320]
    rrect(d, card, 14, fill=S.WHITE, outline=S.SLATE200, width=2)
    d.text((58, y + 22), "Supercopa CBBC", font=font(28, bold=True), fill=S.BLUE_DEEP)
    d.text((58, y + 64), "Término: 31/05/2026", font=font(22), fill=S.TEXT2)
    stat_badge(d, [58, y + 110, 350, y + 196], icon_groups, "4", "Clubes")
    stat_badge(d, [370, y + 110, PHONE_W - 58, y + 196], icon_ball, "42", "Atletas")
    sb = [58, y + 214, PHONE_W - 58, y + 290]
    rrect(d, sb, 10, fill=(0xE7, 0xF3, 0xEB), outline=S.SUCCESS, width=2)
    icon_check_circle(d, sb[0] + 34, (sb[1] + sb[3]) / 2, 20, S.SUCCESS)
    d.text((sb[0] + 66, (sb[1] + sb[3]) / 2 - 16), "Arquivo carregado com sucesso.", font=font(23, bold=True), fill=S.SUCCESS)
    y = card[3] + 28
    d.text((40, y), "Clubes encontrados", font=font(27, bold=True), fill=S.TEXT)
    y += 50
    # team tiles
    for name, count, expand in [("ADESUL", 11, True), ("ALL STAR RODAS PARÁ", 12, False),
                                ("APP", 8, False), ("IREFES", 11, False)]:
        tile = [30, y, PHONE_W - 30, y + 96]
        rrect(d, tile, 14, fill=S.WHITE, outline=S.SLATE200, width=2)
        d.text((58, y + 22), name, font=font(26, bold=True), fill=S.TEXT)
        d.text((58, y + 56), f"{count} atleta(s)", font=font(20), fill=S.TEXT2)
        icon_edit(d, PHONE_W - 150, y + 48, 26, S.BLUE_DEEP)
        # delete (X em vermelho)
        d.line([PHONE_W - 108, y + 36, PHONE_W - 88, y + 60], fill=S.ALERT, width=4)
        d.line([PHONE_W - 88, y + 36, PHONE_W - 108, y + 60], fill=S.ALERT, width=4)
        d.polygon([(PHONE_W - 66, y + 40), (PHONE_W - 46, y + 40), (PHONE_W - 56, y + 58)], fill=S.BLUE_DEEP)
        y += 110
        if expand:
            # cabeçalho + 3 linhas editáveis
            hdr = ["CAMISA", "NOME", "NASC.", "GÊN", "CLASSE"]
            cols = [50, 150, 470, 590, 660]
            for c, lab in zip(cols, hdr):
                d.text((c, y), lab, font=font(16, bold=True), fill=S.TEXT2)
            y += 30
            sample = [(1, "Adrielly de Jesus Ragel", "16/01/1998", "Fem", "3.5"),
                      (2, "Samilli S. G. Teixeira", "19/10/1992", "Fem", "1.0"),
                      (6, "Laura Vitória Nauderer", "13/01/2004", "Fem", "1.5")]
            for n, nm, dob, g, cl in sample:
                rrect(d, [46, y, 96, y + 56], 6, outline=S.SLATE200, width=2)
                center_text(d, 71, y + 14, str(n), font(22, bold=True), S.TEXT)
                rrect(d, [110, y, 450, y + 56], 6, outline=S.SLATE200, width=2)
                d.text((124, y + 16), nm, font=font(20), fill=S.TEXT)
                icon_ball(d, 424, y + 28, 14, S.TEXT2)  # ícone foto (placeholder)
                rrect(d, [460, y, 575, y + 56], 6, outline=S.SLATE200, width=2)
                d.text((468, y + 16), dob, font=font(17), fill=S.TEXT)
                rrect(d, [585, y, 648, y + 56], 6, outline=S.SLATE200, width=2)
                d.text((592, y + 16), g, font=font(17), fill=S.TEXT)
                rrect(d, [658, y, 715, y + 56], 6, outline=S.SLATE200, width=2)
                d.text((668, y + 16), cl, font=font(18, bold=True), fill=S.TEXT)
                y += 66
            y += 8
    # bottom bar
    by = 1520
    d.rectangle([0, by - 16, PHONE_W, 1640], fill=S.WHITE)
    d.line([0, by - 16, PHONE_W, by - 16], fill=S.SLATE200, width=2)
    rrect(d, [40, by + 6, 370, by + 76], 12, outline=S.BLUE_DEEP, width=2)
    center_text(d, 205, by + 22, "Carregar outro arquivo", font(20, bold=True), S.BLUE_DEEP)
    rrect(d, [390, by + 6, PHONE_W - 40, by + 76], 12, fill=S.BLUE)
    center_text(d, (390 + PHONE_W - 40) / 2, by + 24, "Continuar", font(24, bold=True), S.WHITE)
    return img


def match_setup():
    img, d = _new(PHONE_W, 1700)
    status_bar(img)
    h = appbar(img, "Configurar partida")
    y = h + 24

    def team_card(title, team, jersey_sel):
        nonlocal y
        card = [30, y, PHONE_W - 30, y + 250]
        rrect(d, card, 14, fill=S.WHITE, outline=S.SLATE200, width=2)
        rrect(d, [58, y + 22, 64, y + 44], 2, fill=S.BLUE)
        d.text((78, y + 20), title, font=font(24, bold=True), fill=S.BLUE_DEEP)
        # dropdown
        dd = [58, y + 64, PHONE_W - 58, y + 128]
        rrect(d, dd, 12, fill=S.SLATE100, outline=S.SLATE200, width=2)
        d.text((76, y + 84), team, font=font(25, bold=True), fill=S.TEXT)
        d.polygon([(PHONE_W - 100, y + 90), (PHONE_W - 76, y + 90), (PHONE_W - 88, y + 108)], fill=S.TEXT2)
        d.text((58, y + 150), "Cor da camiseta", font=font(22, bold=True), fill=S.TEXT)
        for i, jid in enumerate(["black", "white", "darkBlue", "darkRed", "darkGray"]):
            bx = 58 + i * 110
            sel = jid == jersey_sel
            rrect(d, [bx, y + 182, bx + 84, y + 240], 8,
                  outline=S.ORANGE if sel else (0, 0, 0, 30), width=3 if sel else 2)
            jersey_icon(img, bx + 42, y + 211, 50, jid, 10)
        y = card[3] + 22

    team_card("Equipe A", "IREFES", "white")
    team_card("Equipe B", "ADESUL", "darkBlue")
    # point limit
    dd = [30, y, PHONE_W - 30, y + 80]
    rrect(d, dd, 12, fill=S.SLATE100, outline=S.SLATE200, width=2)
    d.text((50, y + 14), "Pontuação máxima por equipe", font=font(18), fill=S.TEXT2)
    d.text((50, y + 40), "14.0", font=font(26, bold=True), fill=S.TEXT)
    d.polygon([(PHONE_W - 72, y + 34), (PHONE_W - 48, y + 34), (PHONE_W - 60, y + 52)], fill=S.TEXT2)
    y += 104
    # bonus
    bcard = [30, y, PHONE_W - 30, y + 360]
    rrect(d, bcard, 14, fill=(0xE9, 0xF1, 0xF9), outline=S.BLUE, width=2)
    icon_star(d, 64, y + 34, 16, S.ORANGE)
    d.text((86, y + 20), "Bonificações da competição", font=font(24, bold=True), fill=S.BLUE_DEEP)
    for i, ln in enumerate(S.wrap(d, "Quando houver atleta da categoria marcada em quadra, a equipe pode chegar até 15.0 pontos sem alerta.", font(19), PHONE_W - 110)):
        d.text((58, y + 56 + i * 28), ln, font=font(19), fill=S.TEXT2)
    items = [("Sub-16", "Atleta não completa 17 anos durante a competição.", False),
             ("Sub-23", "Atleta não completa 24 anos durante a competição.", True),
             ("Atleta feminina", "Para competição masculina com bonificação feminina.", False)]
    iy = y + 130
    for title, hint, on in items:
        d.text((58, iy), title, font=font(23, bold=True), fill=S.BLUE_DEEP)
        for j, ln in enumerate(S.wrap(d, hint, font(17), PHONE_W - 240)):
            d.text((58, iy + 32 + j * 24), ln, font=font(17), fill=S.TEXT2)
        # switch
        sw = [PHONE_W - 150, iy + 4, PHONE_W - 70, iy + 44]
        rrect(d, sw, 20, fill=S.BLUE if on else S.SLATE200)
        knob = (sw[2] - 18) if on else (sw[0] + 4)
        d.ellipse([knob, sw[1] + 3, knob + 34, sw[3] - 3], fill=S.WHITE if on else S.SLATE100, outline=S.BLUE_DEEP if on else S.SLATE200, width=2)
        iy += 78
    y = bcard[3] + 22
    # dates
    dcard = [30, y, PHONE_W - 30, y + 180]
    rrect(d, dcard, 10, fill=S.SLATE100, outline=(0, 0, 0, 34), width=2)
    d.text((54, y + 16), "Datas de referência", font=font(23, bold=True), fill=S.BLUE_DEEP)
    d.text((54, y + 52), "Conferida com o tablet — toque para corrigir.", font=font(18), fill=S.TEXT2)
    for i, (lab, val) in enumerate([("Data de hoje", "30/05/2026"),
                                    ("Data de término da competição", "31/05/2026")]):
        d.text((54, y + 90 + i * 40), f"{lab}: {val}", font=font(21, bold=True), fill=S.TEXT)
        icon_edit(d, PHONE_W - 70, y + 100 + i * 40, 22, S.BLUE_DEEP)
    # bottom
    by = 1600
    d.rectangle([0, by - 10, PHONE_W, 1700], fill=S.WHITE)
    d.line([0, by - 10, PHONE_W, by - 10], fill=S.SLATE200, width=2)
    rrect(d, [40, by + 8, PHONE_W - 40, by + 80], 14, fill=S.BLUE)
    icon_play(d, 280, by + 44, 30, S.WHITE)
    d.text((310, by + 26), "Iniciar partida", font=font(26, bold=True), fill=S.WHITE)
    return img


def live_court(scenario="normal"):
    """Tela 'Quadra ao vivo' (tablet, paisagem)."""
    W, H = 2300, 1480
    img, d = _new(W, H)
    status_bar(img)
    broadcast = "live" if scenario == "broadcast" else "idle"
    appbar(img, "Quadra ao vivo", broadcast=broadcast)

    # cenários (5 em quadra por equipe)
    if scenario == "exceeded":
        onA = [4, 14, 21, 13, 9]; limitA = 14.0
        onB = [2, 4, 1, 3, 8]; limitB = 14.0
    elif scenario in ("bonus", "broadcast"):
        onA = [5, 4, 13, 14, 21]; limitA = 15.0   # Paula(#5) sub-23 em quadra
        onB = [7, 6, 1, 3, 2]; limitB = 15.0       # Rebeca/Laura sub-23
    else:  # normal
        onA = [14, 21, 9, 4, 25]; limitA = 14.0
        onB = [2, 1, 3, 8, 4]; limitB = 14.0

    bonus_on = scenario in ("bonus", "broadcast")
    headerH = 150
    # header (placar)
    hy = 110
    d.rectangle([0, hy, W, hy + headerH], fill=S.WHITE)
    d.line([0, hy + headerH, W, hy + headerH], fill=S.SLATE200, width=2)
    center_text(d, W / 2, hy + 16, "IREFES   ×   ADESUL", font(30, bold=True), S.BLUE_DEEP)

    def player_by(team, n):
        return next(p for p in team if p["n"] == n)

    def on_list(team, nums):
        res = []
        for n in nums:
            p = player_by(team, n)
            res.append({"class": p["c"], "class_val": p["cv"], "number": p["n"],
                        "bonus": bool(bonus_on and p.get("u23"))})
        return res

    onA_d = on_list(IREFES, onA)
    onB_d = on_list(ADESUL, onB)
    totalA = sum(p["class_val"] for p in onA_d)
    totalB = sum(p["class_val"] for p in onB_d)
    bA = any(p["bonus"] for p in onA_d)
    bB = any(p["bonus"] for p in onB_d)

    def score_cell(box, total, limit, over, bonus):
        rrect(d, box, 10, fill=S.ALERT_BG if over else S.SLATE50,
              outline=S.ALERT if over else S.SLATE200, width=2)
        cx = (box[0] + box[2]) / 2
        s = f"{total:.1f}"
        f1 = font(40, bold=True); f2 = font(24, bold=True)
        lim = f" / {limit:.1f}"
        tw = text_w(d, s, f1) + text_w(d, lim, f2) + (28 if bonus else 0)
        x = cx - tw / 2
        d.text((x, box[1] + 14), s, font=f1, fill=S.ALERT if over else S.BLUE_DEEP)
        x += text_w(d, s, f1)
        d.text((x, box[1] + 26), lim, font=f2, fill=S.TEXT2)
        x += text_w(d, lim, f2)
        if bonus:
            icon_star(d, x + 14, box[1] + 32, 13, S.ORANGE)
        if over:
            center_text(d, cx, box[1] + 64, "Limite excedido.", font(20, bold=True), S.ALERT)

    score_cell([W / 2 - 470, hy + 56, W / 2 - 30, hy + 140], totalA, limitA, totalA > limitA + 1e-9, bA)
    score_cell([W / 2 + 30, hy + 56, W / 2 + 470, hy + 140], totalB, limitB, totalB > limitB + 1e-9, bB)

    body_top = hy + headerH
    body_bot = H - 110
    # court central
    court_h = body_bot - body_top - 80
    court_w = int(court_h * 1504 / 2816)
    court = court_board((court_w, court_h), "claro", onA_d, onB_d, "white", "darkBlue",
                        limitA, limitB, show_hints=False, teamA_name="IREFES", teamB_name="ADESUL")
    cx0 = int(W / 2 - court_w / 2)
    img.paste(court, (cx0, body_top + 20), court)
    # toggle estilo quadra
    center_text(d, W / 2, body_bot - 50, "Estilo da quadra", font(20), S.TEXT2)

    # listas laterais
    def side_list(x0, x1, team, on_nums, jersey_id, isA):
        center_text(d, (x0 + x1) / 2, body_top + 10, "IREFES" if isA else "ADESUL", font(24, bold=True), S.TEXT)
        ly = body_top + 50
        rowh = (body_bot - ly) / len(team)
        rowh = min(rowh, 86)
        for p in team:
            sel = p["n"] in on_nums
            box = [x0, ly, x1, ly + rowh - 8]
            rrect(d, box, 8, fill=S.BLUE_SOFT if sel else S.WHITE,
                  outline=S.BLUE if sel else S.SLATE200, width=2)
            if sel:
                rrect(d, [x0 + 2, ly + 8, x0 + 7, ly + rowh - 16], 2, fill=S.BLUE)
            jersey_icon(img, x0 + 44, ly + (rowh - 8) / 2, 48, jersey_id, p["n"])
            tx = x0 + 80
            if bonus_on and p.get("u23"):
                icon_star(d, tx + 10, ly + (rowh - 8) / 2, 11, S.ORANGE)
                tx += 26
            nm = p["name"]
            f = font(20)
            while text_w(d, nm, f) > x1 - tx - 60:
                nm = nm[:-2]
            disp = p["name"] if text_w(d, p["name"], f) <= x1 - tx - 60 else nm + "…"
            d.text((tx, ly + (rowh - 8) / 2 - 14), disp, font=f, fill=S.TEXT)
            d.text((x1 - 50, ly + (rowh - 8) / 2 - 16), p["c"], font=font(22, bold=True), fill=S.TEXT)
            ly += rowh

    side_list(30, 660, IREFES, onA, "white", True)
    side_list(W - 660, W - 30, ADESUL, onB, "darkBlue", False)

    # botões operacionais
    by = H - 96
    d.rectangle([0, by - 10, W, H], fill=S.WHITE)
    d.line([0, by - 10, W, by - 10], fill=S.SLATE200, width=2)
    btns = [("Limpar Equipe A", "bs"), ("Limpar Equipe B", "bs"), ("Limpar tudo", "del"),
            ("Trocar equipes", "swap"), ("Carregar outro arquivo", "up")]
    bx = W / 2 - 1020
    for lab, ic in btns:
        f = font(20, bold=True)
        w = text_w(d, lab, f) + 90
        box = [bx, by + 6, bx + w, by + 66]
        rrect(d, box, 10, outline=S.BLUE_DEEP, width=2)
        if ic == "swap":
            icon_swap(d, bx + 32, by + 36, 22, S.BLUE_DEEP)
        elif ic == "up":
            icon_cloud_upload(d, bx + 32, by + 36, 26, S.BLUE_DEEP)
        else:
            d.rectangle([bx + 20, by + 24, bx + 44, by + 48], outline=S.BLUE_DEEP, width=3)
        d.text((bx + 56, by + 22), lab, font=f, fill=S.BLUE_DEEP)
        bx += w + 24
    return img


def broadcast_dialog():
    """Tela quadra ao vivo (transmitindo) com o pop-up de QR por cima."""
    base = live_court("broadcast")
    # escurece o fundo
    overlay = Image.new("RGBA", base.size, (0, 0, 0, 120))
    base = Image.alpha_composite(base.convert("RGBA"), overlay).convert("RGB")
    d = ImageDraw.Draw(base)
    W, H = base.size
    dw, dh = 720, 980
    x0 = (W - dw) // 2
    y0 = (H - dh) // 2
    rrect(d, [x0, y0, x0 + dw, y0 + dh], 24, fill=S.WHITE)
    d.text((x0 + 40, y0 + 34), "Transmissão ao vivo", font=font(34, bold=True), fill=S.TEXT)
    y = y0 + 100
    for ln in S.wrap(d, "Aponte a câmera no QR code ou copie o link. A página pública mostra apenas a quadra ao vivo.", font(22), dw - 80):
        center_text(d, x0 + dw / 2, y, ln, font(22), S.TEXT2); y += 32
    y += 20
    # QR real
    import qrcode
    url = "https://cbbc-quadra-live.pages.dev/v/K7P2M"
    qr = qrcode.make(url).convert("RGB").resize((360, 360))
    qrbox = [x0 + dw / 2 - 196, y, x0 + dw / 2 + 196, y + 392]
    rrect(d, qrbox, 12, fill=S.WHITE, outline=S.SLATE200, width=2)
    base.paste(qr, (int(qrbox[0] + 16), int(qrbox[1] + 16)))
    y += 420
    # link copiável
    lb = [x0 + 40, y, x0 + dw - 40, y + 70]
    rrect(d, lb, 8, fill=S.SLATE50, outline=S.SLATE200, width=2)
    d.text((lb[0] + 16, y + 20), url, font=font(22, bold=True), fill=S.TEXT)
    icon_copy(d, lb[2] - 30, y + 35, 26, S.BLUE)
    y += 110
    # ações
    d.text((x0 + 60, y), "Encerrar", font=font(26, bold=True), fill=S.ALERT)
    rrect(d, [x0 + dw - 220, y - 10, x0 + dw - 40, y + 50], 12, fill=S.BLUE)
    center_text(d, x0 + dw - 130, y + 6, "Fechar", font(24, bold=True), S.WHITE)
    return base


def public_viewer():
    """Página pública (navegador) — só a quadra, fundo preto."""
    W, H = 1200, 1500
    content = Image.new("RGB", (W, H), (0, 0, 0))
    onA = [{"class": p["c"], "class_val": p["cv"], "number": p["n"],
            "bonus": bool(p.get("u23"))} for p in IREFES if p["n"] in [5, 4, 13, 14, 21]]
    onB = [{"class": p["c"], "class_val": p["cv"], "number": p["n"],
            "bonus": bool(p.get("u23"))} for p in ADESUL if p["n"] in [7, 6, 1, 3, 2]]
    court_h = H - 40
    court_w = int(court_h * 1504 / 2816)
    court = court_board((court_w, court_h), "claro", onA, onB, "white", "darkBlue",
                        15.0, 15.0, show_hints=False)
    content.paste(court, (int(W / 2 - court_w / 2), 20), court)
    return browser_frame(content, "cbbc-quadra-live.pages.dev/v/K7P2M")


def live_phone():
    """Quadra ao vivo no celular (abas)."""
    img, d = _new(PHONE_W, 1480)
    status_bar(img)
    appbar(img, "Quadra ao vivo", broadcast="idle")
    y = 110
    # placar
    d.rectangle([0, y, PHONE_W, y + 150], fill=S.WHITE)
    center_text(d, PHONE_W / 2, y + 12, "IREFES   ×   ADESUL", font(26, bold=True), S.BLUE_DEEP)
    for i, (tot, lab) in enumerate([(13.5, "A"), (13.5, "B")]):
        box = [40 + i * 350, y + 50, 40 + i * 350 + 320, y + 134]
        rrect(d, box, 10, fill=S.SLATE50, outline=S.SLATE200, width=2)
        center_text(d, (box[0] + box[2]) / 2, y + 64, f"{tot:.1f} / 14.0", font(34, bold=True), S.BLUE_DEEP)
    y += 160
    # abas
    tabs = ["IREFES", "Quadra", "ADESUL"]
    for i, t in enumerate(tabs):
        tx = i * PHONE_W / 3
        sel = i == 1
        center_text(d, tx + PHONE_W / 6, y + 12, t, font(23, bold=True), S.BLUE if sel else S.TEXT2)
        if sel:
            d.rectangle([tx + 30, y + 50, tx + PHONE_W / 3 - 30, y + 54], fill=S.BLUE)
    y += 70
    # quadra
    onA = [{"class": p["c"], "class_val": p["cv"], "number": p["n"], "bonus": False}
           for p in IREFES if p["n"] in [14, 21, 9, 4, 25]]
    onB = [{"class": p["c"], "class_val": p["cv"], "number": p["n"], "bonus": False}
           for p in ADESUL if p["n"] in [2, 1, 3, 8, 4]]
    ch = 1480 - y - 30
    cw = int(ch * 1504 / 2816)
    if cw > PHONE_W - 60:
        cw = PHONE_W - 60
        ch = int(cw * 2816 / 1504)
    court = court_board((cw, ch), "claro", onA, onB, "white", "darkBlue", 14.0, 14.0, show_hints=False)
    img.paste(court, (int(PHONE_W / 2 - cw / 2), y), court)
    return img


def missing_data():
    """Tela 'Dados pendentes' (erros bloqueantes)."""
    img, d = _new(PHONE_W, 1300)
    status_bar(img)
    h = appbar(img, "Dados pendentes")
    y = h + 30
    d.text((40, y), "Há atletas com informações faltando.", font=font(26, bold=True), fill=S.TEXT)
    y += 44
    for ln in S.wrap(d, "Corrija os dados no arquivo de origem e carregue novamente.", font(22), PHONE_W - 80):
        d.text((40, y), ln, font=font(22), fill=S.TEXT); y += 32
    y += 16
    blocks = [
        ("Atletas sem classe funcional (2)",
         "Adicione a classe (1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5).",
         ["Atleta: Joana M. Pereira · Clube: APP · Linha: 7",
          "Atleta: Carla S. Dias · Clube: APP · Linha: 9"]),
        ("Atletas sem data de nascimento (1)",
         "Preencha a data de nascimento (DD/MM/AAAA).",
         ["Atleta: Beatriz Lima · Clube: ALL STAR RODAS PARÁ · Linha: 14"]),
    ]
    for title, hint, lines in blocks:
        bh = 120 + len(lines) * 34
        card = [30, y, PHONE_W - 30, y + bh]
        rrect(d, card, 14, fill=S.WHITE, outline=S.SLATE200, width=2)
        icon_error(d, 64, y + 36, 20, S.ALERT)
        d.text((96, y + 22), title, font=font(23, bold=True), fill=S.TEXT)
        d.text((58, y + 64), hint, font=font(19), fill=S.TEXT)
        ly = y + 100
        for li in lines:
            d.text((58, ly), "• " + li, font=font(18), fill=S.TEXT2); ly += 34
        y = card[3] + 22
    by = 1200
    d.rectangle([0, by - 10, PHONE_W, 1300], fill=S.WHITE)
    d.line([0, by - 10, PHONE_W, by - 10], fill=S.SLATE200, width=2)
    rrect(d, [40, by + 8, PHONE_W - 40, by + 80], 14, fill=S.BLUE)
    icon_cloud_upload(d, 250, by + 44, 26, S.WHITE)
    d.text((282, by + 26), "Carregar outro arquivo", font=font(24, bold=True), fill=S.WHITE)
    return img


if __name__ == "__main__":
    out = {
        "splash": splash, "home": home, "validation": validation_summary,
        "missing": missing_data,
        "setup": match_setup, "live_normal": lambda: live_court("normal"),
        "live_exceeded": lambda: live_court("exceeded"), "live_bonus": lambda: live_court("bonus"),
        "broadcast": broadcast_dialog, "viewer": public_viewer, "live_phone": live_phone,
    }
    import sys
    only = sys.argv[1:] if len(sys.argv) > 1 else list(out)
    for name in only:
        img = out[name]()
        img.convert("RGB").save(os.path.join(BUILD, f"{name}.png"))
        print("rendered", name, img.size)
