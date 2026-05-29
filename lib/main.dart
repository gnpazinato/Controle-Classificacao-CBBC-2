import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/load_spreadsheet_screen.dart';
import 'screens/public_viewer_screen.dart';
import 'screens/splash_screen.dart';
import 'services/wakelock_controller.dart';
import 'theme/cbbc_theme.dart';
import 'utils/url_strategy.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // URLs limpas na web (/v/abc em vez de /#/v/abc). No-op no Android.
  configureUrlStrategy();
  // Fullscreen "modo vídeo": esconde barras de sistema (status e
  // navegação). Swipe da borda traz as barras de volta temporariamente
  // e elas voltam a sumir após alguns segundos.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // Sem trava de orientação: tablet/celular giram livremente entre
  // retrato e paisagem. Em telas largas as informações ficam mais
  // organizadas (nomes longos não cortam) — manter as duas opções
  // abertas.
  // Tela sempre acesa enquanto o app estiver em primeiro plano.
  // wakelock_plus libera automaticamente quando o app vai para o
  // background e re-ativa no resume.
  unawaited(const WakelockController().enable());
  runApp(const CbbcApp());
}

class CbbcApp extends StatelessWidget {
  const CbbcApp({super.key, this.splashDuration});

  /// Duração do splash. `null` usa o padrão de produção (~2.5s).
  /// Em testes pode ser passado `Duration.zero` para pular o splash.
  final Duration? splashDuration;

  @override
  Widget build(BuildContext context) {
    final Widget home = splashDuration == Duration.zero
        ? const LoadSpreadsheetScreen()
        : SplashScreen(
            duration: splashDuration ?? const Duration(milliseconds: 2500),
          );
    return MaterialApp(
      title: 'Controle Classificação CBBC',
      debugShowCheckedModeBanner: false,
      theme: buildCbbcTheme(),
      // Fluxo normal inalterado: `/` → home. Na web, `/v/<codigo>` abre o
      // viewer público da transmissão, isolado do resto do app. Para
      // qualquer outra rota, devolve `null` e o `home` assume.
      home: home,
      onGenerateRoute: (RouteSettings settings) {
        final Uri uri = Uri.parse(settings.name ?? '/');
        if (uri.pathSegments.length == 2 && uri.pathSegments.first == 'v') {
          final String code = uri.pathSegments[1];
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (BuildContext _) => PublicViewerScreen(code: code),
          );
        }
        return null;
      },
    );
  }
}
