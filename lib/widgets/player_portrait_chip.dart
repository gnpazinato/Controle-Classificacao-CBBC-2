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
    final double chipHeight = maxHeight.clamp(46.0, 96.0).toDouble();
    final double chipWidth = math.min(maxWidth, chipHeight * 0.84);
    final double badgeSize =
        (chipHeight * 0.24).clamp(16.0, 24.0).toDouble();
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
                child: _PortraitFrame(
                  photoUrl: photoUrl,
                  initials: _initials(player.fullName),
                ),
              ),
              Positioned(
                left: -badgeSize * 0.18,
                top: chipHeight * 0.18,
                child: _MetricBadge(
                  text: player.playerClass?.toStringAsFixed(1) ?? '—',
                  size: badgeSize,
                  backgroundColor: Colors.white,
                  foregroundColor: CbbcColors.textPrimary,
                  borderColor: CbbcColors.slate200,
                ),
              ),
              Positioned(
                right: -badgeSize * 0.14,
                bottom: chipHeight * 0.12,
                child: _MetricBadge(
                  text: player.shirtNumber.toString(),
                  size: badgeSize,
                  backgroundColor: jerseyColor.fill,
                  foregroundColor: jerseyColor.numberColor,
                  borderColor: jerseyColor.numberColor.withValues(alpha: 0.65),
                ),
              ),
              if (isBonusEligible)
                Positioned(
                  right: -badgeSize * 0.08,
                  top: -badgeSize * 0.10,
                  child: Container(
                    width: badgeSize * 0.88,
                    height: badgeSize * 0.88,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: CbbcColors.orange, width: 1),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.star,
                      size: badgeSize * 0.58,
                      color: CbbcColors.orange,
                    ),
                  ),
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

  static String _initials(String name) {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return _firstLetter(parts.first).toUpperCase();
    return '${_firstLetter(parts.first)}${_firstLetter(parts.last)}'
        .toUpperCase();
  }

  static String _firstLetter(String value) {
    if (value.isEmpty) return '?';
    return String.fromCharCode(value.runes.first);
  }
}

class _PortraitFrame extends StatefulWidget {
  const _PortraitFrame({required this.photoUrl, required this.initials});

  final String? photoUrl;
  final String initials;

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
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: ClipPath(
          clipper: _PortraitClipper(),
          child: future == null
              ? _PortraitFallback(initials: widget.initials)
              : FutureBuilder<_PortraitPhoto?>(
                  future: future,
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<_PortraitPhoto?> snapshot,
                  ) {
                    final _PortraitPhoto? photo = snapshot.data;
                    if (photo == null) {
                      return _PortraitFallback(initials: widget.initials);
                    }
                    return CustomPaint(
                      painter: _PortraitPhotoPainter(photo),
                      child: const SizedBox.expand(),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _PortraitFallback extends StatelessWidget {
  const _PortraitFallback({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: CbbcColors.slate100,
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: CbbcColors.blueDeep,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  const _MetricBadge({
    required this.text,
    required this.size,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
  });

  final String text;
  final double size;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(size * 0.16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.08),
          child: Text(
            text,
            style: TextStyle(
              color: foregroundColor,
              fontSize: size * 0.50,
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
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.26), 4, false);

    final Paint fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(path, fill);

    final Paint stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..isAntiAlias = true;
    canvas.drawPath(path, stroke);
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
