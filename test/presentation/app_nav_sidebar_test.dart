import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitafrance/presentation/nav/app_nav_sidebar.dart';

void main() {
  group('NavChild — icône du sous-menu', () {
    test('l’icône fournie est respectée', () {
      final c = NavChild(
        label: 'Thèmes',
        onTap: () {},
        icon: Icons.star,
      );
      expect(c.effectiveIcon, Icons.star);
    });

    test('à défaut, elle est déduite du libellé', () {
      // Barre repliée, on ne voit que l'icône : un repli approximatif vaut
      // mieux qu'une icône neutre partout.
      expect(NavChild(label: 'Thèmes', onTap: () {}).effectiveIcon,
          Icons.palette_outlined);
      expect(NavChild(label: 'Emails administration', onTap: () {}).effectiveIcon,
          Icons.mail_outlined);
      expect(NavChild(label: 'Groupes', onTap: () {}).effectiveIcon,
          Icons.groups_outlined);
      expect(NavChild(label: 'Mes discussions', onTap: () {}).effectiveIcon,
          Icons.chat_bubble_outline);
    });

    test('un libellé inconnu retombe sur une icône neutre, pas au hasard', () {
      expect(NavChild(label: 'Zzz inconnu', onTap: () {}).effectiveIcon,
          Icons.subdirectory_arrow_right);
    });

    test('la déduction ignore la casse et les accents du libellé', () {
      expect(NavChild(label: 'THÈMES', onTap: () {}).effectiveIcon,
          Icons.palette_outlined);
    });
  });
}
