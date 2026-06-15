import 'package:flutter_test/flutter_test.dart';
import 'package:lacoloc_front/data/permissions/permissions_service.dart';

void main() {
  // O PermissionsService é um singleton. Fazemos clear() antes de cada teste
  // para garantir estado limpo (sem depender de Supabase).
  setUp(() {
    PermissionsService.instance.clear();
  });

  group('PermissionsService', () {
    group('estado inicial após clear()', () {
      test('isLoaded é false após clear', () {
        expect(PermissionsService.instance.isLoaded, isFalse);
      });

      test('can retorna false para qualquer chave após clear', () {
        expect(PermissionsService.instance.can(Perm.immeublesCreate), isFalse);
        expect(PermissionsService.instance.can(Perm.edlCreate), isFalse);
        expect(PermissionsService.instance.can(Perm.usersManage), isFalse);
      });

      test('canAny retorna false para qualquer conjunto após clear', () {
        expect(
          PermissionsService.instance.canAny([
            Perm.immeublesCreate,
            Perm.immeublesEdit,
          ]),
          isFalse,
        );
      });
    });

    group('revision', () {
      test('incrementa a cada clear()', () {
        final before = PermissionsService.instance.revision.value;
        PermissionsService.instance.clear();
        expect(
          PermissionsService.instance.revision.value,
          greaterThan(before),
        );
      });
    });

    group('Perm — constantes de chaves', () {
      test('todas as chaves são strings não vazias', () {
        final allKeys = [
          Perm.immeublesCreate,
          Perm.immeublesEdit,
          Perm.immeublesDelete,
          Perm.chambresCreate,
          Perm.chambresEdit,
          Perm.chambresDelete,
          Perm.piecesCreate,
          Perm.piecesEdit,
          Perm.piecesDelete,
          Perm.inventaireCreate,
          Perm.inventaireEdit,
          Perm.inventaireDelete,
          Perm.visitesCreate,
          Perm.visitesEdit,
          Perm.visitesDelete,
          Perm.edlCreate,
          Perm.edlEdit,
          Perm.edlDelete,
          Perm.edlFinaliser,
          Perm.edlAvenant,
          Perm.edlAddition,
          Perm.edlAccepter,
          Perm.facturesCreate,
          Perm.facturesEdit,
          Perm.facturesDelete,
          Perm.fournisseursCreate,
          Perm.fournisseursEdit,
          Perm.fournisseursDelete,
          Perm.locatairesInvite,
          Perm.locatairesView,
          Perm.demandesView,
          Perm.demandesManage,
          Perm.usersManage,
          Perm.permissionsManage,
          Perm.entreprisesManage,
          Perm.referenceManage,
          Perm.entrepriseComptes,
        ];

        for (final key in allKeys) {
          expect(key, isNotEmpty, reason: 'Chave $key não deve ser vazia');
        }
      });

      test('as chaves seguem o padrão "domínio.ação"', () {
        final keys = [
          Perm.immeublesCreate,
          Perm.edlEdit,
          Perm.facturesDelete,
          Perm.locatairesInvite,
          Perm.entrepriseComptes,
        ];

        for (final key in keys) {
          expect(
            key.contains('.'),
            isTrue,
            reason: 'Chave "$key" deve conter "."',
          );
        }
      });

      test('chaves de imóveis têm prefixo correto', () {
        expect(Perm.immeublesCreate, startsWith('immeubles.'));
        expect(Perm.immeublesEdit, startsWith('immeubles.'));
        expect(Perm.immeublesDelete, startsWith('immeubles.'));
      });

      test('chaves de EDL têm prefixo correto', () {
        expect(Perm.edlCreate, startsWith('edl.'));
        expect(Perm.edlEdit, startsWith('edl.'));
        expect(Perm.edlDelete, startsWith('edl.'));
        expect(Perm.edlFinaliser, startsWith('edl.'));
        expect(Perm.edlAvenant, startsWith('edl.'));
        expect(Perm.edlAddition, startsWith('edl.'));
        expect(Perm.edlAccepter, startsWith('edl.'));
      });

      test('todas as chaves são únicas', () {
        final all = [
          Perm.immeublesCreate, Perm.immeublesEdit, Perm.immeublesDelete,
          Perm.chambresCreate, Perm.chambresEdit, Perm.chambresDelete,
          Perm.piecesCreate, Perm.piecesEdit, Perm.piecesDelete,
          Perm.inventaireCreate, Perm.inventaireEdit, Perm.inventaireDelete,
          Perm.visitesCreate, Perm.visitesEdit, Perm.visitesDelete,
          Perm.edlCreate, Perm.edlEdit, Perm.edlDelete,
          Perm.edlFinaliser, Perm.edlAvenant, Perm.edlAddition, Perm.edlAccepter,
          Perm.facturesCreate, Perm.facturesEdit, Perm.facturesDelete,
          Perm.fournisseursCreate, Perm.fournisseursEdit, Perm.fournisseursDelete,
          Perm.locatairesInvite, Perm.locatairesView,
          Perm.demandesView, Perm.demandesManage,
          Perm.usersManage, Perm.permissionsManage,
          Perm.entreprisesManage, Perm.referenceManage,
          Perm.entrepriseComptes,
        ];

        expect(all.toSet().length, all.length,
            reason: 'Existem chaves de permissão duplicadas');
      });
    });
  });
}
