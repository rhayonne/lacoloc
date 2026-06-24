import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Repli (non-web) : miniature YouTube cliquable qui ouvre la vidéo.
/// Sur le web, l'implémentation `youtube_embed_web.dart` intègre une iframe.
Widget buildYoutubeEmbed(String id, {double height = 220}) {
  return _YoutubeThumb(id: id, height: height);
}

class _YoutubeThumb extends StatelessWidget {
  final String id;
  final double height;
  const _YoutubeThumb({required this.id, required this.height});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => launchUrl(
        Uri.parse('https://www.youtube.com/watch?v=$id'),
        mode: LaunchMode.externalApplication,
      ),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://img.youtube.com/vi/$id/hqdefault.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(color: Colors.black12),
            ),
            const Center(
              child: Icon(Icons.play_circle_fill,
                  size: 56, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
