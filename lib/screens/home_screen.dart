import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:film_match_app/providers/auth_provider.dart';
import 'package:film_match_app/providers/movie_provider.dart';
import 'package:film_match_app/screens/login_screen.dart';
import 'package:film_match_app/screens/wishlist_screen.dart';
import 'package:film_match_app/widgets/movie_card.dart';
import 'package:film_match_app/models/movie.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// New widget for the search bar
class _SearchBarWidget extends StatefulWidget implements PreferredSizeWidget {
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;
  final VoidCallback onSubmittedEmpty;

  const _SearchBarWidget({
    Key? key,
    required this.onSearch,
    required this.onClear,
    required this.onSubmittedEmpty,
  }) : super(key: key);

  @override
  State<_SearchBarWidget> createState() => _SearchBarWidgetState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _SearchBarWidgetState extends State<_SearchBarWidget> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        // Rebuilds only this widget to update the clear icon visibility.
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Поиск фильмов...',
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.black54),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.black),
                onPressed: () {
                  _searchController.clear();
                  widget.onClear();
                },
              )
            : null,
      ),
      style: TextStyle(color: Colors.black),
      onSubmitted: (query) {
        if (query.isNotEmpty) {
          widget.onSearch(query);
        } else {
          widget.onSubmittedEmpty();
        }
      },
    );
  }
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context);
    final movieProvider = Provider.of<MovieProvider>(context, listen: false);

    // Listen to changes in AuthProvider to update MovieProvider's userId
    if (authProvider.user != null) {
      movieProvider.setUserId(authProvider.user!.uid);
    } else {
      movieProvider.setUserId(null);
    }
    
    // Load popular movies only once after dependencies are set
    if (movieProvider.movies.isEmpty && !movieProvider.isLoading) {
      movieProvider.getPopularMovies();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _signOut() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка выхода: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final movieProvider = Provider.of<MovieProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: _SearchBarWidget(
          onSearch: (query) {
            movieProvider.searchMovies(query);
          },
          onClear: () {
            movieProvider.getPopularMovies();
          },
          onSubmittedEmpty: () {
            movieProvider.getPopularMovies();
          },
        ),
        actions: [
          Consumer<MovieProvider>(
            builder: (context, movieProvider, child) {
              if (movieProvider.skippedMovies.isNotEmpty) {
                return Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.undo),
                      onPressed: () async {
                        final undoneMovie = await movieProvider.undoSkipMovie();
                        if (undoneMovie != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Фильм "${undoneMovie.title}" возвращен'),
                            ),
                          );
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear_all),
                      onPressed: () async {
                        await movieProvider.undoAllSkippedMovies();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Все пропущенные фильмы возвращены'),
                          ),
                        );
                      },
                    ),
                  ],
                );
              } else {
                return const SizedBox.shrink();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WishlistScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: Consumer<MovieProvider>(
        builder: (context, movieProvider, child) {
          if (movieProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (movieProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Ошибка: ${movieProvider.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      movieProvider.getPopularMovies();
                    },
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }
          if (movieProvider.movies.isEmpty) {
            return const Center(
              child: Text('Фильмы не найдены'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: movieProvider.movies.length,
            itemBuilder: (context, index) {
              final movie = movieProvider.movies[index];
              final bool isInWishlist = movieProvider.wishlist.any((m) => m.id == movie.id);
              return MovieCard(
                movie: movie,
                isInWishlist: isInWishlist,
                onWishlistToggle: () {
                  movieProvider.toggleWishlist(movie);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isInWishlist
                          ? 'Фильм удален из избранного'
                          : 'Фильм добавлен в избранное'),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implement group matching feature
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Групповой матчинг скоро будет доступен!'),
            ),
          );
        },
        child: const Icon(Icons.group),
      ),
    );
  }
} 