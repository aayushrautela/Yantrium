/// Represents a playable stream from an addon
/// This is a placeholder for future use in stage 2+
class StreamInfo {
  final String? id;
  final String? title;
  final String? name;
  final String? description;
  final String url; // Stream URL (required)
  final String? quality; // e.g., "1080p", "720p"
  final String? type; // e.g., "movie", "series"
  final List<Subtitle>? subtitles;
  final Map<String, dynamic>? behaviorHints;
  final String? addonId;
  final String? addonName;
  final String? infoHash; // For magnet link construction
  final int? fileIdx; // File index for torrent streams
  final int? size; // Stream size in bytes
  final bool? isFree; // Whether stream is free
  final bool? isDebrid; // Whether stream is from debrid service

  StreamInfo({
    this.id,
    this.title,
    this.name,
    this.description,
    required this.url,
    this.quality,
    this.type,
    this.subtitles,
    this.behaviorHints,
    this.addonId,
    this.addonName,
    this.infoHash,
    this.fileIdx,
    this.size,
    this.isFree,
    this.isDebrid,
  });

  factory StreamInfo.fromJson(Map<String, dynamic> json) {
    return StreamInfo(
      id: json['id'] as String?,
      title: json['title'] as String?,
      name: json['name'] as String?,
      description: json['description'] as String?,
      url: json['url'] as String,
      quality: json['quality'] as String?,
      type: json['type'] as String?,
      subtitles: json['subtitles'] != null
          ? (json['subtitles'] as List<dynamic>)
              .map((s) => Subtitle.fromJson(s as Map<String, dynamic>))
              .toList()
          : null,
      behaviorHints: json['behaviorHints'] as Map<String, dynamic>?,
      addonId: json['addonId'] as String?,
      addonName: json['addonName'] as String?,
      infoHash: json['infoHash'] as String?,
      fileIdx: json['fileIdx'] as int?,
      size: json['size'] as int?,
      isFree: json['isFree'] as bool?,
      isDebrid: json['isDebrid'] as bool?,
    );
  }
}

class Subtitle {
  final String url;
  final String lang;
  final String? id;

  Subtitle({
    required this.url,
    required this.lang,
    this.id,
  });

  factory Subtitle.fromJson(Map<String, dynamic> json) {
    return Subtitle(
      url: json['url'] as String,
      lang: json['lang'] as String,
      id: json['id'] as String?,
    );
  }
}


