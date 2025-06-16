class Movie {
  final String id;
  final String title;
  final String year;
  final String poster;

  Movie({
    required this.id,
    required this.title,
    required this.year,
    required this.poster,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['imdbID'] ?? '',
      title: json['Title'] ?? '',
      year: json['Year'] ?? '',
      poster: json['Poster'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'imdbID': id,
      'Title': title,
      'Year': year,
      'Poster': poster,
    };
  }
} 