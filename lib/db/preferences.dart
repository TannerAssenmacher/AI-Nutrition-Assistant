import 'package:json_annotation/json_annotation.dart';

part 'preferences.g.dart';

// -----------------------------------------------------------------------------
// PREFERENCES
// -----------------------------------------------------------------------------

@JsonSerializable()
class Preferences {
  @JsonKey(fromJson: _stringListFromJson)
  final List<String> likes;
  @JsonKey(fromJson: _stringListFromJson)
  final List<String> dislikes;

  static List<String> _stringListFromJson(dynamic value) {
    if (value is List) {
      return value.map((e) {
        if (e is String) return e;
        if (e is num) return e.toString();
        return e.toString();
      }).toList();
    }
    return [];
  }

  Preferences({required this.likes, required this.dislikes});

  factory Preferences.fromJson(Map<String, dynamic> json) =>
      _$PreferencesFromJson(json);
  Map<String, dynamic> toJson() => _$PreferencesToJson(this);
}