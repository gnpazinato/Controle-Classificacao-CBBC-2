"""
Renderizadores fiéis das telas do app Controle de Classificação CBBC (v2.3.4).

Cada função devolve uma imagem PIL representando uma tela real do aplicativo,
usando a mesma paleta (CbbcColors), tipografia e layout do código Flutter.
São usadas como "capturas de tela" no manual em PDF.

Como a internet do ambiente de build é bloqueada, as fotos das atletas
aparecem com a silhueta-fallback real do app (retrato azul) — exatamente o
que o app mostra offline. Com conexão, o mesmo chip exibe a foto da atleta.
"""

import os
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
ASSETS = os.path.join(REPO, "assets", "images")

# ----------------------------------------------------------------------------
# Paleta (lib/theme/cbbc_theme.dart)
# ----------------------------------------------------------------------------
BLUE = (0x1F, 0x66, 0xB6)
BLUE_DEEP = (0x15, 0x4B, 0x82)
BLUE_SOFT = (0xDC, 0xE9, 0xF5)
ORANGE = (0xE8, 0x7B, 0x2B)
ORANGE2 = (0xF9, 0x73, 0x16)
SURFACE = (0xFF, 0xFF, 0xFF)
SLATE50 = (0xF8, 0xFA, 0xFC)
SLATE100 = (0xF1, 0xF5, 0xF9)
SLATE200 = (0xE2, 0xE8, 0xF0)
SUCCESS = (0x1B, 0x8A, 0x3A)
TEXT = (0x1A, 0x1A, 0x1A)
TEXT2 = (0x5A, 0x60, 0x68)
ALERT = (0xB3, 0x26, 0x1E)
ALERT_BG = (0xFD, 0xEC, 0xEC)
WARN_BG = (0xFF, 0xF7, 0xE0)
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)

# Jersey colors: (fill, number_color)
JERSEY = {
    "white": ((0xFF, 0xFF, 0xFF), TEXT),
    "darkBlue": ((0x0E, 0x25, 0x47), WHITE),
    "black": ((0x11, 0x11, 0x11), WHITE),
    "darkRed": ((0x8B, 0x1A, 0x1A), WHITE),
    "darkGray": ((0x3F, 0x3F, 0x3F), WHITE),
}

# ----------------------------------------------------------------------------
# Fontes
# ----------------------------------------------------------------------------
FONT_DIR = "/usr/share/fonts/truetype/dejavu"
_FONT_CACHE = {}


def font(size, bold=False):
    key = (size, bold)
    if key not in _FONT_CACHE:
        name = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
        _FONT_CACHE[key] = ImageFont.truetype(os.path.join(FONT_DIR, name), size)
    return _FONT_CACHE[key]


# ----------------------------------------------------------------------------
# Helpers de desenho
# ----------------------------------------------------------------------------
def rrect(d, box, radius, fill=None, outline=None, width=1):
    d.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def text(d, xy, s, f, fill, anchor=None):
    d.text(xy, s, font=f, fill=fill, anchor=anchor)


def text_w(d, s, f):
    return d.textbbox((0, 0), s, font=f)[2]


def text_h(f):
    asc, desc = f.getmetrics()
    return asc + desc


def center_text(d, cx, y, s, f, fill):
    w = text_w(d, s, f)
    d.text((cx - w / 2, y), s, font=f, fill=fill)


def wrap(d, s, f, max_w):
    words = s.split()
    lines, cur = [], ""
    for wd in words:
        t = (cur + " " + wd).strip()
        if text_w(d, t, f) <= max_w:
            cur = t
        else:
            if cur:
                lines.append(cur)
            cur = wd
    if cur:
        lines.append(cur)
    return lines


def draw_wrapped(d, xy, s, f, fill, max_w, line_gap=6):
    x, y = xy
    lh = text_h(f) + line_gap
    for ln in wrap(d, s, f, max_w):
        d.text((x, y), ln, font=f, fill=fill)
        y += lh
    return y


def vgrad(size, top, bottom):
    """Gradiente vertical (PIL)."""
    w, h = size
    base = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        base.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return base.resize((w, h))


def dgrad(size, c1, c2):
    """Gradiente diagonal (topo-esq -> base-dir)."""
    w, h = size
    img = Image.new("RGB", size)
    px = img.load()
    for y in range(h):
        for x in range(w):
            t = (x / max(1, w - 1) + y / max(1, h - 1)) / 2
            px[x, y] = tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))
    return img


