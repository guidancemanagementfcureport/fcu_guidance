class ResourceModel {
  final String id;
  final String counselorId;
  final String title;
  final String? description;
  final String fileUrl;
  final ResourceFileType fileType;
  final String? category;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;

  ResourceModel({
    required this.id,
    required this.counselorId,
    required this.title,
    this.description,
    required this.fileUrl,
    required this.fileType,
    this.category,
    this.isPublic = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ResourceModel.fromJson(Map<String, dynamic> json) {
    return ResourceModel(
      id: json['id'] as String,
      counselorId: json['counselor_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      fileUrl: json['file_url'] as String,
      fileType: ResourceFileType.fromString(json['file_type'] as String),
      category: json['category'] as String?,
      isPublic: json['is_public'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'counselor_id': counselorId,
      'title': title,
      'description': description,
      'file_url': fileUrl,
      'file_type': fileType.toString(),
      'category': category,
      'is_public': isPublic,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

enum ResourceFileType {
  pdf,
  image,
  document;

  static ResourceFileType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return ResourceFileType.pdf;
      case 'image':
        return ResourceFileType.image;
      case 'document':
        return ResourceFileType.document;
      default:
        throw ArgumentError('Invalid file type: $type');
    }
  }

  @override
  String toString() {
    switch (this) {
      case ResourceFileType.pdf:
        return 'pdf';
      case ResourceFileType.image:
        return 'image';
      case ResourceFileType.document:
        return 'document';
    }
  }
}
