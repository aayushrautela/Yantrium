/// Represents a cast or crew member
class CastCrewMember {
  final String name;
  final String? character; // Character name for cast, role/job for crew
  final String? profileImageUrl;
  final int? order; // For sorting cast by importance

  CastCrewMember({
    required this.name,
    this.character,
    this.profileImageUrl,
    this.order,
  });

  factory CastCrewMember.fromJson(Map<String, dynamic> json) {
    return CastCrewMember(
      name: json['name'] as String? ?? '',
      character: json['character'] as String? ?? json['job'] as String?,
      profileImageUrl: json['profile_path'] as String?,
      order: json['order'] as int?,
    );
  }
}













