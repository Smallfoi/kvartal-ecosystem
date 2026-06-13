class Category {
  final String id;
  final String name;
  final String emoji;
  final String? imageUrl;

  const Category({
    required this.id,
    required this.name,
    required this.emoji,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'imageUrl': imageUrl,
      };

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] as String,
        name: j['name'] as String,
        emoji: j['emoji'] as String? ?? '',
        imageUrl: j['imageUrl'] as String?,
      );
}
