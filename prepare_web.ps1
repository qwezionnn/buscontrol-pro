$ErrorActionPreference = "Stop"

Write-Host "1/4 Получение зависимостей..."
flutter pub get

Write-Host "2/4 Установка SQLite Web (IndexedDB)..."
dart run sqflite_common_ffi_web:setup --force

Write-Host "3/4 Проверка проекта..."
flutter analyze

Write-Host "4/4 Сборка PWA..."
flutter build web --release

Write-Host ""
Write-Host "Готово: build\web"
Write-Host "Для локальной проверки:"
Write-Host "  python -m http.server 8080 --directory build\web"
