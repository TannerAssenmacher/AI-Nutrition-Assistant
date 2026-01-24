import 'package:json_annotation/json_annotation.dart';

part 'preferences.g.dart';

// -----------------------------------------------------------------------------
// PREFERENCES
// -----------------------------------------------------------------------------

@JsonSerializable()
class Preferences {
  final List<String> likes;
  final List<String> dislikes;

  Preferences({required this.likes, required this.dislikes});

  factory Preferences.fromJson(Map<String, dynamic> json) =>
      _$PreferencesFromJson(json);
  Map<String, dynamic> toJson() => _$PreferencesToJson(this);
}