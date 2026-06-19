import 'package:flutter_test/flutter_test.dart';
import 'package:lacoloc_front/data/datasources/storage_service.dart';

/// Teste des helpers purs de StorageService (sans accès réseau/Supabase) :
/// distinction référence privée (`doc:`) vs URL publique, et extraction de
/// chemin. Ces helpers pilotent l'affichage (PrivateImage) et la résolution
/// d'URL signée pour le bucket privé `documents`.
void main() {
  group('StorageService — références', () {
    test('isPrivateRef : true pour une référence doc:', () {
      expect(
        StorageService.isPrivateRef('doc:etat_de_lieux/42/murs/uid/1.png'),
        isTrue,
      );
      expect(StorageService.isPrivateRef('doc:signatures/uid/1.png'), isTrue);
    });

    test('isPrivateRef : false pour une URL publique / héritée', () {
      expect(
        StorageService.isPrivateRef(
          'https://x.supabase.co/storage/v1/object/public/photos/chambres/uid/1.png',
        ),
        isFalse,
      );
      expect(StorageService.isPrivateRef(''), isFalse);
    });

    test('pathOfRef : retire le préfixe doc: pour une référence privée', () {
      expect(
        StorageService.pathOfRef('doc:etat_de_lieux/42/murs/uid/1.png'),
        'etat_de_lieux/42/murs/uid/1.png',
      );
    });

    test('pathOfRef : renvoie la valeur telle quelle pour une URL publique', () {
      const url =
          'https://x.supabase.co/storage/v1/object/public/photos/chambres/uid/1.png';
      expect(StorageService.pathOfRef(url), url);
    });

    test('docPrefix est cohérent avec isPrivateRef/pathOfRef', () {
      const path = 'etat_de_lieux/7/general/uid/2.png';
      final ref = '${StorageService.docPrefix}$path';
      expect(StorageService.isPrivateRef(ref), isTrue);
      expect(StorageService.pathOfRef(ref), path);
    });
  });
}
