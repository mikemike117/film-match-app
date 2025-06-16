import 'package:flutter/material.dart';
import 'package:film_match_app/screens/home_screen.dart';
import 'package:film_match_app/screens/login_screen.dart';
import 'package:film_match_app/screens/wishlist_screen.dart';
import 'package:film_match_app/screens/movie_details_screen.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  void navigateToLogin() {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  void navigateToHome() {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  void navigateToWishlist() {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (context) => const WishlistScreen()),
    );
  }

  void navigateToMovieDetails(String movieId) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => MovieDetailsScreen(movieId: movieId),
      ),
    );
  }
} 