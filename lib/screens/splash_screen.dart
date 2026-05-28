import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/cbbc_theme.dart';
import '../widgets/cbbc_logo_header.dart';
import 'load_spreadsheet_screen.dart';

/// Splash inicial: logo CBBC sobre fundo branco por ~2.5s, transição em
/// fade para a tela de carregar planilha.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.duration = const Duration(milliseconds: 2500),
  });

  final Duration duration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Espera o primeiro frame antes de agendar a navegação — pushReplacement
    // dentro do mesmo microtask do initState quebra o build do Navigator.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _timer = Timer(widget.duration, _goHome);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const LoadSpreadsheetScreen(),
        transitionsBuilder: (_, Animation<double> anim, __, Widget child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              key: const Key('splash-content'),
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 320,
                    maxHeight: 320,
                  ),
                  child: Image.asset(
                    kCbbcLogoAsset,
                    fit: BoxFit.contain,
                    semanticLabel: 'Logo CBBC',
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'CONFEDERAÇÃO BRASILEIRA DE\nBASQUETEBOL EM CADEIRA DE RODAS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: CbbcColors.blueDeep,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 0.8,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