def paste_rrect(dst, src, box, radius):
    """Cola src dentro de box com cantos arredondados."""
    x0, y0, x1, y1 = box
    w, h = int(x1 - x0), int(y1 - y0)
    src = src.resize((w, h)).convert("RGBA")
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, fill=255)
    dst.paste(src, (int(x0), int(y0)), mask)


# ----------------------------------------------------------------------------
# Ícones vetoriais simples (aproximam Material Icons)
# ----------------------------------------------------------------------------
def icon_star(d, cx, cy, r, fill):
    pts = []
    for i in range(10):
        ang = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.42
        pts.append((cx + rr * math.cos(ang), cy + rr * math.sin(ang)))
    d.polygon(pts, fill=fill)


def icon_cloud_upload(d, cx, cy, s, fill):
    # nuvem
    d.ellipse([cx - s * 0.55, cy - s * 0.12, cx - s * 0.05, cy + s * 0.30], fill=fill)
    d.ellipse([cx - s * 0.10, cy - s * 0.30, cx + s * 0.45, cy + s * 0.25], fill=fill)
    d.ellipse([cx + s * 0.10, cy - s * 0.05, cx + s * 0.55, cy + s * 0.30], fill=fill)
    d.rectangle([cx - s * 0.45, cy + s * 0.10, cx + s * 0.45, cy + s * 0.30], fill=fill)
    # seta
    d.rectangle([cx - s * 0.07, cy + s * 0.02, cx + s * 0.07, cy + s * 0.45], fill=WHITE)
    d.polygon([(cx - s * 0.20, cy + s * 0.10), (cx + s * 0.20, cy + s * 0.10),
               (cx, cy - s * 0.18)], fill=WHITE)


def icon_download(d, cx, cy, s, fill):
    d.rectangle([cx - s * 0.09, cy - s * 0.45, cx + s * 0.09, cy + s * 0.18], fill=fill)
    d.polygon([(cx - s * 0.28, cy + s * 0.05), (cx + s * 0.28, cy + s * 0.05),
               (cx, cy + s * 0.42)], fill=fill)
    d.rectangle([cx - s * 0.42, cy + s * 0.45, cx + s * 0.42, cy + s * 0.55], fill=fill)


def icon_cast(d, cx, cy, s, fill, connected=False):
    # canto/ondas de transmissão
    x0, y0 = cx - s * 0.5, cy - s * 0.45
    x1, y1 = cx + s * 0.5, cy + s * 0.45
    d.rounded_rectangle([x0, y0, x1, y1], radius=s * 0.12, outline=fill, width=max(2, int(s * 0.08)))
    # apaga canto inferior esquerdo p/ ondas
    d.rectangle([x0 - 2, cy + s * 0.05, cx, y1 + 2], fill=None)
    for i, rr in enumerate([0.16, 0.30]):
        d.arc([x0 - s * rr, y1 - s * rr * 2, x0 + s * rr * 2, y1 + s * rr], 270, 360,
              fill=fill, width=max(2, int(s * 0.08)))
    d.ellipse([x0 - s * 0.06, y1 - s * 0.06, x0 + s * 0.08, y1 + s * 0.08], fill=fill)
    if connected:
        d.rounded_rectangle([cx - s * 0.18, cy - s * 0.18, x1 - s * 0.12, cy + s * 0.05],
                            radius=s * 0.06, fill=fill)


def icon_tune(d, cx, cy, s, fill):
    lw = max(2, int(s * 0.10))
    for i, yy in enumerate([cy - s * 0.30, cy + s * 0.05, cy + s * 0.38]):
        d.line([cx - s * 0.5, yy, cx + s * 0.5, yy], fill=fill, width=lw)
        knob = cx - s * 0.2 + i * s * 0.25
        d.ellipse([knob - s * 0.12, yy - s * 0.12, knob + s * 0.12, yy + s * 0.12], fill=fill)


def icon_copy(d, cx, cy, s, fill):
    d.rounded_rectangle([cx - s * 0.42, cy - s * 0.30, cx + s * 0.18, cy + s * 0.45],
                        radius=s * 0.08, outline=fill, width=max(2, int(s * 0.08)))
    d.rounded_rectangle([cx - s * 0.18, cy - s * 0.45, cx + s * 0.42, cy + s * 0.30],
                        radius=s * 0.08, fill=WHITE, outline=fill, width=max(2, int(s * 0.08)))


