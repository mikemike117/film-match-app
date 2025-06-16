import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/movie_details.dart';

class MovieCacheService {
  static const String _cacheKey = 'movie_cache';
  static const Duration _cacheValidity = Duration(days: 7);

  final SharedPreferences _prefs;

  MovieCacheService(this._prefs);

  Future<void> cacheMovie(MovieDetails movie) async {
    final cache = await _getCache();
    cache[movie.id] = movie.toJson();
    await _saveCache(cache);
  }

  Future<void> cacheMovies(List<MovieDetails> movies) async {
    final cache = await _getCache();
    for (var movie in movies) {
      cache[movie.id] = movie.toJson();
    }
    await _saveCache(cache);
  }

  Future<MovieDetails?> getCachedMovie(String id) async {
    final cache = await _getCache();
    final movieData = cache[id];
    if (movieData == null) return null;

    final movie = MovieDetails.fromCache(movieData);
    if (_isCacheExpired(movie.lastUpdated)) {
      cache.remove(id);
      await _saveCache(cache);
      return null;
    }

    return movie;
  }

  Future<List<MovieDetails>> getCachedMovies(List<String> ids) async {
    final cache = await _getCache();
    final movies = <MovieDetails>[];
    final expiredIds = <String>[];

    for (var id in ids) {
      final movieData = cache[id];
      if (movieData != null) {
        final movie = MovieDetails.fromCache(movieData);
        if (!_isCacheExpired(movie.lastUpdated)) {
          movies.add(movie);
        } else {
          expiredIds.add(id);
        }
      }
    }

    // Удаляем устаревшие записи
    if (expiredIds.isNotEmpty) {
      for (var id in expiredIds) {
        cache.remove(id);
      }
      await _saveCache(cache);
    }

    return movies;
  }

  Future<Map<String, dynamic>> _getCache() async {
    final cacheJson = _prefs.getString(_cacheKey);
    if (cacheJson == null) return {};
    return Map<String, dynamic>.from(json.decode(cacheJson));
  }

  Future<void> _saveCache(Map<String, dynamic> cache) async {
    await _prefs.setString(_cacheKey, json.encode(cache));
  }

  bool _isCacheExpired(DateTime lastUpdated) {
    return DateTime.now().difference(lastUpdated) > _cacheValidity;
  }

  Future<void> clearCache() async {
    await _prefs.remove(_cacheKey);
  }
} 