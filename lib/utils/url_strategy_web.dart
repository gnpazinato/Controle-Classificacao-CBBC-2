import 'package:flutter_web_plugins/url_strategy.dart';

/// Na web, usa o roteamento por path (`/v/abc`) em vez do hash (`/#/v/abc`),
/// deixando o link público mais limpo no QR code e na barra de endereço.
void configureUrlStrategy() => usePathUrlStrategy();
