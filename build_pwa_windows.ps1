$ErrorActionPreference = "Stop"

Write-Host "BusControl PRO PWA: проверка Flutter..."
flutter --version

Write-Host "Включение Web..."
flutter config --enable-web

Write-Host "Получение зависимостей..."
flutter pub get

Write-Host "Установка SQLite Web runtime..."
dart run sqflite_common_ffi_web:setup --force

Write-Host "Проверка исходников..."
flutter analyze

Write-Host "Сборка PWA..."
flutter build web --release

Write-Host ""
Write-Host "Готово. Файлы находятся в build\web"
Write-Host "Локальная проверка:"
Write-Host "python -m http.server 8080 --directory build\web"
