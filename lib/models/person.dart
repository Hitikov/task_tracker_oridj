class Person {
  final String id; // UUID (Primary Key)
  String name; // VARCHAR(255) - Имя пользователя

  Person({required this.id, required this.name});

  // Factory constructor: из строки БД в объект Dart
  factory Person.fromMap(Map<String, dynamic> data) {
    return Person(
      id: data['id'] as String,
      name: data['name'] as String,
    );
  }

  // Method: преобразование объекта Dart в Map для сохранения в БД
  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name};
  }
}
