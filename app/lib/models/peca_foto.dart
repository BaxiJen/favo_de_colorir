class PecaFoto {
  final String id;
  final String pecaId;
  final String storagePath;
  final String? caption;
  final String uploadedBy;
  final DateTime createdAt;

  const PecaFoto({
    required this.id,
    required this.pecaId,
    required this.storagePath,
    this.caption,
    required this.uploadedBy,
    required this.createdAt,
  });

  factory PecaFoto.fromJson(Map<String, dynamic> json) {
    return PecaFoto(
      id: json['id'] as String,
      pecaId: json['peca_id'] as String,
      storagePath: json['storage_path'] as String,
      caption: json['caption'] as String?,
      uploadedBy: json['uploaded_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'peca_id': pecaId,
        'storage_path': storagePath,
        'caption': caption,
        'uploaded_by': uploadedBy,
      };
}
