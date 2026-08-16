import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:habitafrance/data/cache/realtime_refresh_mixin.dart';
import 'package:habitafrance/data/datasources/auth_service.dart';
import 'package:habitafrance/data/datasources/messages.dart';
import 'package:habitafrance/data/models/demande_contact.dart';
import 'package:habitafrance/data/models/message.dart';
import 'package:habitafrance/data/models/profile_card_data.dart';
import 'package:habitafrance/presentation/widgets/user_profile_card.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_typography.dart';

/// Fil de discussion d'une demande de contact — **le même widget pour les deux
/// parties** (locataire et proprietaire) : le rôle ne change que l'interlocuteur
/// affiché, jamais les règles.
///
/// Le fil n'est ouvert qu'une fois la demande acceptée
/// (`DemandeContactModel.discussionOuverte`) ; sinon on affiche un bandeau
/// d'attente et le champ de saisie est masqué. C'est la RLS qui fait foi —
/// l'UI ne fait que la refléter.
///
/// Se rafraîchit tout seul via le Realtime (table `Messages`).
class ConversationView extends StatefulWidget {
  final DemandeContactModel demande;

  /// Fiche de l'interlocuteur, telle que filtrée par le serveur (RPC
  /// `demande_counterpart_profiles`). Le fil ne déduit plus l'identité de
  /// l'autre partie d'un embed : une demande de contact ne donne pas accès à sa
  /// ligne. Null = pas encore chargée → l'en-tête reste neutre.
  final ProfileCardData? interlocuteur;

  /// Fermer le fil (retour à la liste). Null = pas de bouton retour.
  final VoidCallback? onClose;

  /// Appelé après l'envoi réussi d'un message (ex. le propriétaire passe la
  /// demande au statut « répondu »).
  final VoidCallback? onSent;

  /// Actions supplémentaires dans l'en-tête, à droite (ex. « Ignorer »).
  final List<Widget>? headerActions;

