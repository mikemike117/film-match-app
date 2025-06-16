import 'package:film_match_backend/backend/server.dart'; // Корректный импорт BackendServer

void main() async {
  final server = BackendServer();
  await server.start();
} 