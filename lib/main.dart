import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/load_spreadsheet_screen.dart';
import 'screens/public_viewer_screen.dart';
import 'screens/splash_screen.dart';
import 'services/wakelock_controller.dart';
import 'theme/cbbc_theme.dart';
import 'utils/app_route_observer.dart';
import 'utils/url_strategy.dart';
import 'widgets/battery_warning_banner.dart';

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
      // Aviso de bateria baixa por cima de TODAS as telas (o app roda em
      // modo imersivo e esconde o indicador do próprio Android).
      builder: (BuildContext context, Widget? child) =>
          BatteryWarningOverlay(child: child ?? const SizedBox.shrink()),
      // Notifica a tela inicial quando o usuário volta até ela (gatilho
      // da re-checagem de atualização do app).
      navigatorObservers: <NavigatorObserver>[appRouteObserver],
      // A rota inicial é resolvida por onGenerateInitialRoutes (importante na
      // web): `/v/<codigo>` abre SÓ o viewer público — sem empilhar a home
      // (Splash) atrás, senão o timer do Splash trocaria o viewer pela tela
      // inicial. Qualquer outra rota inicial abre a home normalmente.
      onGenerateInitialRoutes: (String initialRoute) =>
          <Route<void>>[_routeFor(initialRoute, home)],
      onGenerateRoute: (RouteSettings settings) =>
          _routeFor(settings.name ?? '/', home),
    );
  }

  /// Decide a rota a partir do nome: `/v/<codigo>` → viewer público;
  /// qualquer outra → [home].
  Route<void> _routeFor(String name, Widget home) {
    final Uri uri = Uri.parse(name);
    if (uri.pathSegments.length == 2 && uri.pathSegments.first == 'v') {
      final String code = uri.pathSegments[1];
      return MaterialPageRoute<void>(
        settings: RouteSettings(name: name),
        builder: (BuildContext _) => PublicViewerScreen(code: code),
      );
    }
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: name),
      builder: (BuildContext _) => home,
    );
  }
}