  const ConversationView({
    super.key,
    required this.demande,
    this.interlocuteur,
    this.onClose,
    this.onSent,
    this.headerActions,
  });

  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView>
    with RealtimeRefreshMixin {
  final _composerCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  late Future<List<MessageModel>> _future;
  String? _uid;
  bool _sending = false;

  @override
  Set<String> get watchedEntities => const {'messages', 'demandes'};

  @override
  void initState() {
    super.initState();
    _uid = AuthService.currentUser?.id;
    _future = _load();
  }

  @override
  void didUpdateWidget(ConversationView old) {
    super.didUpdateWidget(old);
    if (old.demande.id != widget.demande.id) _reload();
  }

  @override
  void dispose() {
    _composerCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void onRealtimeChange() => _reload();

  /// `_load()` tourne HORS du setState (sinon le closure renverrait un Future).
  void _reload() {
    final f = _load();
    setState(() {
      _future = f;
    });
  }

  Future<List<MessageModel>> _load() async {
    final msgs = await MessagesDatasource.listByDemande(
      widget.demande.id,
      refresh: true,
    );
    // Ouvrir le fil vaut lecture : on efface la pastille côté destinataire.
    if (msgs.any((m) => !m.isRead && m.recipientId == _uid)) {
      await MessagesDatasource.markReadForDemande(widget.demande.id);
    }
    _scrollToBottomSoon();
    return msgs;
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final texte = _composerCtrl.text.trim();
    if (texte.isEmpty || _sending) return;

    final destinataire = widget.demande.interlocuteurId(_uid);
    if (destinataire == null) {
      _snack('Destinataire introuvable pour cette demande.');
      return;
    }

    setState(() => _sending = true);
    try {
      await MessagesDatasource.send(
        demandeId: widget.demande.id,
        recipientId: destinataire,
        body: texte,
      );
      _composerCtrl.clear();
      _reload();
      widget.onSent?.call();
    } catch (e) {
      // Ne pas avaler l'erreur : l'envoi a échoué, il faut le dire.
      _snack('Impossible d\'envoyer le message : $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.demande;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(d),
        if (!d.discussionOuverte) _bandeauEnAttente(),
        Expanded(
          child: FutureBuilder<List<MessageModel>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text('Erreur : ${snap.error}'),
                  ),
                );
              }
              final msgs = snap.data ?? const <MessageModel>[];
              if (msgs.isEmpty) return _vide(d);
              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: msgs.length,
                itemBuilder: (_, i) =>
                    _Bulle(message: msgs[i], isMine: msgs[i].isMine(_uid)),
              );
            },
          ),
        ),
        if (d.discussionOuverte) _composer(),
      ],
    );
  }

  /// Barre d'en-tête du fil : **avec qui** on parle et **à propos de quoi**.
  /// Sans elle, une conversation ouverte est un mur de bulles hors contexte —
  /// on affiche donc toujours l'interlocuteur, le bien (chambre · immeuble) et
  /// la date de la prise de contact.
  Widget _header(DemandeContactModel d) {
    final profil = widget.interlocuteur;
    final lieu = [
      if (d.chambreName != null) d.chambreName,
      if (d.immeubleName != null) d.immeubleName,
    ].whereType<String>().join(' · ');
    final depuis = DateFormat('dd/MM/yyyy').format(d.createdAt);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: AppColors.outline)),
      ),
      child: Row(
        children: [
          if (widget.onClose != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Retour à la liste',
                onPressed: widget.onClose,
              ),
            ),
          ProfileAvatar(nom: profil?.fullName, size: 40),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  profil?.fullName ?? 'Votre interlocuteur',
                  style: AppTypography.titleLg,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (lieu.isNotEmpty)
                  Text(
                    lieu,
                    style: AppTypography.labelSm
                        .copyWith(color: AppColors.primary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  'En contact depuis le $depuis',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ...?widget.headerActions,
        ],
      ),
    );
  }

  Widget _bandeauEnAttente() {
    final jeSuisLeProprio = _uid == widget.demande.proprietaireId;
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_clock, color: AppColors.onSurfaceVariant, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              jeSuisLeProprio
                  ? 'Acceptez la demande pour ouvrir la discussion avec ce locataire.'
                  : 'En attente de l\'acceptation du propriétaire. '
                        'Vous pourrez échanger des messages dès qu\'il aura accepté.',
              style: AppTypography.bodyMd,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vide(DemandeContactModel d) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 40,
            color: AppColors.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            d.discussionOuverte
                ? 'Aucun message pour l\'instant — écrivez le premier.'
                : 'La discussion n\'est pas encore ouverte.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _composer() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _composerCtrl,
              minLines: 1,
              maxLines: 5,
              maxLength: 4000,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(
                hintText: 'Écrire un message…',
                counterText: '',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton(
            onPressed: _sending ? null : _send,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 14,
              ),
            ),
            child: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

}

/// Une bulle de message. Les miennes à droite (couleur d'action), celles de
/// l'autre à gauche (surface neutre).
class _Bulle extends StatelessWidget {
  final MessageModel message;
  final bool isMine;

  const _Bulle({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final heure = DateFormat('dd/MM/yyyy HH:mm').format(message.createdAt);
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isMine ? AppColors.primary : AppColors.surfaceContainer,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.lg),
            topRight: const Radius.circular(AppRadius.lg),
            bottomLeft: Radius.circular(isMine ? AppRadius.lg : AppRadius.sm),
            bottomRight: Radius.circular(isMine ? AppRadius.sm : AppRadius.lg),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.body,
              style: AppTypography.bodyMd.copyWith(
                color: isMine ? AppColors.onPrimary : AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  heure,
                  style: AppTypography.labelSm.copyWith(
                    color: isMine
                        ? AppColors.onPrimary.withValues(alpha: .7)
                        : AppColors.onSurfaceVariant,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: AppColors.onPrimary.withValues(alpha: .7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
