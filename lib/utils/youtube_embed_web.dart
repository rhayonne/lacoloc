import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Vues déjà enregistrées (le registre est global et ne doit pas être doublé).
final Set<String> _registered = {};

/// Web : intègre la vidéo YouTube via une iframe `youtube.com/embed/<id>`.
/// [id] est déjà validé (11 caractères) par `parseYoutubeId` → pas d'injection
/// possible dans le `src`.
Widget buildYoutubeEmbed(String id, {double height = 220}) {
  final viewType = 'yt-embed-$id';
  if (!_registered.contains(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final el = web.HTMLIFrameElement()
        ..src = 'https://www.youtube.com/embed/$id'
        ..allow =
            'accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture'
        ..allowFullscreen = true;
      el.style
        ..border = 'none'
        ..width = '100%'
        ..height = '100%';
      return el;
    });
    _registered.add(viewType);
  }
  return SizedBox(height: height, child: HtmlElementView(viewType: viewType));
}
