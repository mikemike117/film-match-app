import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:film_match_app/providers/auth_provider.dart';
import 'package:film_match_app/providers/movie_provider.dart';
import 'package:film_match_app/screens/home_screen.dart';
import 'package:film_match_app/screens/login_screen.dart';
import 'package:film_match_app/services/deep_link_service.dart';
import 'package:film_match_app/services/navigation_service.dart';
import 'package:film_match_app/firebase_options.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Инициализация сервисов
  final navigationService = NavigationService();
  DeepLinkService? deepLinkService; // Сделаем null-able

  if (!kIsWeb) {
    // Инициализируем DeepLinkService только для не-веб платформ
    deepLinkService = DeepLinkService(navigationService);
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MovieProvider()),
      ],
      child: MaterialApp(
        navigatorKey: NavigationService().navigatorKey,
        title: 'FilmMatch',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            return StreamBuilder(
              stream: authProvider.authStateChanges,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasData) {
                  return const HomeScreen();
                }
                return const LoginScreen();
              },
            );
          },
        ),
      ),
    );
  }
}
