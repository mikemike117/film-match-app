import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
// Условный импорт uni_links: импортируем только если это не веб-платформа
import 'package:uni_links/uni_links.dart' if (dart.library.js) 'package:film_match_app/services/stub_uni_links.dart';
import 'package:film_match_app/services/navigation_service.dart';

// Создаем заглушку для uni_links на вебе, чтобы избежать ошибки компиляции
// Этот файл будет создан ниже

class DeepLinkService {
  StreamSubscription? _sub;
  final NavigationService _navigationService;

  DeepLinkService(this._navigationService) {
    // Инициализируем потоки только на не-веб платформах.
    // На вебе начальный URI обрабатывается напрямую в main.dart.
    if (!kIsWeb) {
      _initLinkStream();
      _initInitialLink();
    }
  }

  // Слушает входящие URI-ссылки, пока приложение работает.
  void _initLinkStream() {
    _sub = uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    }, onError: (err) {
      print('DeepLinkService: Stream error: $err');
    });
  }

  // Обрабатывает начальную URI-ссылку при первом запуске приложения.
  Future<void> _initInitialLink() async {
    try {
      final initialUri = await getInitialUri();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      print('DeepLinkService: Error getting initial URI: $e');
    }
  }

  void _handleDeepLink(Uri uri) {
    if (uri.pathSegments.isNotEmpty) {
      final path = uri.pathSegments[0];
      if (path == 'movie' && uri.pathSegments.length > 1) {
        final movieId = uri.pathSegments[1];
        _navigationService.navigateToMovieDetails(movieId);
      }
    }
  }

  void dispose() {
    _sub?.cancel();
  }
} 