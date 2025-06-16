import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:film_match_app/providers/movie_provider.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Избранные фильмы'),
      ),
      body: Consumer<MovieProvider>(
        builder: (context, movieProvider, child) {
          if (movieProvider.wishlist.isEmpty) {
            return const Center(
              child: Text('Ваш список избранного пуст.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: movieProvider.wishlist.length,
            itemBuilder: (context, index) {
              final movie = movieProvider.wishlist[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: movie.posterPath.isNotEmpty
                      ? Image.network(
                          movie.posterPath,
                          width: 50,
                          height: 75,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.broken_image),
                        )
                      : const Icon(Icons.movie),
                  title: Text(movie.title),
                  subtitle: Text('Год: ${movie.year}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      movieProvider.removeFromWishlist(movie);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Фильм "${movie.title}" удален из избранного'),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
} 