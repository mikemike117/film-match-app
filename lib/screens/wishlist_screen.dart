import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/movie_provider.dart';
import '../models/movie.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Избранное'),
      ),
      body: Consumer<MovieProvider>(
        builder: (context, movieProvider, child) {
          final wishlist = movieProvider.wishlist;
          
          if (wishlist.isEmpty) {
            return const Center(
              child: Text('В избранном пока ничего нет'),
            );
          }

          return ListView.builder(
            itemCount: wishlist.length,
            itemBuilder: (context, index) {
              final movie = wishlist[index];
              return ListTile(
                leading: movie.poster.isNotEmpty
                    ? Image.network(
                        movie.poster,
                        width: 50,
                        height: 75,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.movie);
                        },
                      )
                    : const Icon(Icons.movie),
                title: Text(movie.title),
                subtitle: Text(movie.year),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => movieProvider.toggleWishlist(movie),
                ),
                onTap: () {
                  // TODO: Добавить навигацию к деталям фильма
                },
              );
            },
          );
        },
      ),
    );
  }
} 