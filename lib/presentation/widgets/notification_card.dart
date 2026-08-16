import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:habitafrance/data/models/notification_model.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_typography.dart';
import 'package:habitafrance/utils/media_embed.dart';

/// Carte de notification réutilisable (Interactions + Vue générale).
class NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;

  const NotificationCard({super.key, required this.notification, this.onTap});

  IconData get _icon => switch (notification.type) {
        'edl_accepte' => Icons.verified_outlined,
        'admin_message' => Icons.campaign_outlined,
        'nouvelle_demande' => Icons.person_add_alt_outlined,
        'nouveau_proprietaire' => Icons.how_to_reg_outlined,
        _ => Icons.notifications_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    final dateStr = DateFormat('dd/MM/yyyy à HH:mm').format(
      notification.createdAt.toLocal(),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderMd,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: unread
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.borderMd,
          border: Border.all(
            color: unread
                ? AppColors.primary.withValues(alpha: 0.35)
                : AppColors.outlineVariant,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon, size: 20, color: AppColors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.title,
                      style: AppTypography.titleLg.copyWith(
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                      )),
                  if (notification.body != null &&
                      notification.body!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    // Rendu Markdown (sans HTML brut → pas d'injection XSS).
                    MarkdownBody(
                      data: notification.body!,
                      onTapLink: (text, href, title) {
                        if (href != null) {
                          launchUrl(Uri.parse(href),
                              mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ],
                  if (notification.mediaType != null &&
                      notification.mediaUrl != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    MessageMediaView(
                      mediaType: notification.mediaType,
                      mediaUrl: notification.mediaUrl,
                      height: 200,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Text(dateStr,
                      style: AppTypography.labelSm
                          .copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            if (unread)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4, left: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