def icon_check_circle(d, cx, cy, r, fill):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=fill, width=max(2, int(r * 0.14)))
    d.line([cx - r * 0.4, cy + r * 0.05, cx - r * 0.05, cy + r * 0.4],
           fill=fill, width=max(2, int(r * 0.16)))
    d.line([cx - r * 0.05, cy + r * 0.4, cx + r * 0.45, cy - r * 0.35],
           fill=fill, width=max(2, int(r * 0.16)))


def icon_error(d, cx, cy, r, fill):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=fill, width=max(2, int(r * 0.14)))
    d.rectangle([cx - r * 0.10, cy - r * 0.45, cx + r * 0.10, cy + r * 0.15], fill=fill)
    d.ellipse([cx - r * 0.12, cy + r * 0.30, cx + r * 0.12, cy + r * 0.54], fill=fill)


def icon_play(d, cx, cy, s, fill):
    d.polygon([(cx - s * 0.3, cy - s * 0.42), (cx - s * 0.3, cy + s * 0.42),
               (cx + s * 0.4, cy)], fill=fill)


def icon_swap(d, cx, cy, s, fill):
    lw = max(2, int(s * 0.09))
    d.line([cx - s * 0.4, cy - s * 0.18, cx + s * 0.4, cy - s * 0.18], fill=fill, width=lw)
    d.polygon([(cx + s * 0.4, cy - s * 0.32), (cx + s * 0.4, cy - s * 0.04), (cx + s * 0.55, cy - s * 0.18)], fill=fill)
    d.line([cx - s * 0.4, cy + s * 0.18, cx + s * 0.4, cy + s * 0.18], fill=fill, width=lw)
    d.polygon([(cx - s * 0.4, cy + s * 0.04), (cx - s * 0.4, cy + s * 0.32), (cx - s * 0.55, cy + s * 0.18)], fill=fill)


def icon_groups(d, cx, cy, s, fill):
    d.ellipse([cx - s * 0.30, cy - s * 0.40, cx + s * 0.05, cy - s * 0.05], fill=fill)
    d.ellipse([cx - s * 0.05, cy - s * 0.34, cx + s * 0.34, cy + s * 0.02], fill=fill)
    d.rounded_rectangle([cx - s * 0.42, cy + s * 0.02, cx + s * 0.10, cy + s * 0.42], radius=s * 0.12, fill=fill)
    d.rounded_rectangle([cx - s * 0.05, cy + s * 0.06, cx + s * 0.45, cy + s * 0.42], radius=s * 0.12, fill=fill)


def icon_ball(d, cx, cy, r, fill):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=fill, width=max(2, int(r * 0.12)))
    d.line([cx - r, cy, cx + r, cy], fill=fill, width=max(2, int(r * 0.10)))
    d.line([cx, cy - r, cx, cy + r], fill=fill, width=max(2, int(r * 0.10)))
    d.arc([cx - r * 1.9, cy - r, cx - r * 0.1, cy + r * 3], 270, 360, fill=fill, width=max(2, int(r * 0.10)))


def icon_edit(d, cx, cy, s, fill):
    d.line([cx - s * 0.35, cy + s * 0.35, cx + s * 0.30, cy - s * 0.30], fill=fill, width=max(2, int(s * 0.16)))
    d.polygon([(cx - s * 0.45, cy + s * 0.45), (cx - s * 0.30, cy + s * 0.40),
               (cx - s * 0.40, cy + s * 0.30)], fill=fill)


def icon_qr_small(d, cx, cy, s, fill):
    # ícone de QR estilizado
    cell = s / 5
    pat = ["11011", "01010", "11001", "00110", "10111"]
    for j, row in enumerate(pat):
        for i, c in enumerate(row):
            if c == "1":
                x = cx - s / 2 + i * cell
                y = cy - s / 2 + j * cell
                d.rectangle([x, y, x + cell - 1, y + cell - 1], fill=fill)


def person_silhouette(img, box):
    """Desenha silhueta branca (fallback de foto do app) dentro de box RGBA."""
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    d = ImageDraw.Draw(img)
    cx = x0 + w / 2
    head_r = w * 0.20
    head_cy = y0 + h * 0.34
    d.ellipse([cx - head_r, head_cy - head_r, cx + head_r, head_cy + head_r],
              fill=(255, 255, 255, 235))
    # ombros
    sh_w = w * 0.62
    sh_top = y0 + h * 0.58
    d.pieslice([cx - sh_w / 2, sh_top, cx + sh_w / 2, sh_top + h * 0.7],
               180, 360, fill=(255, 255, 255, 235))


