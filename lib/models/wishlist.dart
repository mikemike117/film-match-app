class Wishlist {
  final String userId;
  final List<String> movieIds;

  Wishlist({
    required this.userId,
    required this.movieIds,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'movieIds': movieIds,
    };
  }

  factory Wishlist.fromJson(Map<String, dynamic> json) {
    return Wishlist(
      userId: json['userId'],
      movieIds: List<String>.from(json['movieIds'] ?? []),
    );
  }
} 