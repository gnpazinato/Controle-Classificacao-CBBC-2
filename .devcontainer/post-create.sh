#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.32.0}"
FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter}"

# Em imagens Alpine (musl), o Dart SDK (glibc) só executa com a camada
# de compatibilidade gcompat — sem ela, `flutter` falha com
# "cannot execute: required file not found".
# Mesmo com gcompat, testes de widget que montam MaterialApp podem
# estourar a pilha (thread musl é pequena e o VM do Dart herda o limite).
# O suite completo roda no CI (ubuntu), que é o ambiente de referência.
if [ -f /etc/alpine-release ]; then
  echo "Alpine detectado — instalando gcompat/libstdc++ pro Dart SDK..."
  sudo apk add --no-cache gcompat libstdc++
fi

if [ ! -d "$FLUTTER_HOME" ]; then
  echo "Baixando Flutter $FLUTTER_VERSION..."
  curl -fSL -o /tmp/flutter.tar.xz \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  tar -xf /tmp/flutter.tar.xz -C "$(dirname "$FLUTTER_HOME")"
  rm /tmp/flutter.tar.xz
fi

export PATH="$FLUTTER_HOME/bin:$PATH"
git config --global --add safe.directory "$FLUTTER_HOME"
flutter --disable-analytics
flutter config --no-analytics

echo "Gerando arquivos Android/Web do projeto..."
flutter create . \
  --project-name controle_classificacao_cbbc \
  --org br.org.cbbc \
  --platforms=android,web \
  --description "Controle de Classificação CBBC"

flutter pub get

echo ""
echo "Tudo pronto. Para rodar a versão Web:"
echo "  flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0"
echo "Codespaces vai abrir a porta 8080 automaticamente."
