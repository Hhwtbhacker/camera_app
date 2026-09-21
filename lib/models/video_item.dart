class VideoItem {
  final String name;
  final int size;
  final int mtime;

  VideoItem({required this.name, required this.size, required this.mtime});

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    return VideoItem(
      name: json['name'] as String,
      size: json['size'] as int,
      mtime: json['mtime'] as int,
    );
  }

  String get sizeText {
    if (size >= 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / 1024).toStringAsFixed(0)} KB';
  }

  String get timeText {
    final dt = DateTime.fromMillisecondsSinceEpoch(mtime * 1000);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }
}
