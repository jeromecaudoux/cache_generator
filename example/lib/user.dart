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
}
