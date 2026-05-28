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
  });

  final Player player;
  final JerseyColor jerseyColor;
  final bool isBonusEligible;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final double chipHeight = maxHeight.clamp(52.0, 108.0).toDouble();
    final double chipWidth = math.min(maxWidth, chipHeight * 0.84);

    final double classBadgeSize =
        (chipHeight * 0.30).clamp(22.0, 32.0).toDouble();
    final double jerseyBadgeSize =
        (chipHeight * 0.28).clamp(20.0, 30.0).toDouble();
    final String? photoUrl = player.photoUrl;

    return SizedBox(
      width: maxWidth,
      height: maxHeight,
      child: Center(
        child: Semantics(
          label: _semanticLabel,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              SizedBox(
                width: chipWidth,
                height: chipHeight,
                child: _PortraitFrame(photoUrl: photoUrl),
              ),
              Positioned(
                left: -classBadgeSize * 0.55,
                top: chipHeight * 0.18,
                child: _ClassBadge(
                  text: player.playerClass?.toStringAsFixed(1) ?? '—',
                  size: classBadgeSize,
                ),
              ),
              Positioned(
                right: -jerseyBadgeSize * 0.14,
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
          ),
        ),
      ),
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

  Future<_PortraitPhoto?>? _future;

  @override
  void initState() {
    super.initState();
    _future = _futureFor(widget.photoUrl);
  }

  @override
  void didUpdateWidget(_PortraitFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) {
      _future = _futureFor(widget.photoUrl);
    }
  }

  Future<_PortraitPhoto?>? _futureFor(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    return _cache.putIfAbsent(url, () => _load(url));
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

  static Future<Rect> _computeSourceRect(ui.Image image) async {
    final int width = image.width;
    final int height = image.height;
    final ByteData? raw =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (raw == null) {
      return Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    }

    final Uint8List pixels = raw.buffer.asUint8List(
      raw.offsetInBytes,
      raw.lengthInBytes,
    );
    final int step = math.max(1, math.min(width, height) ~/ 360);
    final List<int> xs = <int>[];
    final List<int> ys = <int>[];

    for (int y = 0; y < height; y += step) {
      for (int x = 0; x < width; x += step) {
        final int idx = (y * width + x) * 4;
        final int r = pixels[idx];
        final int g = pixels[idx + 1];
        final int b = pixels[idx + 2];
        final int maxChannel = math.max(r, math.max(g, b));
        final int minChannel = math.min(r, math.min(g, b));
        final int saturation = maxChannel - minChannel;

        if (saturation > 22 || maxChannel < 205) {
          xs.add(x);
          ys.add(y);
        }
      }
    }

    if (xs.length < 24 || ys.length < 24) {
      return _centerCrop(width, height);
    }

    xs.sort();
    ys.sort();
    final double left = _quantile(xs, 0.01).toDouble();
    final double top = _quantile(ys, 0.01).toDouble();
    final double right = _quantile(xs, 0.99).toDouble();
    final double bottom = _quantile(ys, 0.995).toDouble();
    final double subjectHeight = math.max(1.0, bottom - top);
    final double subjectWidth = math.max(1.0, right - left);
    final double subjectRatio = subjectHeight / height;

    double cropHeight = subjectHeight * (subjectRatio > 0.66 ? 0.38 : 0.45);
    cropHeight = cropHeight.clamp(height * 0.25, height * 0.46).toDouble();
    final double cropWidth = cropHeight * 0.82;
    final double subjectCenterX = left + subjectWidth / 2;
    final double centerX = subjectCenterX * 0.80 + (width / 2) * 0.20;

    double cropLeft = centerX - cropWidth / 2;
    double cropTop = top - cropHeight * 0.075;
    cropLeft =
        cropLeft.clamp(0.0, math.max(0.0, width - cropWidth)).toDouble();
    cropTop =
        cropTop.clamp(0.0, math.max(0.0, height - cropHeight)).toDouble();

    return Rect.fromLTWH(cropLeft, cropTop, cropWidth, cropHeight);
  }

  static Rect _centerCrop(int width, int height) {
    final double cropHeight = (height * 0.42).clamp(1.0, height).toDouble();
    final double cropWidth =
        (cropHeight * 0.82).clamp(1.0, width).toDouble();
    final double left = math.max(0.0, (width - cropWidth) / 2);
    return Rect.fromLTWH(left, 0, cropWidth, cropHeight);
  }

  static int _quantile(List<int> values, double percentile) {
    final int rawIdx = (values.length * percentile).floor();
    final int idx = rawIdx < 0
        ? 0
        : (rawIdx >= values.length ? values.length - 1 : rawIdx);
    return values[idx];
  }

  @override
  Widget build(BuildContext context) {
    final Future<_PortraitPhoto?>? future = _future;
    return CustomPaint(
      painter: _PortraitFramePainter(),
      child: ClipPath(
        clipper: _PortraitClipper(),
        child: future == null
            ? const _PortraitFallback()
            : FutureBuilder<_PortraitPhoto?>(
                // Key por URL evita o flash da foto da atleta anterior quando
                // o slot recebe uma jogadora diferente — força o FutureBuilder
                // a recriar seu State (snapshot.data zera) em vez de reusar
                // o dado do future antigo durante o frame de transição.
                key: ValueKey<String?>(widget.photoUrl),
                future: future,
                builder: (
                  BuildContext context,
                  AsyncSnapshot<_PortraitPhoto?> snapshot,
                ) {
                  final _PortraitPhoto? photo = snapshot.data;
                  if (photo == null) {
                    return const _PortraitFallback();
                  }
                  return CustomPaint(
                    painter: _PortraitPhotoPainter(photo),
                    child: const SizedBox.expand(),
                  );
                },
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
  const _ClassBadge({required this.text, required this.size});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 1.15,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Colors.white, Color(0xFFF1F5F9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(size * 0.20),
          topRight: Radius.circular(size * 0.20),
          bottomRight: Radius.circular(size * 0.20),
          bottomLeft: Radius.zero,
        ),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 0,
            top: size * 0.18,
            bottom: size * 0.18,
            child: Container(
              width: 2.2,
              decoration: const BoxDecoration(
                color: CbbcColors.blue,
                borderRadius:
                    BorderRadius.horizontal(right: Radius.circular(1)),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.only(left: size * 0.08),
              child: Text(
                text,
                style: TextStyle(
                  color: CbbcColors.textPrimary,
                  fontSize: size * 0.46,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
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
