class User {
  final String name;
  final int age;

  User(this.name, this.age);

  User.fromJson(dynamic json)
      : name = json['name'],
        age = json['age'];

  Map<String, dynamic> toJson() => {
    'name': name,
    'age': age,
  };

  @override
  String toString() {
    return 'User{name: $name, age: $age}';
  }
}
