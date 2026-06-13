enum NotifType { order, promo, system }

class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotifType type;
  final String? orderId;
  final DateTime createdAt;
  final bool read;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.orderId,
    required this.createdAt,
    this.read = false,
  });

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        orderId: orderId,
        createdAt: createdAt,
        read: read ?? this.read,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type.name,
        'orderId': orderId,
        'createdAt': createdAt.toIso8601String(),
        'read': read,
      };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        type: NotifType.values.firstWhere(
          (e) => e.name == j['type'],
          orElse: () => NotifType.system,
        ),
        orderId: j['orderId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        read: j['read'] as bool? ?? false,
      );
}
