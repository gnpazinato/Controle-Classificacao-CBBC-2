import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/player.dart';
import '../theme/cbbc_theme.dart';

class PlayerPortraitChip extends StatelessWidget {
  const PlayerPortraitChip({
    super.key,
    required this.player,
    required this.jerseyColor,
    required this.isBonusEligible,
    required this.maxWidth,
    required this.maxHeight,
    this.onTap,
  });

  final Player player;
  final JerseyColor jerseyColor;
  final bool isBonusEligible;
  final double maxWidth;
  final double maxHeight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Chip dimensions scale fully with the available box (no fixed clamps)
    // so that on portrait/landscape tablets everything keeps the same
    // relative proportions to the court behind it.
    final double chipHeight = maxHeight;
    final double chipWidth = math.min(maxWidth, chipHeight * 0.84);

    // Badges são proporcionais ao chip pra acompanhar telas variadas.
    // Class badge: pill um pouco menor (0.26) com overhang reduzido pra
    // não invadir o chip vizinho na linha de 3 atletas da frente.
    final double classBadgeSize = chipHeight * 0.26;
    final double jerseyBadgeSize = chipHeight * 0.28;
    final String? photoUrl = player.photoUrl;

    final Widget stack = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        SizedBox(
          width: chipWidth,
          height: chipHeight,
          child: _PortraitFrame(photoUrl: photoUrl),
        ),
        Positioned(
          // Overhang lateral comedido: o badge encosta na borda esquerda
          // do chip e projeta só ~metade da sua altura pra fora, deixando
          // espaço pro chip ao lado na linha de 3 atletas.
          left: -classBadgeSize * 0.50,
          top: chipHeight * 0.05,
          child: _ClassBadge(
            text: player.playerClass?.toStringAsFixed(1) ?? '—',
            size: classBadgeSize,
            jerseyColor: jerseyColor,
          ),
        ),
        Positioned(
          right: -jerseyBadgeSize * 0.45,
          bottom: chipHeight * 0.12,
          child: _JerseyBadge(
            text: player.shirtNumber.toString(),
            size: jerseyBadgeSize,
            jerseyColor: jerseyColor,
          ),
        ),
        if (isBonusEligible)
          Positioned(
            right: -jerseyBadgeSize * 0.08,
            top: -jerseyBadgeSize * 0.10,
            child: _BonusStarBadge(size: jerseyBadgeSize * 0.88),
          ),
      ],
    );

    final Widget content = Center(
      child: Semantics(
        label: _semanticLabel,
        button: onTap != null,
        child: onTap == null
            ? stack
            : Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  // Hit target generoso na área do chip; sem ripple visível
                  // pra não competir com a sombra do retrato.
                  splashColor: Colors.white.withValues(alpha: 0.18),
                  highlightColor: Colors.white.withValues(alpha: 0.10),
                  customBorder: const _PortraitInkShape(),
                  child: stack,
                ),
              ),
      ),
    );

    return SizedBox(
      width: maxWidth,
      height: maxHeight,
      child: content,
    );
  }

  String get _semanticLabel {
    final String cls = player.playerClass?.toStringAsFixed(1) ?? 'sem classe';
    final String bonus = isBonusEligible ? ', com bonificação' : '';
    return '${player.displayName}, camisa ${player.shirtNumber}, classe $cls$bonus';
  }

  /// Exposto apenas para testes visuais de regressão do crop. Recebe uma
  /// imagem já decodificada e devolve o retângulo de origem que seria
  /// desenhado pelo chip.
  @visibleForTesting
  static Future<Rect> debugComputeCrop(ui.Image image) =>
      _PortraitFrameState._computeSourceRect(image);
}

class _PortraitFrame extends StatefulWidget {
  const _PortraitFrame({required this.photoUrl});

  final String? photoUrl;

  @override
  State<_PortraitFrame> createState() => _PortraitFrameState();
}

class _PortraitFrameState extends State<_PortraitFrame> {
  static final Map<String, Future<_PortraitPhoto?>> _cache =
      <String, Future<_PortraitPhoto?>>{};
  // Cache síncrono: após o future resolver, guardamos o resultado aqui pra
  // que mounts subsequentes do mesmo URL pulem o frame de fallback.
  static final Map<String, _PortraitPhoto?> _resolved =
      <String, _PortraitPhoto?>{};

  _PortraitPhoto? _photo;

  @override
  void initState() {
    super.initState();
    _resolvePhoto();
  }

