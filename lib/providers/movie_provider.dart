import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/movie.dart';
import '../models/movie_details.dart';
import '../services/movie_cache_service.dart';

class MovieProvider with ChangeNotifier {
  final Dio _dio = Dio();
  final String _baseUrl = 'https://www.omdbapi.com/'; // OMDb API Base URL
  final String _apiKey = 'b5748ebb'; // Replace with your OMDb API Key
  final String _backendUrl = 'http://localhost:8080';
  final MovieCacheService _cacheService;
  
  List<Movie> _movies = [];
  List<Movie> _wishlist = [];
  List<Movie> _skippedMovies = [];
  bool _isLoading = false;
  String? _error;
  String? _currentUserId;

  MovieProvider(SharedPreferences prefs) : _cacheService = MovieCacheService(prefs);

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
    } else {
      _movies = [];
      _wishlist = [];
      _skippedMovies = [];
      notifyListeners();
    }
  }

  Future<void> _initializeMoviesAndWishlist() async {
    print('MovieProvider: Starting _initializeMoviesAndWishlist...');
    await _loadWishlist();
    await getPopularMovies();
    print('MovieProvider: _initializeMoviesAndWishlist completed.');
  }

  Future<void> _loadWishlist() async {
    print('MovieProvider: _loadWishlist called. Current UserId: $_currentUserId');
    if (_currentUserId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final wishlistJson = prefs.getStringList('wishlist_$_currentUserId') ?? [];
      final skippedJson = prefs.getStringList('skipped_$_currentUserId') ?? [];

      _wishlist = wishlistJson.map((id) => Movie(id: id, title: '', year: '', poster: '')).toList();
      _skippedMovies = skippedJson.map((id) => Movie(id: id, title: '', year: '', poster: '')).toList();

      // Загружаем детали фильмов из кэша
      final wishlistDetails = await _cacheService.getCachedMovies(_wishlist.map((m) => m.id).toList());
      final skippedDetails = await _cacheService.getCachedMovies(_skippedMovies.map((m) => m.id).toList());

      // Обновляем информацию о фильмах
      _wishlist = wishlistDetails.map((details) => Movie(
        id: details.id,
        title: details.title,
        year: details.year,
        poster: details.poster,
      )).toList();

      _skippedMovies = skippedDetails.map((details) => Movie(
        id: details.id,
        title: details.title,
        year: details.year,
        poster: details.poster,
      )).toList();

      print('MovieProvider: _loadWishlist completed. Skipped movies count: ${_skippedMovies.length}');
    } catch (e) {
      print('MovieProvider: Error loading wishlist: $e');
      _error = 'Failed to load wishlist: $e';
    }
  }

  Future<void> searchMovies(String query) async {
    if (query.isEmpty) {
      await getPopularMovies();
      return;
    }

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

        // Загружаем детали фильмов из кэша или API
        final moviesWithDetails = await Future.wait(
          fetchedMovies.map((movie) => _getMovieDetails(movie))
        );

        _movies = moviesWithDetails.where((movie) => 
          !_skippedMovies.any((skipped) => skipped.id == movie.id)
        ).toList();
      } else {
        _movies = [];
        _error = response.data['Error'] ?? 'No movies found.';
      }
    } catch (e) {
      _error = 'Failed to search movies: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Movie> _getMovieDetails(Movie movie) async {
    // Сначала проверяем кэш
    final cachedMovie = await _cacheService.getCachedMovie(movie.id);
    if (cachedMovie != null) {
      return Movie(
        id: cachedMovie.id,
        title: cachedMovie.title,
        year: cachedMovie.year,
        poster: cachedMovie.poster,
      );
    }

    // Если в кэше нет, запрашиваем из API
    try {
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {
          'i': movie.id,
          'apikey': _apiKey,
        },
      );

      if (response.data['Response'] == 'True') {
        final details = MovieDetails.fromJson(response.data);
        await _cacheService.cacheMovie(details);
        return Movie(
          id: details.id,
          title: details.title,
          year: details.year,
          poster: details.poster,
        );
      }
    } catch (e) {
      print('Error fetching movie details: $e');
    }

    // Если API недоступен, возвращаем базовую информацию
    return movie;
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

        // Загружаем детали фильмов из кэша или API
        final moviesWithDetails = await Future.wait(
          fetchedMovies.map((movie) => _getMovieDetails(movie))
        );

        _movies = moviesWithDetails.where((movie) => 
          !_skippedMovies.any((skipped) => skipped.id == movie.id)
        ).toList();

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

  Future<void> toggleWishlist(Movie movie) async {
    if (_currentUserId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final wishlistJson = prefs.getStringList('wishlist_$_currentUserId') ?? [];

    if (wishlistJson.contains(movie.id)) {
      wishlistJson.remove(movie.id);
      _wishlist.removeWhere((m) => m.id == movie.id);
    } else {
      wishlistJson.add(movie.id);
      _wishlist.add(movie);
    }

    await prefs.setStringList('wishlist_$_currentUserId', wishlistJson);
    notifyListeners();
  }

  Future<void> skipMovie(Movie movie) async {
    if (_currentUserId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final skippedJson = prefs.getStringList('skipped_$_currentUserId') ?? [];

    if (!skippedJson.contains(movie.id)) {
      skippedJson.add(movie.id);
      _skippedMovies.add(movie);
      _movies.removeWhere((m) => m.id == movie.id);
      await prefs.setStringList('skipped_$_currentUserId', skippedJson);
      notifyListeners();
    }
  }

  Future<Movie?> undoSkipMovie() async {
    if (_currentUserId == null) return null;
    if (_skippedMovies.isEmpty) return null;

    final movieToUndo = _skippedMovies.last;
    final prefs = await SharedPreferences.getInstance();
    final skippedJson = prefs.getStringList('skipped_$_currentUserId') ?? [];

    if (skippedJson.contains(movieToUndo.id)) {
      skippedJson.remove(movieToUndo.id);
      _skippedMovies.removeLast();
      _movies.insert(0, movieToUndo);
      await prefs.setStringList('skipped_$_currentUserId', skippedJson);
      notifyListeners();
      return movieToUndo;
    }
    return null;
  }

  Future<void> undoAllSkippedMovies() async {
    if (_currentUserId == null) return;
    if (_skippedMovies.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('skipped_$_currentUserId');
    
    _movies.insertAll(0, _skippedMovies);
    _skippedMovies.clear();
    notifyListeners();
  }

  Future<void> returnMovie(Movie movie) async {
    if (_currentUserId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final skippedJson = prefs.getStringList('skipped_$_currentUserId') ?? [];

    if (skippedJson.contains(movie.id)) {
      skippedJson.remove(movie.id);
      _skippedMovies.removeWhere((m) => m.id == movie.id);
      await prefs.setStringList('skipped_$_currentUserId', skippedJson);
      notifyListeners();
    }
  }
} 