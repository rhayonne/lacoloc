import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:habitafrance/data/datasources/payment_methods.dart';
import 'package:habitafrance/data/models/payment_methods.dart';
import 'package:habitafrance/presentation/widgets/app_button.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_typography.dart';
import 'package:habitafrance/utils/phone_field.dart';

/// Section **« Mes moyens de paiement »** de l'écran Mon Profil, commune au
/// propriétaire (comment il **reçoit** le loyer) et au locataire (comment il
/// préfère **payer**).
///
/// Trois moyens, dans l'ordre de ce qui sert vraiment : le **virement**
/// (l'essentiel du loyer en France), puis **Wero** (virement instantané,
/// ex-Lydia/Paylib) et **PayPal** pour les petits montants.
///
/// L'IBAN est vérifié par le **contrôle mod 97** avant enregistrement : une
/// faute de frappe sur un RIB envoie l'argent ailleurs, et l'erreur se découvre
/// trop tard. Le champ est refusé tant que la clé ne tombe pas juste.
class PaymentMethodsSection extends StatefulWidget {
  /// Ce que la personne fait de ces coordonnées — adapte le texte d'intro.
  final bool isLocataire;

  const PaymentMethodsSection({super.key, this.isLocataire = false});

  @override
  State<PaymentMethodsSection> createState() => _PaymentMethodsSectionState();
}

class _PaymentMethodsSectionState extends State<PaymentMethodsSection> {
  final _titulaireCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();
  final _bicCtrl = TextEditingController();
  final _paypalCtrl = TextEditingController();
  final _weroFormKey = GlobalKey<FormBuilderState>();
  String _telephoneWero = '';

  bool _weroActif = false;
  bool _paypalActif = false;

  bool _chargement = true;
  bool _enregistrement = false;
  String? _erreurIban;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _titulaireCtrl.dispose();
    _ibanCtrl.dispose();
    _bicCtrl.dispose();
    _paypalCtrl.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final fiche = await PaymentMethodsDatasource.getMine();
      if (!mounted || fiche == null) return;
      setState(() {
        _titulaireCtrl.text = fiche.titulaireCompte ?? '';
        _ibanCtrl.text = fiche.iban == null
            ? ''
            : PaymentMethods.formaterIban(fiche.iban!);
        _bicCtrl.text = fiche.bic ?? '';
        _telephoneWero = fiche.telephoneWero ?? '';
        _paypalCtrl.text = fiche.emailPaypal ?? '';
        _weroActif = fiche.weroActif;
        _paypalActif = fiche.paypalActif;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _chargement = false);
      _snack('Impossible de charger vos moyens de paiement : $e');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _enregistrer() async {
    final iban = _ibanCtrl.text.trim();
    // Un IBAN faux est pire qu'un IBAN absent : on bloque avant l'écriture.
    if (iban.isNotEmpty && !PaymentMethods.ibanValide(iban)) {
      setState(() => _erreurIban = 'IBAN invalide — vérifiez la saisie.');
      return;
    }
    setState(() {
      _erreurIban = null;
      _enregistrement = true;
    });

    try {
      final saved = await PaymentMethodsDatasource.save(
        PaymentMethods(
          userId: '', // réimposé par le datasource depuis la session
          titulaireCompte: _titulaireCtrl.text,
          iban: iban,
          bic: _bicCtrl.text,
          telephoneWero: _telephoneWero,
          weroActif: _weroActif,
          emailPaypal: _paypalCtrl.text,
          paypalActif: _paypalActif,
        ),
      );
      if (!mounted) return;
      // On réaffiche l'IBAN tel qu'il est stocké, groupé par 4.
      _ibanCtrl.text = saved.iban == null
          ? ''
          : PaymentMethods.formaterIban(saved.iban!);
      _snack('Moyens de paiement enregistrés');
    } catch (e) {
      _snack('Erreur lors de l\'enregistrement : $e');
    } finally {
      if (mounted) setState(() => _enregistrement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mes moyens de paiement', style: AppTypography.titleLg),
        const SizedBox(height: AppSpacing.sm),
        Text(
          widget.isLocataire
              ? 'Indiquez comment vous préférez régler votre loyer. Ces '
                    'coordonnées ne sont visibles que par vous.'
              : 'Indiquez comment vous souhaitez recevoir les loyers. Ces '
                    'coordonnées ne sont visibles que par vous.',
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Virement ────────────────────────────────────────────────────────
        _sousTitre('Coordonnées bancaires'),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _titulaireCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Titulaire du compte',
            hintText: 'Jean Dupont',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _ibanCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'IBAN',
            hintText: 'FR76 3000 1007 9412 3456 7890 185',
            errorText: _erreurIban,
            helperText: 'Vérifié automatiquement (clé de contrôle).',
          ),
          onChanged: (_) {
            if (_erreurIban != null) setState(() => _erreurIban = null);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _bicCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'BIC',
            hintText: 'BNPAFRPP',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Paiements instantanés ───────────────────────────────────────────
        _sousTitre('Paiements instantanés'),
        const SizedBox(height: AppSpacing.sm),
        _moyenActivable(
          titre: 'Wero',
          sousTitre: 'Virement instantané (ex-Lydia / Paylib)',
          actif: _weroActif,
          onChanged: (v) => setState(() => _weroActif = v),
          // `PhoneField` est un champ `flutter_form_builder` : il lui faut un
          // `FormBuilder` au-dessus, sinon il lève à la construction.
          champ: FormBuilder(
            key: _weroFormKey,
            child: PhoneField(
              name: 'wero_phone',
              labelText: 'Téléphone Wero',
              initialValue: _telephoneWero,
              onChanged: (v) => _telephoneWero = PhoneField.normalize(v) ?? '',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _moyenActivable(
          titre: 'PayPal',
          sousTitre: 'Pour les petits montants',
          actif: _paypalActif,
          onChanged: (v) => setState(() => _paypalActif = v),
          champ: TextField(
            controller: _paypalCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-mail PayPal',
              hintText: 'jean.dupont@exemple.com',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        Align(
          alignment: Alignment.centerLeft,
          child: AppButton.save(
            label: 'Enregistrer',
            onPressed: _enregistrement ? null : _enregistrer,
            isBusy: _enregistrement,
          ),
        ),
      ],
    );
  }

  Widget _sousTitre(String texte) => Text(
    texte.toUpperCase(),
    style: AppTypography.labelSm.copyWith(
      color: AppColors.onSurfaceVariant,
      letterSpacing: 1.2,
    ),
  );

  /// Un moyen de paiement = un interrupteur + son champ, replié tant qu'il est
  /// désactivé (on ne demande pas un numéro pour un service qu'on n'utilise
  /// pas).
  Widget _moyenActivable({
    required String titre,
    required String sousTitre,
    required bool actif,
    required ValueChanged<bool> onChanged,
    required Widget champ,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre, style: AppTypography.labelMd),
                    Text(
                      sousTitre,
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Switch(value: actif, onChanged: onChanged),
            ],
          ),
          if (actif) ...[const SizedBox(height: AppSpacing.md), champ],
        ],
      ),
    );
  }
}
