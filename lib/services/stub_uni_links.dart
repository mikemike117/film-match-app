import 'dart:async';

// Заглушка для uni_links на веб-платформе
// Это необходимо, потому что uni_links.uriLinkStream не поддерживается на вебе

Future<Uri?> getInitialUri() async => null;
Stream<Uri?> get uriLinkStream => Stream.empty();

// Чтобы избежать ошибки 'Ambiguous import', также нужно заглушить getInitialLink
Future<String?> getInitialLink() async => null;
Stream<String?> get linkStream => Stream.empty(); 