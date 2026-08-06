import 'package:flutter/widgets.dart';

/// Observador global de navegação, registrado no `MaterialApp`.
///
/// Permite que a tela inicial (raiz da pilha, criada uma vez só) saiba
/// quando o usuário VOLTOU até ela — é o gatilho da re-checagem de
/// atualização do app: sem isso, uma release publicada com o app aberto
/// só apareceria após fechar e reabrir o aplicativo.
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
