class AdItem {
  const AdItem({
    required this.id,
    required this.type,
    required this.targetScreens,
    required this.title,
    required this.imageUrl,
    required this.clickUrl,
    required this.priority,
    required this.active,
    required this.startAt,
    required this.endAt,
  });

  final String id;
  final String type;
  final List<String> targetScreens;
  final String title;
  final String imageUrl;
  final String clickUrl;
  final int priority;
  final bool active;
  final DateTime? startAt;
  final DateTime? endAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'targetScreens': targetScreens,
      'title': title,
      'imageUrl': imageUrl,
      'clickUrl': clickUrl,
      'priority': priority,
      'active': active,
      'startAt': startAt?.toIso8601String(),
      'endAt': endAt?.toIso8601String(),
    };
  }

  factory AdItem.fromJson(Map<String, dynamic> json) {
    return AdItem(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'banner',
      targetScreens: (json['targetScreens'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      title: json['title']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      clickUrl: json['clickUrl']?.toString() ?? '',
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      active: json['active'] as bool? ?? true,
      startAt: _parseDate(json['startAt']),
      endAt: _parseDate(json['endAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
