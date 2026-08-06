# BusControl PRO 3.1 — iPhone polish

Добавлено:

- название BusControl PRO для iOS и Android;
- собственная иконка приложения;
- фирменный Splash Screen;
- светлая и полноценная тёмная темы;
- iOS-анимации переходов между экранами;
- плавная анимация переключения основных вкладок;
- iOS bounce-прокрутка;
- Cupertino-оформление диалогов на iPhone;
- Haptic Feedback при переключении вкладок и транспорта;
- портретная ориентация;
- Safe Area для выреза и Dynamic Island;
- ограничение масштаба текста, чтобы карточки не переполнялись.

## Важно про Dynamic Island

Приложение корректно учитывает безопасную область iPhone с Dynamic Island.
Live Activities внутри Dynamic Island пока не добавлены: для них потребуется
отдельный нативный Widget Extension в Xcode и macOS.

## Проверка Android

```powershell
flutter clean
flutter pub get
flutter analyze
flutter run -d emulator-5554
```

## Проверка iPhone на Mac

```bash
flutter clean
flutter pub get
cd ios
pod install
cd ..
flutter run
```

Открывать в Xcode нужно файл:

`ios/Runner.xcworkspace`