# ----------------------------------------------------------------------------
# Componentes
# ----------------------------------------------------------------------------
def load_logo(white=False, h=120):
    logo = Image.open(os.path.join(ASSETS, "cbbc-logo.png")).convert("RGBA")
    ratio = h / logo.height
    logo = logo.resize((int(logo.width * ratio), h))
    if white:
        # tinge de branco preservando alfa
        alpha = logo.split()[3]
        white_img = Image.new("RGBA", logo.size, (255, 255, 255, 0))
        white_img.putalpha(alpha)
        return white_img
    return logo


def status_bar(img, dark=False):
    """Barra de status do tablet/celular no topo."""
    d = ImageDraw.Draw(img)
    w = img.width
    col = WHITE if dark else TEXT
    f = font(26, bold=True)
    d.text((28, 14), "09:41", font=f, fill=col)
    # wifi + bateria simples (à direita)
    bx = w - 120
    for i in range(4):
        bh = 8 + i * 6
        d.rectangle([bx + i * 14, 36 - bh, bx + i * 14 + 9, 36], fill=col)
    d.rounded_rectangle([w - 56, 16, w - 20, 36], radius=4, outline=col, width=3)
    d.rectangle([w - 18, 22, w - 14, 30], fill=col)


def appbar(img, title, broadcast=None):
    """Barra azul do app com logo + título centralizado. broadcast: None|'idle'|'live'."""
    d = ImageDraw.Draw(img)
    w = img.width
    H = 96
    d.rectangle([0, 0, w, H], fill=BLUE)
    logo = load_logo(white=True, h=58)
    lx = w / 2 - (text_w(d, title, font(30, bold=True)) / 2) - logo.width - 14
    img.paste(logo, (int(lx), int(H / 2 - logo.height / 2)), logo)
    center_text(d, w / 2 + logo.width / 2 + 7, H / 2 - 18, title, font(30, bold=True), WHITE)
    if broadcast is not None:
        col = ORANGE if broadcast == "live" else WHITE
        icon_cast(d, w - 150, H / 2, 30, col, connected=(broadcast == "live"))
        icon_tune(d, w - 70, H / 2, 26, WHITE)
    return H


def jersey_icon(img, cx, cy, size, jersey_id, number):
    """Camisa de basquete vetorial com número (PlayerJerseyIcon)."""
    d = ImageDraw.Draw(img)
    fill, num_col = JERSEY[jersey_id]
    s = size
    x = cx - s / 2
    y = cy - s / 2

    def P(px, py):
        return (x + s * px, y + s * py)
    body = [P(.18, .22), P(.35, .10), P(.42, .22), P(.50, .34), P(.58, .22),
            P(.65, .10), P(.82, .22), P(.80, .40), P(.90, .92), P(.10, .92),
            P(.20, .40), P(.18, .22)]
    d.polygon(body, fill=fill, outline=num_col)
    # contorno mais forte
    d.line(body, fill=num_col, width=max(1, int(s * 0.04)), joint="curve")
    nf = font(int(s * 0.42), bold=True)
    center_text(d, cx, cy + s * 0.06, str(number), nf, num_col)


def portrait_chip(canvas, center, chip_w, chip_h, jersey_id, pclass, number, bonus=False):
    """Chip de retrato em quadra (PlayerPortraitChip) com silhueta fallback."""
    cw, ch = int(chip_w), int(chip_h)
    chip = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    # gradiente azul (fallback)
    grad = dgrad((cw, ch), BLUE, BLUE_DEEP).convert("RGBA")
    notch = min(cw, ch) * 0.17
    rad = min(cw, ch) * 0.055
    mask = Image.new("L", (cw, ch), 0)
    md = ImageDraw.Draw(mask)
    md.polygon([(notch, 0), (cw - rad, 0), (cw, rad), (cw, ch - rad),
                (cw - rad, ch), (rad, ch), (0, ch - rad), (0, notch)], fill=255)
    chip.paste(grad, (0, 0), mask)
    person_silhouette(chip, (0, 0, cw, ch))

    d = ImageDraw.Draw(chip)
    fill, num_col = JERSEY[jersey_id]
    # class badge (pill, esquerda)
    cb = ch * 0.26
    pill_w, pill_h = cb * 1.15, cb
    px = -cb * 0.50
    py = ch * 0.05
    d.rounded_rectangle([px, py, px + pill_w, py + pill_h], radius=pill_h * 0.34,
                        fill=fill, outline=(255, 255, 255, 225), width=2)
    center_text(d, px + pill_w / 2, py + pill_h / 2 - cb * 0.34, pclass, font(int(cb * 0.55), bold=True), num_col)
    # jersey badge (círculo, dir-baixo)
    jb = ch * 0.28
    jx = cw - jb * 0.55
    jy = ch * 0.88 - jb
    d.ellipse([jx, jy, jx + jb, jy + jb], fill=fill, outline=num_col, width=2)
    center_text(d, jx + jb / 2, jy + jb / 2 - jb * 0.36, str(number), font(int(jb * 0.5), bold=True), num_col)
    # star bonus (dir-topo)
    if bonus:
        sb = jb * 0.88
        sx = cw - sb * 0.55
        sy = -sb * 0.12
        d.ellipse([sx, sy, sx + sb, sy + sb], fill=ORANGE, outline=WHITE, width=2)
        icon_star(d, sx + sb / 2, sy + sb / 2, sb * 0.30, WHITE)

    cx, cy = center
    canvas.alpha_composite(chip, (int(cx - cw / 2), int(cy - ch / 2)))


