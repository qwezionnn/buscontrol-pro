# BusControl PRO 3.0.1 — исправление запуска

Исправлено зависание на Flutter splash:

- открытие SQLite теперь защищено одним общим Future;
- параллельные обращения не запускают несколько openDatabase;
- batch.commit удалён из onCreate/onUpgrade;
- настройки создаются последовательными INSERT внутри транзакции sqflite;
- версия базы повышена до 7;
- foreign_keys включаются через onConfigure.

Запуск:

flutter clean
flutter pub get
flutter run -d emulator-5554
