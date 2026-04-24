#!/usr/bin/env bash
set -e

git clone https://github.com/flutter/flutter.git -b stable "$HOME/flutter"

export PATH="$HOME/flutter/bin:$PATH"

flutter config --enable-web
flutter pub get
flutter build web --release