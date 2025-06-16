class MovieDetails {
  final String id;
  final String title;
  final String year;
  final String poster;
  final String plot;
  final String director;
  final String actors;
  final String genre;
  final String runtime;
  final String imdbRating;
  final DateTime lastUpdated;

  MovieDetails({
    required this.id,
    required this.title,
    required this.year,
    required this.poster,
    required this.plot,
    required this.director,
    required this.actors,
    required this.genre,
    required this.runtime,
    required this.imdbRating,
    required this.lastUpdated,
  });

  factory MovieDetails.fromJson(Map<String, dynamic> json) {
    return MovieDetails(
      id: json['imdbID'] ?? '',
      title: json['Title'] ?? '',
      year: json['Year'] ?? '',
      poster: json['Poster'] ?? '',
      plot: json['Plot'] ?? '',
      director: json['Director'] ?? '',
      actors: json['Actors'] ?? '',
      genre: json['Genre'] ?? '',
      runtime: json['Runtime'] ?? '',
      imdbRating: json['imdbRating'] ?? '',
      lastUpdated: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'imdbID': id,
      'Title': title,
      'Year': year,
      'Poster': poster,
      'Plot': plot,
      'Director': director,
      'Actors': actors,
      'Genre': genre,
      'Runtime': runtime,
      'imdbRating': imdbRating,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory MovieDetails.fromCache(Map<String, dynamic> json) {
    return MovieDetails(
      id: json['imdbID'] ?? '',
      title: json['Title'] ?? '',
      year: json['Year'] ?? '',
      poster: json['Poster'] ?? '',
      plot: json['Plot'] ?? '',
      director: json['Director'] ?? '',
      actors: json['Actors'] ?? '',
      genre: json['Genre'] ?? '',
      runtime: json['Runtime'] ?? '',
      imdbRating: json['imdbRating'] ?? '',
      lastUpdated: DateTime.parse(json['lastUpdated'] ?? DateTime.now().toIso8601String()),
    );
  }
} 