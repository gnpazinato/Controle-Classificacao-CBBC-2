import 'package:flutter/material.dart';

import '../theme/cbbc_theme.dart';

const String kCbbcLogoAsset = 'assets/images/cbbc-logo.png';

/// Cabeçalho institucional usado na home.
class CbbcBrandHeader extends StatelessWidget {
  const CbbcBrandHeader({
    super.key,
    this.title = 'Controle Classificação CBBC',
    this.subtitle,
    this.maxLogoHeight = 140,
  });

  final String title;
  final String? subtitle;
  final double maxLogoHeight;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext _, BoxConstraints c) {
            final double availableHeight =
                c.maxHeight.isFinite ? c.maxHeight : maxLogoHeight;
            final double height =
                availableHeight < maxLogoHeight ? availableHeight : maxLogoHeight;
            return SizedBox(
              key: const Key('cbbc-brand-logo'),
              height: height,
              child: Image.asset(
                kCbbcLogoAsset,
                fit: BoxFit.contain,
                semanticLabel: 'Logo CBBC',
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: CbbcColors.blueDeep,
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: CbbcColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// Título lado-a-lado (logo branco à esquerda, texto da tela à direita)
/// usado nas `AppBar`s azuis das telas internas. O logo é tintado de
/// branco via `ColorFilter` pra ficar legível sobre o fundo azul cobalto.
class CbbcAppBarTitle extends StatelessWidget {
  const CbbcAppBarTitle({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        SizedBox(
          key: const Key('cbbc-appbar-logo'),
          height: 56,
          width: 56,
          child: ColorFiltered(
            colorFilter: const ColorFilter.mode(
              Colors.white,
              BlendMode.srcIn,
            ),
            child: Image.asset(
              kCbbcLogoAsset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              semanticLabel: 'Logo CBBC',
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
