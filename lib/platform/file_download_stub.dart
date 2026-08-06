import 'dart:typed_data';

Future<void> downloadBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) {
  throw UnsupportedError('Скачивание через браузер доступно только в Web.');
}