  @override
  void didUpdateWidget(_PortraitFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) {
      _resolvePhoto();
    }
  }

  void _resolvePhoto() {
    final String? url = widget.photoUrl;
    if (url == null || url.trim().isEmpty) {
      _photo = null;
      return;
    }
    if (_resolved.containsKey(url)) {
      // Hit síncrono — sem flash de fallback.
      _photo = _resolved[url];
      return;
    }
    // Cold load: dispara o future e aguarda; mantém _photo null até resolver.
    _photo = null;
    _futureFor(url).then((_PortraitPhoto? photo) {
      if (!mounted || widget.photoUrl != url) return;
      setState(() {
        _photo = photo;
      });
    });
  }

  /// Compartilhado entre o chip e o pré-carregador. Garante que toda
  /// resolução popule também [_resolved] pra permitir mounts subsequentes
  /// sem o frame de silhueta.
  static Future<_PortraitPhoto?> _futureFor(String url) {
    return _cache.putIfAbsent(url, () async {
      final _PortraitPhoto? photo = await _load(url);
      _resolved[url] = photo;
      return photo;
    });
  }

  static Future<_PortraitPhoto?> _load(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      final ByteData data = await NetworkAssetBundle(uri).load(uri.toString());
      final Uint8List bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final ui.Codec codec =
          await ui.instantiateImageCodec(bytes, targetWidth: 640);
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image image = frame.image;
      final Rect sourceRect = await _computeSourceRect(image);
      return _PortraitPhoto(image: image, sourceRect: sourceRect);
    } catch (_) {
      return null;
    }
  }

  /// Determina o recorte da foto de forma **consistente** entre atletas:
  /// sempre rosto + pescoço + ombros + um pouco da camiseta.
  ///
  /// Estratégia em 3 passos:
  ///
  /// 1. **Cor de fundo adaptativa.** Em vez de assumir fundo branco
  ///    (saturação < 22, como a versão anterior), amostra os pixels das
  ///    bordas superior/laterais e calcula a cor mediana do fundo.
  ///    Funciona com fundos coloridos, escuros ou texturizados.
  ///
  /// 2. **Detecção do sujeito.** Pixel é "sujeito" se a soma das
  ///    distâncias absolutas RGB até a cor de fundo passar do limiar
  ///    (~70 ≈ 24/canal). Isso evita falsos positivos com fundo escuro
  ///    e camiseta escura ao mesmo tempo.
  ///
  /// 3. **Decisão close-up vs crop padronizado.** Estima a largura da
  ///    cabeça pela mediana das larguras de sujeito na faixa superior.
  ///    A altura alvo "rosto + ombros" é ~2.7 × essa largura. Se essa
  ///    altura ideal *não cabe* na foto (ou seja, o rosto já ocupa
  ///    quase toda a altura), entra no branch de close-up: a foto não
  ///    é cortada verticalmente, apenas recentralizada no rosto. Caso
  ///    contrário, faz o crop padronizado com a altura derivada da
  ///    cabeça — o que dá tamanho aparente igual entre fotos com zoom
  ///    diferente.
  static Future<Rect> _computeSourceRect(ui.Image image) async {
    final int width = image.width;
    final int height = image.height;
    final ByteData? raw =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (raw == null) {
      return _centerCrop(width, height);
    }

    final Uint8List pixels = raw.buffer.asUint8List(
      raw.offsetInBytes,
      raw.lengthInBytes,
    );

    final _BgSample bg = _sampleBackground(pixels, width, height);

    bool isSubject(int x, int y) {
      final int idx = (y * width + x) * 4;
      final int r = pixels[idx];
      final int g = pixels[idx + 1];
      final int b = pixels[idx + 2];
      final int distance =
          (r - bg.r).abs() + (g - bg.g).abs() + (b - bg.b).abs();
      return distance > bg.threshold;
    }

    final int step = math.max(1, math.min(width, height) ~/ 360);

    // O retrato sempre tem a atleta centralizada. Fundos com vinheta,
    // sombra nos cantos ou moldura disparam o detector de sujeito nas
    // *bordas* e jogavam o recorte pra fora do rosto (bug das fotos
    // tiradas "de longe"). Para blindar contra isso, toda a busca:
    //   • ignora uma margem horizontal (xMargin) — a atleta nunca encosta
    //     na borda lateral, então pixel de sujeito ali é ruído de fundo;
    //   • exige uma *sequência contígua* mínima de pixels do sujeito —
    //     ruído espalhado nos cantos não forma run e é descartado.
    final int xMargin = (width * 0.07).round();
    final int xStart = xMargin;
    final int xEnd = width - xMargin;
    // Run mínimo pra valer como sujeito (~5 % da largura). Buracos
    // pequenos (olhos, óculos, mechas) até gapTol não quebram o run.
    final int minRun = math.max(2 * step, (width * 0.05).round());
    final int gapTol = math.max(step, (width * 0.04).round());

    // Maior sequência contígua de sujeito na linha [y], dentro da margem.
    // Devolve [start, end] em px, ou null se não atingir minRun.
    List<int>? longestSubjectRun(int y) {
      int bestStart = -1, bestEnd = -1, bestLen = -1;
      int curStart = -1, curEnd = -1, gap = 0;
      void closeRun() {
        if (curStart >= 0) {
          final int len = curEnd - curStart;
          if (len > bestLen) {
            bestLen = len;
            bestStart = curStart;
            bestEnd = curEnd;
          }
        }
      }

      for (int x = xStart; x < xEnd; x += step) {
        if (isSubject(x, y)) {
          if (curStart < 0) curStart = x;
          curEnd = x;
          gap = 0;
        } else if (curStart >= 0) {
          gap += step;
          if (gap > gapTol) {
            closeRun();
            curStart = -1;
            curEnd = -1;
            gap = 0;
          }
        }
      }
      closeRun();
      if (bestLen < minRun) return null;
      return <int>[bestStart, bestEnd];
    }

    // 1. Topo do sujeito: primeira linha com um run contíguo e central.
    int subjectTop = -1;
    for (int y = 0; y < height; y += step) {
      if (longestSubjectRun(y) != null) {
        subjectTop = y;
        break;
      }
    }

    if (subjectTop < 0) {
      return _centerCrop(width, height);
    }

    // 2. Largura/centro da cabeça: mediana dos runs contíguos nas linhas
    //    dentro dos primeiros 18 % abaixo do topo. Como a cabeça domina
    //    essa faixa, a mediana fica imune a alguns ombros largos no fim.
    final int headBandBottom = math.min(
      height,
      subjectTop + (height * 0.18).round(),
    );
    final List<int> widths = <int>[];
    final List<int> centers = <int>[];
    for (int y = subjectTop; y < headBandBottom; y += step) {
      final List<int>? run = longestSubjectRun(y);
      if (run != null) {
        widths.add(run[1] - run[0]);
        centers.add(((run[0] + run[1]) / 2).round());
      }
    }

    double headWidth;
    double headCenterX;
    if (widths.isEmpty) {
      final List<int>? top = longestSubjectRun(subjectTop);
      headWidth = top == null ? width * 0.30 : (top[1] - top[0]).toDouble();
      headCenterX = top == null ? width / 2 : (top[0] + top[1]) / 2;
    } else {
      widths.sort();
      centers.sort();
      headWidth = widths[widths.length ~/ 2].toDouble();
      headCenterX = centers[centers.length ~/ 2].toDouble();
    }
    if (headWidth < 1) headWidth = width * 0.30;

    // 3. Decisão close-up vs crop padronizado.
    //    Constantes alvo: rosto + ombros + pouco da camiseta ≈ 2.7 ×
    //    largura da cabeça, com 22 % de margem acima do topo.
    const double targetCropFactor = 2.7;
    const double topMarginFactor = 0.22;
    final double idealCropHeight = headWidth * targetCropFactor;
    final double idealTopMargin = headWidth * topMarginFactor;

    // Se a altura ideal (com margem) já ultrapassa 92 % da foto, a foto
    // **já veio em close** — não tem espaço pra um crop padronizado.
    // Nesse caso usa a foto inteira só recentralizada no rosto.
    final bool isCloseUp =
        (idealCropHeight + idealTopMargin) >= height * 0.92;

    final double cropHeight;
    final double cropTop;
    if (isCloseUp) {
      cropHeight = height.toDouble();
      cropTop = 0.0;
    } else {
      // Crop padronizado. Aspect ratio retrato 0.82.
      // Limites de segurança: nunca menos que 42 % nem mais que 80 % da
      // altura — protege contra detecções esquisitas.
      cropHeight =
          idealCropHeight.clamp(height * 0.42, height * 0.80).toDouble();
      cropTop = (subjectTop - idealTopMargin)
          .clamp(0.0, math.max(0.0, height - cropHeight))
          .toDouble();
    }

    final double cropWidth =
        math.min(width.toDouble(), cropHeight * 0.82);
    final double cropLeft = (headCenterX - cropWidth / 2)
        .clamp(0.0, math.max(0.0, width - cropWidth))
        .toDouble();

    return Rect.fromLTWH(cropLeft, cropTop, cropWidth, cropHeight);
  }

  /// Amostra os pixels das bordas superior/laterais (faixa superior, evita
  /// pegar a camiseta no rodapé) e devolve a cor mediana do fundo + um
  /// limiar de tolerância.
  static _BgSample _sampleBackground(
    Uint8List pixels,
    int width,
    int height,
  ) {
    final List<int> rs = <int>[];
    final List<int> gs = <int>[];
    final List<int> bs = <int>[];
    final int marginX = math.max(1, (width * 0.05).round());
    final int marginY = math.max(1, (height * 0.05).round());
    final int sideBottom = height ~/ 3;
    final int stepX = math.max(1, width ~/ 40);
    final int stepY = math.max(1, marginY ~/ 4);
    final int sideStepY = math.max(1, sideBottom ~/ 20);
    final int sideStepX = math.max(1, marginX ~/ 4);

    void sample(int x, int y) {
      if (x < 0 || x >= width || y < 0 || y >= height) return;
      final int idx = (y * width + x) * 4;
      rs.add(pixels[idx]);
      gs.add(pixels[idx + 1]);
      bs.add(pixels[idx + 2]);
    }

    // Faixa do topo: linha cheia, várias linhas.
    for (int y = 0; y < marginY; y += stepY) {
      for (int x = 0; x < width; x += stepX) {
        sample(x, y);
      }
    }
    // Faixas laterais — só no terço superior, pra não confundir com camiseta.
    for (int y = 0; y < sideBottom; y += sideStepY) {
      for (int x = 0; x < marginX; x += sideStepX) {
        sample(x, y);
        sample(width - 1 - x, y);
      }
    }

    if (rs.isEmpty) {
      return const _BgSample(r: 255, g: 255, b: 255, threshold: 70);
    }
    rs.sort();
    gs.sort();
    bs.sort();
    final int mid = rs.length ~/ 2;
    return _BgSample(
      r: rs[mid],
      g: gs[mid],
      b: bs[mid],
      // Limiar L1 (soma absoluta RGB) ≈ 24/canal. Suficiente pra separar
      // pele/cabelo/roupa de fundos uniformes; não tão alto que dilua a
      // distinção em fundos escuros.
      threshold: 70,
    );
  }

  static Rect _centerCrop(int width, int height) {
    // Fallback quando a detecção falha: 65 % da altura começando a 20 %
    // do topo dentro da margem vertical disponível. Antes pegava só a
    // metade superior, o que cortava nos olhos em fotos pequenas.
    final double cropHeight =
        (height * 0.65).clamp(1.0, height.toDouble()).toDouble();
    final double cropWidth =
        math.min(width.toDouble(), cropHeight * 0.82);
    final double left = math.max(0.0, (width - cropWidth) / 2);
    final double top = math.max(0.0, (height - cropHeight) * 0.20);
    return Rect.fromLTWH(left, top, cropWidth, cropHeight);
  }

  @override
  Widget build(BuildContext context) {
    final _PortraitPhoto? photo = _photo;
    return CustomPaint(
      painter: _PortraitFramePainter(),
      child: ClipPath(
        clipper: _PortraitClipper(),
        child: photo == null
            ? const _PortraitFallback()
            : CustomPaint(
                painter: _PortraitPhotoPainter(photo),
                child: const SizedBox.expand(),
              ),
      ),
    );
  }
}

