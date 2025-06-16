import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'database_service.dart';
import 'dart:convert';
import 'package:firebase_admin/firebase_admin.dart';
import 'package:firebase_admin/auth.dart';

class BackendServer {
  final DatabaseService _dbService = DatabaseService();
  late final Router _router;
  late final DbCollection _openedLogsCollection; // Добавляем коллекцию для открытых логов

  BackendServer() {
    // Initialize Firebase Admin SDK
    FirebaseAdmin.instance.initializeApp(AppOptions(
      credential: ApplicationDefaultCredential.fromPath('D:\\\\project_dart\\\\dart_movies\\\\film_match_backend\\\\service_account_key.json'), // Ваш путь к ключу сервисного аккаунта
    ));

    _router = Router()
      ..get('/health', _healthCheck)
      // Protected routes
      ..get('/wishlist/<userId>', _getWishlist)
      ..post('/wishlist/<userId>', _addToWishlist)
      ..delete('/wishlist/<userId>/<movieId>', _removeFromWishlist)
      ..post('/skipped/<userId>', _skipMovie)
      ..delete('/skipped/<userId>/<movieId>', _undoSkipMovie)
      ..delete('/skipped/<userId>/all', _undoAllSkippedMovies)
      // Opened logs routes - теперь внутри _router
      ..get('/api/opened-logs/stats', _getOpenedLogsStats)
      ..post('/api/opened-logs', _markLogAsOpened)
      ..get('/api/opened-logs', _getOpenedLogs);
  }

  // Middleware для верификации Firebase ID Token
  Future<Response> _authMiddleware(Request request) async {
    // Исключаем /health из аутентификации
    if (request.url.pathSegments.isNotEmpty && request.url.pathSegments.first == 'health') {
      return await _router(request);
    }

    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response.forbidden('No authorization token provided.');
    }

    final idToken = authHeader.substring(7); // Убираем префикс 'Bearer '

