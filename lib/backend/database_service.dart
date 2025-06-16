import 'package:mongo_dart/mongo_dart.dart';

class DatabaseService {
  static DatabaseService? _instance;
  static Db? _db;
  
  // Приватный конструктор для синглтона
  DatabaseService._();
  
  // Фабричный конструктор
  factory DatabaseService() {
    _instance ??= DatabaseService._();
    return _instance!;
  }
  
  // Метод для подключения к базе данных
  Future<void> connect() async {
    if (_db != null) return;
    // Подключаемся к базе данных без аутентификации
    _db = await Db.create('mongodb://localhost:27017/film_match');
    await _db!.open();
    print('Connected to MongoDB!');
  }
  
  // Метод для получения коллекции
  DbCollection getCollection(String collectionName) {
    if (_db == null) {
      throw Exception('Database not connected. Call connect() first.');
    }
    return _db!.collection(collectionName);
  }
  
  // Метод для закрытия соединения
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
} 