class _PortraitFallback extends StatelessWidget {
  const _PortraitFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[CbbcColors.blue, CbbcColors.blueDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: FractionallySizedBox(
          heightFactor: 0.82,
          widthFactor: 0.82,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Icon(
              Icons.person_rounded,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassBadge extends StatelessWidget {
  const _ClassBadge({
    required this.text,
    required this.size,
    required this.jerseyColor,
  });

  final String text;
  final double size;
  final JerseyColor jerseyColor;

  @override
  Widget build(BuildContext context) {
    // Pill arredondado com borda branca fina pra destacar sobre a foto
    // sem precisar de uma sombra pesada. Fonte um pouco mais leve (w800)
    // pra ficar elegante em telas pequenas.
    return Container(
      width: size * 1.15,
      height: size,
      decoration: BoxDecoration(
        color: jerseyColor.fill,
        borderRadius: BorderRadius.circular(size * 0.34),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.88),
          width: 1.1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.14),
          child: Text(
            text,
            style: TextStyle(
              color: jerseyColor.numberColor,
              fontSize: size * 0.54,
              fontWeight: FontWeight.w800,
              height: 1,
              letterSpacing: -0.2,
              fontFeatures: const <ui.FontFeature>[
                ui.FontFeature.tabularFigures(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JerseyBadge extends StatelessWidget {
  const _JerseyBadge({
    required this.text,
    required this.size,
    required this.jerseyColor,
  });

  final String text;
  final double size;
  final JerseyColor jerseyColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: jerseyColor.fill,
        shape: BoxShape.circle,
        border: Border.all(
          color: jerseyColor.numberColor.withValues(alpha: 0.8),
          width: 1.5,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.26),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.all(size * 0.08),
          child: Text(
            text,
            style: TextStyle(
              color: jerseyColor.numberColor,
              fontSize: size * 0.52,
              fontWeight: FontWeight.w900,
              height: 1,
              fontFeatures: const <ui.FontFeature>[
                ui.FontFeature.tabularFigures(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BonusStarBadge extends StatelessWidget {
  const _BonusStarBadge({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[CbbcColors.orange, Color(0xFFF97316)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: CbbcColors.orange.withValues(alpha: 0.48),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.star,
        size: size * 0.56,
        color: Colors.white,
      ),
    );
  }
}

class _PortraitPhoto {
  const _PortraitPhoto({required this.image, required this.sourceRect});

  final ui.Image image;
  final Rect sourceRect;
}

class _BgSample {
  const _BgSample({
    required this.r,
    required this.g,
    required this.b,
    required this.threshold,
  });

  final int r;
  final int g;
  final int b;
  final int threshold;
}

class _PortraitPhotoPainter extends CustomPainter {
  const _PortraitPhotoPainter(this.photo);

  final _PortraitPhoto photo;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect destination = Offset.zero & size;
    final Paint paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;
    canvas.drawImageRect(photo.image, photo.sourceRect, destination, paint);
  }

  @override
  bool shouldRepaint(_PortraitPhotoPainter oldDelegate) =>
      oldDelegate.photo != photo;
}

class _PortraitFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Path path = _portraitPath(size);
    // Sem moldura, sem fundo branco — só sombra projetada para o chip
    // parecer flutuar sobre a quadra.
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path.shift(const Offset(0, 3)), shadowPaint);
  }

  @override
  bool shouldRepaint(_PortraitFramePainter oldDelegate) => false;
}

class _PortraitClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => _portraitPath(size);

  @override
  bool shouldReclip(_PortraitClipper oldClipper) => false;
}

/// Shape "do recorte do retrato" pra que o ripple do InkWell respeite o
/// formato do chip (canto chanfrado em cima à esquerda).
class _PortraitInkShape extends ShapeBorder {
  const _PortraitInkShape();

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _portraitPath(rect.size).shift(rect.topLeft);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _portraitPath(rect.size).shift(rect.topLeft);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}

Path _portraitPath(Size size) {
  final double w = size.width;
  final double h = size.height;
  final double radius = math.min(w, h) * 0.055;
  final double notch = math.min(w, h) * 0.17;

  return Path()
    ..moveTo(notch, 0)
    ..lineTo(w - radius, 0)
    ..quadraticBezierTo(w, 0, w, radius)
    ..lineTo(w, h - radius)
    ..quadraticBezierTo(w, h, w - radius, h)
    ..lineTo(radius, h)
    ..quadraticBezierTo(0, h, 0, h - radius)
    ..lineTo(0, notch)
    ..close();
}

/// Pré-carrega fotos das atletas em background, antes do usuário abrir um
/// chip em quadra. Reaproveita o mesmo cache estático de
/// [_PortraitFrameState], então uma vez que uma URL passa por aqui a
/// próxima montagem do chip aparece com a foto imediatamente.
abstract class PlayerPhotoPrecache {
  /// Baixa, decodifica e roda o crop facial de uma única URL. Idempotente.
  static Future<void> precache(String url) async {
    if (url.trim().isEmpty) return;
    await _PortraitFrameState._futureFor(url);
  }

  /// Pre-carrega URLs em lotes de [concurrency] paralelos (default 6),
  /// aguardando cada lote terminar antes do próximo. Evita tempestade de
  /// requests no Drive e pressão de memória ao decodificar 20+ imagens de
  /// uma vez em tablets modestos.
  static Future<void> precacheAll(
    Iterable<String?> urls, {
    int concurrency = 6,
  }) async {
    final List<String> filtered = urls
        .whereType<String>()
        .map((String u) => u.trim())
        .where((String u) => u.isNotEmpty)
        .toSet()
        .toList(growable: false);
    for (int i = 0; i < filtered.length; i += concurrency) {
      final Iterable<String> batch = filtered.skip(i).take(concurrency);
      await Future.wait(batch.map(precache));
    }
  }
}