    try {
      final decodedToken = await FirebaseAuth.instance.verifyIdToken(idToken);
      final userId = decodedToken.uid;
      // Прикрепляем проверенный userId к контексту запроса
      final newRequest = request.change(context: {'userId': userId});
      return await _router(newRequest);
    } on FirebaseAuthException catch (e) {
      return Response.forbidden('Invalid or expired token: ${e.message}');
    } catch (e) {
      return Response.internalServerError(body: 'Authentication error: $e');
    }
  }

  Future<void> start() async {
    // Подключаемся к базе данных
    await _dbService.connect();
    _openedLogsCollection = _dbService.getCollection('opened_logs'); // Инициализируем коллекцию
    await _openedLogsCollection.createIndex(keys: {'userId': 1, 'logId': 1}, unique: true); // Создаем индекс

    // Создаем конвейер обработчиков с middleware аутентификации
    final handler = Pipeline()
        .addMiddleware(logRequests())
        .addHandler(_authMiddleware); // Применяем middleware аутентификации первым

    // Запускаем сервер
    final server = await shelf_io.serve(
      handler,
      InternetAddress.anyIPv4,
      8080,
    );

    print('Server running on port ${server.port}');
  }

  // Обработчики маршрутов (теперь ожидаем userId из контекста запроса)
  Response _healthCheck(Request request) {
    return Response.ok('Server is running!');
  }

  Future<Response> _getWishlist(Request request) async {
    final userId = request.context['userId'] as String?;
    if (userId == null) {
      return Response.badRequest(body: 'User ID not found in context.');
    }

    try {
      final wishlistDoc = await _dbService.getCollection('wishlists').findOne(
        where.eq('userId', userId),
      );

      if (wishlistDoc == null) {
        return Response.ok(
          json.encode({'userId': userId, 'movieIds': [], 'skippedMovieIds': []}),
          headers: {'content-type': 'application/json'},
        );
      }

      final List<dynamic> movieIds = wishlistDoc['movieIds'] ?? [];
      final List<dynamic> skippedMovieIds = wishlistDoc['skippedMovieIds'] ?? [];

      print('Backend: Sending wishlist data for user $userId: movieIds = $movieIds, skippedMovieIds = $skippedMovieIds');
      return Response.ok(
        json.encode({'userId': userId, 'movieIds': movieIds, 'skippedMovieIds': skippedMovieIds}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: e.toString());
    }
  }

  Future<Response> _addToWishlist(Request request) async {
    final userId = request.context['userId'] as String?;
    if (userId == null) {
      return Response.badRequest(body: 'User ID not found in context.');
    }

    try {
      final body = await request.readAsString();
      final movieData = json.decode(body) as Map<String, dynamic>;

      final result = await _dbService.getCollection('wishlists').updateOne(
        where.eq('userId', userId),
        modify.addToSet('movieIds', movieData), // Store full movie object
        upsert: true,
      );

      return Response.ok(
        result.toString(),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      print('Error adding movie to wishlist: $e');
      return Response.internalServerError(body: e.toString());
    }
  }

  Future<Response> _removeFromWishlist(Request request) async {
    final userId = request.context['userId'] as String?;
    if (userId == null) {
      return Response.badRequest(body: 'User ID not found in context.');
    }

    final movieId = request.params['movieId'];
    if (movieId == null) {
      return Response.badRequest(body: 'Movie ID is required.');
    }

    try {
      final result = await _dbService.getCollection('wishlists').updateOne(
        where.eq('userId', userId),
        modify.pull('movieIds', {'id': movieId}), // Pull by movie ID within the object
      );

      return Response.ok(
        result.toString(),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      print('Error removing movie from wishlist: $e');
      return Response.internalServerError(body: e.toString());
    }
  }

  Future<Response> _skipMovie(Request request) async {
    final userId = request.context['userId'] as String?;
    if (userId == null) {
      return Response.badRequest(body: 'User ID not found in context.');
    }

    try {
      final body = await request.readAsString();
      final movieData = json.decode(body) as Map<String, dynamic>;

      final result = await _dbService.getCollection('wishlists').updateOne(
        where.eq('userId', userId),
        modify.addToSet('skippedMovieIds', movieData), // Store full movie object
        upsert: true,
      );

      return Response.ok(
        json.encode({'message': 'Movie skipped and saved'}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      print('Error skipping movie: $e');
      return Response.internalServerError(body: e.toString());
    }
  }

  Future<Response> _undoSkipMovie(Request request) async {
    final userId = request.context['userId'] as String?;
    if (userId == null) {
      return Response.badRequest(body: 'User ID not found in context.');
    }

    final movieId = request.params['movieId'];
    if (movieId == null) {
      return Response.badRequest(body: 'Movie ID is required.');
    }

    try {
      final result = await _dbService.getCollection('wishlists').updateOne(
        where.eq('userId', userId),
        modify.pull('skippedMovieIds', {'id': movieId}), // Pull by movie ID within the object
      );

      return Response.ok(
        json.encode({'message': 'Skipped movie undone'}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      print('Error undoing skipped movie: $e');
      return Response.internalServerError(body: e.toString());
    }
  }

  Future<Response> _undoAllSkippedMovies(Request request) async {
    final userId = request.context['userId'] as String?;
    if (userId == null) {
      return Response.badRequest(body: 'User ID not found in context.');
    }

    try {
      final result = await _dbService.getCollection('wishlists').updateOne(
        where.eq('userId', userId),
        modify.set('skippedMovieIds', []), // Clear the skippedMovieIds array
      );

      return Response.ok(
        json.encode({'message': 'All skipped movies undone'}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      print('Error undoing all skipped movies: $e');
      return Response.internalServerError(body: e.toString());
    }
  }

  // Новые обработчики для открытых логов
  Future<Response> _getOpenedLogsStats(Request request) async {
    final userId = request.context['userId'] as String?;
    if (userId == null) {
      return Response.badRequest(body: 'User ID not found in context.');
    }
    try {
      final stats = await _openedLogsCollection.aggregate([
        {
          '\$match': {'userId': userId}
        },
        {
          '\$group': {
            '_id': null,
            'totalOpened': {'\$sum': 1},
            'lastOpened': {'\$max': '\$openedAt'}
          }
        }
      ]).toList();

      return Response.ok(
        json.encode({
          'totalOpened': stats.isEmpty ? 0 : stats[0]['totalOpened'],
          'lastOpened': stats.isEmpty ? null : stats[0]['lastOpened']?.toIso8601String() // Convert DateTime to String
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: e.toString());
    }
  }

  Future<Response> _markLogAsOpened(Request request) async {
    final userId = request.context['userId'] as String?;
    if (userId == null) {
      return Response.badRequest(body: 'User ID not found in context.');
    }
    try {
      final body = await request.readAsString();
      final data = json.decode(body) as Map<String, dynamic>;
      final logId = data['logId'] as String;

      await _openedLogsCollection.updateOne(
        where.eq('userId', userId).eq('logId', logId),
        modify
          .set('userId', userId)
          .set('logId', logId)
          .set('openedAt', DateTime.now().toUtc()),
        upsert: true
      );

      return Response.ok(
        json.encode({'success': true}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: e.toString());
    }
  }

  Future<Response> _getOpenedLogs(Request request) async {
    final userId = request.context['userId'] as String?;
    if (userId == null) {
      return Response.badRequest(body: 'User ID not found in context.');
    }
    try {
      final openedLogs = await _openedLogsCollection
          .find(where.eq('userId', userId))
          .sort({'openedAt': -1})
          .toList();

      // Convert DateTime objects to ISO 8601 strings for JSON serialization
      final List<Map<String, dynamic>> serializableLogs = openedLogs.map((log) {
        return {
          ...log,
          'openedAt': (log['openedAt'] as DateTime).toIso8601String(),
        };
      }).toList();

      return Response.ok(
        json.encode(serializableLogs),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: e.toString());
    }
  }
} 