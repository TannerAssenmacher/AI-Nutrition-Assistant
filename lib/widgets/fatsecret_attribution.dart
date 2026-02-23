import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class FatSecretAttribution extends StatelessWidget {
  const FatSecretAttribution({
    super.key,
    this.showBadge = false,
    this.centered = true,
  });

  final bool showBadge;
  final bool centered;

  static final Uri _fatSecretUrl = Uri.parse('https://www.fatsecret.com');
  static const String _badgeImageUrl =
      'https://platform.fatsecret.com/api/static/images/powered_by_fatsecret.png';

  Future<void> _openFatSecret() async {
    final launched = await launchUrl(
      _fatSecretUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      throw Exception('Could not open fatsecret website');
    }
  }

  @override
  Widget build(BuildContext context) {
    final alignment = centered
        ? Alignment.center
        : AlignmentDirectional.centerStart;

    if (showBadge) {
      return Align(
        alignment: alignment,
        child: InkWell(
          onTap: _openFatSecret,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Image(
              image: const NetworkImage(_badgeImageUrl),
              errorBuilder: (_, __, ___) => TextButton(
                onPressed: _openFatSecret,
                child: const Text('Powered by fatsecret'),
              ),
              width: 146,
              height: 28,
              fit: BoxFit.contain,
              semanticLabel: 'Powered by fatsecret',
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: alignment,
      child: TextButton(
        onPressed: _openFatSecret,
        child: const Text('Powered by fatsecret'),
      ),
    );
  }
}
