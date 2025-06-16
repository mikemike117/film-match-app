import 'package:mongo_dart/mongo_dart.dart';
import 'dart:io';

class MongoDB {
  static late Db _db;
  static late DbCollection wishlists;

  static Future<void> connect() async {
    try {
      _db = await Db.create('mongodb://localhost:27017/film_match');
      await _db.open();
      wishlists = _db.collection('wishlists');
      print('Connected to MongoDB');
    } catch (e) {
      print('Error connecting to MongoDB: $e');
      rethrow;
    }
  }

  static Future<void> close() async {
    await _db.close();
  }
} 