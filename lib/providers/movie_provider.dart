import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Movie {
  final String id; // OMDb uses imdbID
  final String title;
  final String posterPath;
  final String year; // OMDb includes year in search results

  Movie({
    required this.id,
    required this.title,
    required this.posterPath,
    required this.year,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id']?.toString() ?? json['imdbID']?.toString() ?? '',
      title: json['title']?.toString() ?? json['Title']?.toString() ?? '',
      posterPath: json['posterPath'] ?? json['Poster'] ?? '',
      year: json['year']?.toString() ?? json['Year']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'posterPath': posterPath,
      'year': year,
    };
  }
}

class MovieProvider with ChangeNotifier {
  final Dio _dio = Dio();
  final String _baseUrl = 'https://www.omdbapi.com/'; // OMDb API Base URL
  final String _apiKey = 'b5748ebb'; // Replace with your OMDb API Key
  final String _backendUrl = 'http://localhost:8080';
  
  List<Movie> _movies = [];
  List<Movie> _wishlist = [];
  List<Movie> _skippedMovies = [];
  bool _isLoading = false;
  String? _error;
  String? _currentUserId;

  List<Movie> get movies => _movies;
  List<Movie> get wishlist => _wishlist;
  List<Movie> get skippedMovies => _skippedMovies;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<Map<String, String>> _getAuthHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated.');
    }
    final idToken = await user.getIdToken();
    return {'Authorization': 'Bearer $idToken'};
  }

  void setUserId(String? userId) {
    _currentUserId = userId;
    print('MovieProvider: setUserId called with: $_currentUserId');
    if (_currentUserId != null) {
      _initializeMoviesAndWishlist();
    }
  }

  Future<void> _initializeMoviesAndWishlist() async {
    print('MovieProvider: Starting _initializeMoviesAndWishlist...');
    await _loadWishlist();
    print('MovieProvider: _loadWishlist completed. Skipped movies count: ${_skippedMovies.length}');
    _skippedMovies.forEach((movie) => print('  Skipped movie: ${movie.title} (${movie.id})'));
    await getPopularMovies();
    print('MovieProvider: _initializeMoviesAndWishlist completed.');
  }

  Future<void> _loadWishlist() async {
    print('MovieProvider: _loadWishlist called. Current UserId: $_currentUserId');
    if (_currentUserId == null) return;

    try {
      final headers = await _getAuthHeaders();
      final response = await _dio.get(
        '$_backendUrl/wishlist/$_currentUserId',
        options: Options(headers: headers),
      );
      if (response.data != null) {
        final List<dynamic> movieIdsData = response.data['movieIds'] ?? [];
        _wishlist = movieIdsData.map((data) => Movie.fromJson(data as Map<String, dynamic>)).toList();

        final List<dynamic> skippedMovieIdsData = response.data['skippedMovieIds'] ?? [];
        _skippedMovies = skippedMovieIdsData.map((data) => Movie.fromJson(data as Map<String, dynamic>)).toList();
        
        notifyListeners();
      }
    } catch (e) {
      print('Error loading wishlist/skipped movies: $e');
      _error = 'Failed to load wishlist/skipped movies: $e';
      notifyListeners();
    }
  }

  Future<void> searchMovies(String query) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {
          's': query,
          'type': 'movie',
          'apikey': _apiKey,
        },
      );

      if (response.data['Response'] == 'True') {
        List<Movie> fetchedMovies = (response.data['Search'] as List)
            .map((movie) => Movie.fromJson(movie))
            .toList();
        
        print('MovieProvider: searchMovies fetched ${fetchedMovies.length} movies.');
        fetchedMovies.forEach((movie) => print('  Fetched movie: ${movie.title} (${movie.id})'));

        _movies = fetchedMovies.where((movie) => !_skippedMovies.any((skipped) => skipped.id == movie.id)).toList();

        print('MovieProvider: searchMovies after filtering, _movies count: ${_movies.length}');
        _movies.forEach((movie) => print('  Filtered movie: ${movie.title} (${movie.id})'));

      } else {
        _movies = [];
        _error = response.data['Error'] ?? 'Unknown error occurred.';
      }
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
        _baseUrl,
        queryParameters: {
          's': 'movie',
          'type': 'movie',
          'apikey': _apiKey,
        },
      );

      if (response.data['Response'] == 'True') {
        List<Movie> fetchedMovies = (response.data['Search'] as List)
            .map((movie) => Movie.fromJson(movie))
            .toList();
        
        print('MovieProvider: getPopularMovies fetched ${fetchedMovies.length} movies.');
        fetchedMovies.forEach((movie) => print('  Fetched movie: ${movie.title} (${movie.id})'));

        _movies = fetchedMovies.where((movie) => !_skippedMovies.any((skipped) => skipped.id == movie.id)).toList();

        print('MovieProvider: getPopularMovies after filtering, _movies count: ${_movies.length}');
        _movies.forEach((movie) => print('  Filtered movie: ${movie.title} (${movie.id})'));

      } else {
        _movies = [];
        _error = response.data['Error'] ?? 'Unknown error occurred.';
      }
    } catch (e) {
      _error = 'Failed to load popular movies: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addToWishlist(Movie movie) async {
    print('MovieProvider: addToWishlist called. Current UserId: $_currentUserId');
    if (_currentUserId == null) {
      _error = 'User not logged in';
      notifyListeners();
      return;
    }

    try {
      final headers = await _getAuthHeaders();
      await _dio.post(
        '$_backendUrl/wishlist/$_currentUserId',
        data: movie.toJson(),
        options: Options(headers: headers),
      );
      
      if (!_wishlist.any((m) => m.id == movie.id)) {
        _wishlist.add(movie);
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to add movie to wishlist: $e';
      notifyListeners();
    }
  }

  Future<void> removeFromWishlist(Movie movie) async {
    print('MovieProvider: removeFromWishlist called. Current UserId: $_currentUserId');
    if (_currentUserId == null) {
      _error = 'User not logged in';
      notifyListeners();
      return;
    }

    try {
      final headers = await _getAuthHeaders();
      await _dio.delete(
        '$_backendUrl/wishlist/$_currentUserId/${movie.id}',
        options: Options(headers: headers),
      );
      
      _wishlist.removeWhere((m) => m.id == movie.id);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to remove movie from wishlist: $e';
      notifyListeners();
    }
  }

  Future<void> skipMovie(Movie movie) async {
    print('MovieProvider: skipMovie called. Current UserId: $_currentUserId');
    if (_currentUserId == null) {
      _error = 'User not logged in';
      notifyListeners();
      return;
    }

    try {
      final headers = await _getAuthHeaders();
      await _dio.post(
        '$_backendUrl/skipped/$_currentUserId',
        data: movie.toJson(),
        options: Options(headers: headers),
      );
      
      _movies.removeWhere((m) => m.id == movie.id);
      _skippedMovies.add(movie);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to skip movie: $e';
      notifyListeners();
    }
  }

  Future<Movie?> undoSkipMovie() async {
    print('MovieProvider: undoSkipMovie called. Current UserId: $_currentUserId');
    if (_skippedMovies.isEmpty) return null;
    if (_currentUserId == null) {
      _error = 'User not logged in';
      notifyListeners();
      return null;
    }

    final movieToUndo = _skippedMovies.last;

    try {
      final headers = await _getAuthHeaders();
      await _dio.delete(
        '$_backendUrl/skipped/$_currentUserId/${movieToUndo.id}',
        options: Options(headers: headers),
      );
      
      _skippedMovies.removeLast();
      _movies.insert(0, movieToUndo);
      notifyListeners();
      return movieToUndo;
    } catch (e) {
      _error = 'Failed to undo skipped movie: $e';
      notifyListeners();
      return null;
    }
  }

  Future<void> undoAllSkippedMovies() async {
    print('MovieProvider: undoAllSkippedMovies called. Current UserId: $_currentUserId');
    if (_skippedMovies.isEmpty) {
      print('MovieProvider: No skipped movies to undo.');
      return;
    }
    if (_currentUserId == null) {
      _error = 'User not logged in';
      notifyListeners();
      return;
    }

    try {
      final headers = await _getAuthHeaders();
      await _dio.delete(
        '$_backendUrl/skipped/$_currentUserId/all',
        options: Options(headers: headers),
      );
      
      _movies.insertAll(0, _skippedMovies);
      _skippedMovies.clear();
      notifyListeners();
      print('MovieProvider: Successfully unskipped all movies.');
    } catch (e) {
      _error = 'Failed to undo all skipped movies: $e';
      notifyListeners();
      print('MovieProvider: Error undoing all skipped movies: $e');
    }
  }

  bool isInWishlist(Movie movie) {
    return _wishlist.any((m) => m.id == movie.id);
  }
} 