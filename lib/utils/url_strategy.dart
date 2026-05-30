// Configura URLs "limpas" (`/v/abc`) no Flutter Web, sem o `#`. Em Android
// e outras plataformas é um no-op — resolvido por importação condicional.
export 'url_strategy_noop.dart'
    if (dart.library.js_interop) 'url_strategy_web.dart';
