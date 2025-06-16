import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

class Movie {
  final int id;
  final String title;
  final String overview;
  final String posterPath;
  final double voteAverage;
  final List<int> genreIds;
  final String releaseDate;

  Movie({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.voteAverage,
    required this.genreIds,
    required this.releaseDate,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'],
      title: json['title'],
      overview: json['overview'],
      posterPath: json['poster_path'] ?? '',
      voteAverage: (json['vote_average'] as num).toDouble(),
      genreIds: List<int>.from(json['genre_ids'] ?? []),
      releaseDate: json['release_date'] ?? '',
    );
  }
}

class MovieProvider with ChangeNotifier {
  final Dio _dio = Dio();
  final String _baseUrl = 'https://api.themoviedb.org/3';
  final String _apiKey = 'e8ad42d7';
  
  List<Movie> _movies = [];
  List<Movie> _wishlist = [];
  bool _isLoading = false;
  String? _error;

  List<Movie> get movies => _movies;
  List<Movie> get wishlist => _wishlist;
  bool get isLoading => _isLoading;
  String? get error => _error;

  MovieProvider() {
    _dio.options.headers['Authorization'] = 'Bearer $_apiKey';
  }

  Future<void> searchMovies(String query) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      final response = await _dio.get(
        '$_baseUrl/search/movie',
        queryParameters: {
          'query': query,
          'language': 'ru-RU',
        },
      );
      _movies = (response.data['results'] as List)
          .map((movie) => Movie.fromJson(movie))
          .toList();
    } catch (e) {
      _error = 'Failed to load movies: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> getPopularMovies() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      final response = await _dio.get(
        '$_baseUrl/movie/popular',
        queryParameters: {
          'language': 'ru-RU',
        },
      );
      _movies = (response.data['results'] as List)
          .map((movie) => Movie.fromJson(movie))
          .toList();
    } catch (e) {
      _error = 'Failed to load popular movies: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void addToWishlist(Movie movie) {
    if (!_wishlist.any((m) => m.id == movie.id)) {
      _wishlist.add(movie);
      notifyListeners();
    }
  }

  void removeFromWishlist(Movie movie) {
    _wishlist.removeWhere((m) => m.id == movie.id);
    notifyListeners();
  }

  bool isInWishlist(Movie movie) {
    return _wishlist.any((m) => m.id == movie.id);
  }
} 