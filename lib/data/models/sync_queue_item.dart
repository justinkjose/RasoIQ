enum SyncActionType { upsert, delete }

class SyncQueueItem {
  SyncQueueItem({
    required this.id,
    required this.type,
    required this.collection,
    required this.entityId,
    required this.action,
    required this.payload,
    required this.queuedAt,
    required this.retryCount,
  });

  final String id;
  final String type;
  final String collection;
  final String entityId;
  final SyncActionType action;
  final Map<String, dynamic> payload;
  final DateTime queuedAt;
  final int retryCount;

  factory SyncQueueItem.upsert({
    required String collection,
    required String entityId,
    required Map<String, dynamic> payload,
  }) {
    return SyncQueueItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: 'upsert',
      collection: collection,
      entityId: entityId,
      action: SyncActionType.upsert,
      payload: payload,
      queuedAt: DateTime.now(),
      retryCount: 0,
    );
  }

  factory SyncQueueItem.delete({
    required String collection,
    required String entityId,
    required Map<String, dynamic> payload,
  }) {
    return SyncQueueItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: 'delete',
      collection: collection,
      entityId: entityId,
      action: SyncActionType.delete,
      payload: payload,
      queuedAt: DateTime.now(),
      retryCount: 0,
    );
  }

  factory SyncQueueItem.operation({
    required String type,
    required String collection,
    required String entityId,
    required Map<String, dynamic> payload,
  }) {
    return SyncQueueItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      collection: collection,
      entityId: entityId,
      action: type == 'delete_item' || type == 'delete'
          ? SyncActionType.delete
          : SyncActionType.upsert,
      payload: payload,
      queuedAt: DateTime.now(),
      retryCount: 0,
    );
  }

  SyncQueueItem copyWith({
    String? type,
    String? collection,
    String? entityId,
    SyncActionType? action,
    Map<String, dynamic>? payload,
    DateTime? queuedAt,
    int? retryCount,
  }) {
    return SyncQueueItem(
      id: id,
      type: type ?? this.type,
      collection: collection ?? this.collection,
      entityId: entityId ?? this.entityId,
      action: action ?? this.action,
      payload: payload ?? this.payload,
      queuedAt: queuedAt ?? this.queuedAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'collection': collection,
      'entityId': entityId,
      'action': action.name,
      'payload': payload,
      'queuedAt': queuedAt.toIso8601String(),
      'retryCount': retryCount,
    };
  }

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    final actionName = json['action']?.toString() ?? 'upsert';
    return SyncQueueItem(
      id: json['id'] as String,
      type: json['type']?.toString() ?? actionName,
      collection: json['collection'] as String,
      entityId: json['entityId'] as String,
      action: SyncActionType.values.firstWhere(
        (value) => value.name == actionName,
        orElse: () => SyncActionType.upsert,
      ),
      payload: Map<String, dynamic>.from(
        json['payload'] as Map? ?? <String, dynamic>{},
      ),
      queuedAt: DateTime.parse(json['queuedAt'] as String),
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
    );
  }
}
