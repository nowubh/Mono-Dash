class FileFavoriteDto {
  const FileFavoriteDto({
    required this.id,
    required this.path,
    required this.name,
    required this.isDir,
    required this.isTxt,
  });

  final int id;
  final String path;
  final String name;
  final bool isDir;
  final bool isTxt;

  factory FileFavoriteDto.fromJson(Map<String, dynamic> json) {
    return FileFavoriteDto(
      id: (json['id'] as num? ?? json['ID'] as num?)?.toInt() ?? 0,
      path: json['path'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isDir: json['isDir'] as bool? ?? false,
      isTxt: json['isTxt'] as bool? ?? false,
    );
  }
}
