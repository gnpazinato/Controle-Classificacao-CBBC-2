import 'dart:math' as math;
import 'dart:typed_data';
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
    final double classBadgeSize = chipHeight * 0.30;
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
          // Badge da classe levemente pra cima e mais pra esquerda — não
          // toca no rosto e abre espaço pro chip ao lado.
          left: -classBadgeSize * 0.70,
          top: chipHeight * 0.04,
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
  /// Estratégia:
  /// 1. Faz uma varredura pra encontrar pixels do sujeito (não-fundo).
  /// 2. Usa o topo do sujeito (onde fica o topo da cabeça) como âncora.
  /// 3. Estima a largura da cabeça medindo a faixa de pixels do sujeito
  ///    na região superior (até 25 % abaixo do topo).
  /// 4. Escala a altura do recorte por **~3 × largura da cabeça** — isso
  ///    corresponde, na prática, a "rosto + pescoço + ombros + barra do
  ///    decote". Como a largura da cabeça é uma medida proporcional ao
  ///    tamanho real do rosto no enquadramento original, fotos com zoom
  ///    diferente terminam recortadas no mesmo "tamanho aparente".
  /// 5. Garante uma altura mínima/máxima absoluta pra evitar crops
  ///    minúsculos quando a detecção falhar.
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

    bool isSubject(int x, int y) {
      final int idx = (y * width + x) * 4;
      final int r = pixels[idx];
      final int g = pixels[idx + 1];
      final int b = pixels[idx + 2];
      final int maxChannel = math.max(r, math.max(g, b));
      final int minChannel = math.min(r, math.min(g, b));
      final int saturation = maxChannel - minChannel;
      // Fundo: branco/claro com pouca saturação. Tudo o resto é sujeito.
      return saturation > 22 || maxChannel < 205;
    }

    final int step = math.max(1, math.min(width, height) ~/ 360);
    final int minRunPerRow = math.max(3, (width * 0.04) ~/ step);

    // 1. Topo do sujeito: primeira linha com uma sequência minimamente
    //    sólida de pixels do sujeito (filtra ruído isolado).
    int subjectTop = -1;
    int topRowLeft = 0;
    int topRowRight = width;
    for (int y = 0; y < height; y += step) {
      int run = 0;
      int firstX = -1;
      int lastX = -1;
      for (int x = 0; x < width; x += step) {
        if (isSubject(x, y)) {
          if (firstX == -1) firstX = x;
          lastX = x;
          run++;
        }
      }
      if (run >= minRunPerRow) {
        subjectTop = y;
        topRowLeft = firstX;
        topRowRight = lastX;
        break;
      }
    }

    if (subjectTop < 0) {
      return _centerCrop(width, height);
    }

    // 2. Largura da cabeça: usa a mediana da largura "do sujeito" nas
    //    linhas dentro dos primeiros 25 % abaixo do topo. Isso evita que
    //    ombros muito largos dominem a medida.
    final int headBandBottom = math.min(
      height,
      subjectTop + (height * 0.18).round(),
    );
    final List<int> widths = <int>[];
    final List<int> leftEdges = <int>[];
    final List<int> rightEdges = <int>[];
    for (int y = subjectTop; y < headBandBottom; y += step) {
      int firstX = -1;
      int lastX = -1;
      for (int x = 0; x < width; x += step) {
        if (isSubject(x, y)) {
          if (firstX == -1) firstX = x;
          lastX = x;
        }
      }
      if (firstX != -1 && lastX - firstX >= step) {
        widths.add(lastX - firstX);
        leftEdges.add(firstX);
        rightEdges.add(lastX);
      }
    }

    double headWidth;
    double headCenterX;
    if (widths.isEmpty) {
      headWidth = (topRowRight - topRowLeft).toDouble();
      headCenterX = (topRowLeft + topRowRight) / 2;
    } else {
      widths.sort();
      leftEdges.sort();
      rightEdges.sort();
      headWidth = widths[widths.length ~/ 2].toDouble();
      final int medianLeft = leftEdges[leftEdges.length ~/ 2];
      final int medianRight = rightEdges[rightEdges.length ~/ 2];
      headCenterX = (medianLeft + medianRight) / 2;
    }
    if (headWidth < 1) headWidth = width * 0.30;

    // 3. Recorte: altura ≈ 3 × largura da cabeça, gentil margem acima.
    //    O fator 3.0 vem da regra de ouro do enquadramento "rosto + ombros
    //    + um pouco da camiseta": numa foto bem enquadrada, esse trecho
    //    mede cerca de 3× a largura da cabeça.
    final double topMargin = headWidth * 0.20;
    double cropHeight = headWidth * 3.0;
    // Mínimo: pelo menos 38 % da altura da foto, pra evitar crops muito
    // apertados em fotos onde a cabeça acabou pequena. Máximo: 65 % da
    // altura, pra não pegar do quadril pra baixo.
    cropHeight = cropHeight.clamp(height * 0.38, height * 0.65).toDouble();
    final double cropWidth = (cropHeight * 0.82).clamp(1.0, width.toDouble());

    double cropTop = subjectTop - topMargin;
    double cropLeft = headCenterX - cropWidth / 2;
    cropTop =
        cropTop.clamp(0.0, math.max(0.0, height - cropHeight)).toDouble();
    cropLeft =
        cropLeft.clamp(0.0, math.max(0.0, width - cropWidth)).toDouble();

    return Rect.fromLTWH(cropLeft, cropTop, cropWidth, cropHeight);
  }

  static Rect _centerCrop(int width, int height) {
    final double cropHeight = (height * 0.50).clamp(1.0, height).toDouble();
    final double cropWidth =
        (cropHeight * 0.82).clamp(1.0, width).toDouble();
    final double left = math.max(0.0, (width - cropWidth) / 2);
    return Rect.fromLTWH(left, 0, cropWidth, cropHeight);
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
    // Mesma cor da camiseta + número na cor de leitura da camiseta. Sem
    // borda; só uma sombra suave pra destacar sobre a foto.
    return Container(
      width: size * 1.15,
      height: size,
      decoration: BoxDecoration(
        color: jerseyColor.fill,
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.12),
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
