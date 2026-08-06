# BusControl PRO 2.0.2 — запуск

1. Убедитесь, что через Android Studio SDK Manager установлен Android SDK Platform 36.
2. Откройте именно папку, где находится `pubspec.yaml`.
3. В терминале выполните:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run -d emulator-5554
```

Если Android Studio продолжает показывать старые ошибки после `flutter pub get`:

- File → Invalidate Caches… → Invalidate and Restart
- либо перезапустите Dart Analysis Server.

Исправления этой версии:

- `compileSdk = 36`;
- `file_picker` обновлён до `10.3.11`, чтобы Android-плагин не компилировался с API 34;
- удалён старый `pubspec.lock`, чтобы зависимости разрешились заново;
- добавлен явный импорт `cross_file` для `XFile`.