def score_badge(canvas, pos, anchor, total, limit, is_over, bonus, corner):
    """Placar flutuante nos cantos da quadra."""
    d0 = ImageDraw.Draw(canvas)
    f_total = max(11, min(22, anchor * 0.034)) * 1.0
    f_total = int(f_total * 1.6)
    f_limit = int(f_total * 0.78)
    padH = int(max(6, min(14, anchor * 0.022)) * 1.6)
    padV = int(max(3, min(8, anchor * 0.014)) * 1.6)
    ft = font(f_total, bold=True)
    fl = font(f_limit, bold=True)
    s_total = f"{total:.1f}"
    s_limit = f" / {limit:.1f}"
    star_w = int(f_total * 0.9) if bonus else 0
    tw = text_w(d0, s_total, ft) + text_w(d0, s_limit, fl) + star_w + padH * 2
    th = f_total + padV * 2
    x, y = pos
    if corner == "br":
        x -= tw
        y -= th
    # sombra + fundo
    badge = Image.new("RGBA", (int(tw) + 12, int(th) + 12), (0, 0, 0, 0))
    bd = ImageDraw.Draw(badge)
    bd.rounded_rectangle([6, 6, tw + 6, th + 6], radius=int(min(12, anchor * 0.022 * 1.6)),
                         fill=(255, 255, 255, 247))
    if is_over:
        bd.rounded_rectangle([6, 6, tw + 6, th + 6], radius=int(min(12, anchor * 0.022 * 1.6)),
                             outline=ALERT, width=3)
    tcol = ALERT if is_over else BLUE_DEEP
    bx = 6 + padH
    bd.text((bx, 6 + padV - 2), s_total, font=ft, fill=tcol)
    bx += text_w(bd, s_total, ft)
    bd.text((bx, 6 + padV + (f_total - f_limit) - 2), s_limit, font=fl, fill=TEXT2)
    bx += text_w(bd, s_limit, fl)
    if bonus:
        icon_star(bd, bx + star_w / 2, 6 + th / 2, star_w * 0.45, ORANGE)
    canvas.alpha_composite(badge, (int(x - 6), int(y - 6)))


