class AuditLog {
  final String id;
  final String? actorId;
  final String action;
  final String resourceType;
  final String? resourceId;
  final Map<String, dynamic>? changes;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const AuditLog({
    required this.id,
    this.actorId,
    required this.action,
    required this.resourceType,
    this.resourceId,
    this.changes,
    this.metadata,
    required this.createdAt,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'] as String,
      actorId: json['actor_id'] as String?,
      action: json['action'] as String,
      resourceType: json['resource_type'] as String,
      resourceId: json['resource_id'] as String?,
      changes: json['changes'] as Map<String, dynamic>?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'actor_id': actorId,
        'action': action,
        'resource_type': resourceType,
        'resource_id': resourceId,
        'changes': changes,
        'metadata': metadata,
      };
}