def court_board(size, court_style, teamA_on, teamB_on, jerseyA, jerseyB,
                limitA, limitB, show_hints=True, teamA_name="", teamB_name=""):
    """
    Tabuleiro da quadra (CourtBoard). teamX_on: lista de até 5 dicts
    {class,number,bonus} ou None. Devolve imagem RGBA portrait.
    """
    w, h = size
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    asset = "quadra1.png" if court_style == "claro" else "quadra2.png"
    court = Image.open(os.path.join(ASSETS, asset)).convert("RGBA")
    court = court.rotate(-90, expand=True)
    # cover
    cr = max(w / court.width, h / court.height)
    court = court.resize((int(court.width * cr), int(court.height * cr)))
    cx0 = (court.width - w) // 2
    cy0 = (court.height - h) // 2
    court = court.crop((cx0, cy0, cx0 + w, cy0 + h))

    has_any = any(teamA_on) or any(teamB_on)
    if has_any:
        # opacity 0.76 + overlay branco 0.18  => clareia
        white = Image.new("RGBA", (w, h), (255, 255, 255, int(255 * 0.30)))
        court = Image.alpha_composite(court, white)
    canvas.alpha_composite(court, (0, 0))

    d = ImageDraw.Draw(canvas)
    # borda arredondada (recorta)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=14, fill=255)
    canvas.putalpha(mask)
    d = ImageDraw.Draw(canvas)
    d.rounded_rectangle([1, 1, w - 2, h - 2], radius=14, outline=SLATE200, width=2)

    targetsA = [(0.22, 0.13), (0.50, 0.13), (0.78, 0.13), (0.36, 0.37), (0.64, 0.37)]
    targetsB = [(0.22, 0.87), (0.50, 0.87), (0.78, 0.87), (0.36, 0.63), (0.64, 0.63)]
    slot_w = w * 0.22
    slot_h = h * 0.16
    chip_h = slot_h
    chip_w = min(slot_w, chip_h * 0.84)

    if show_hints and not any(teamA_on):
        _hint(canvas, w * 0.5, h * 0.225, f"Toque nos atletas da {teamA_name}")
    if show_hints and not any(teamB_on):
        _hint(canvas, w * 0.5, h * 0.775, f"Toque nos atletas da {teamB_name}")

    for i, p in enumerate(teamA_on):
        if p:
            cx, cy = w * targetsA[i][0], h * targetsA[i][1]
            portrait_chip(canvas, (cx, cy), chip_w, chip_h, jerseyA, p["class"], p["number"], p.get("bonus"))
    for i, p in enumerate(teamB_on):
        if p:
            cx, cy = w * targetsB[i][0], h * targetsB[i][1]
            portrait_chip(canvas, (cx, cy), chip_w, chip_h, jerseyB, p["class"], p["number"], p.get("bonus"))

    totalA = sum(p["class_val"] for p in teamA_on if p)
    totalB = sum(p["class_val"] for p in teamB_on if p)
    bonusA = any(p.get("bonus") for p in teamA_on if p)
    bonusB = any(p.get("bonus") for p in teamB_on if p)
    margin = w * 0.018
    score_badge(canvas, (margin, margin), w, totalA, limitA, totalA > limitA + 1e-9, bonusA, "tl")
    score_badge(canvas, (w - margin, h - margin), w, totalB, limitB, totalB > limitB + 1e-9, bonusB, "br")
    return canvas


def _hint(canvas, cx, cy, s):
    d = ImageDraw.Draw(canvas)
    f = font(20, bold=True)
    tw = text_w(d, s, f)
    box = [cx - tw / 2 - 14, cy - 20, cx + tw / 2 + 14, cy + 20]
    overlay = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    od.rounded_rectangle(box, radius=8, fill=(255, 255, 255, 217))
    canvas.alpha_composite(overlay)
    d.text((cx - tw / 2, cy - text_h(f) / 2), s, font=f, fill=TEXT)


# Frames de dispositivo --------------------------------------------------------
def phone_frame(content):
    """Envolve conteúdo (já com status bar) numa moldura de celular."""
    pad = 26
    radius = 70
    w = content.width + pad * 2
    h = content.height + pad * 2
    frame = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, fill=(28, 30, 34, 255))
    paste_rrect(frame, content.convert("RGB"), (pad, pad, w - pad, h - pad), radius - 18)
    return frame


def tablet_frame(content):
    pad = 30
    radius = 46
    w = content.width + pad * 2
    h = content.height + pad * 2
    frame = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, fill=(28, 30, 34, 255))
    paste_rrect(frame, content.convert("RGB"), (pad, pad, w - pad, h - pad), radius - 16)
    return frame


def browser_frame(content, url):
    """Moldura de navegador com barra de endereço."""
    bar = 70
    w = content.width
    h = content.height + bar
    frame = Image.new("RGB", (w, h), (240, 242, 245))
    d = ImageDraw.Draw(frame)
    d.rectangle([0, 0, w, bar], fill=(228, 231, 236))
    for i, c in enumerate([(0xED, 0x6A, 0x5E), (0xF4, 0xBF, 0x4F), (0x61, 0xC5, 0x54)]):
        d.ellipse([24 + i * 34, bar / 2 - 11, 24 + i * 34 + 22, bar / 2 + 11], fill=c)
    d.rounded_rectangle([150, 14, w - 30, bar - 14], radius=18, fill=WHITE, outline=(205, 209, 215), width=2)
    f = font(26)
    d.text((175, bar / 2 - text_h(f) / 2), url, font=f, fill=(60, 64, 70))
    frame.paste(content, (0, bar))
    return frame
