import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade100, width: 1),
            ),
          ),
        ),
        leading: Icon(Icons.menu, color: colorScheme.primary),
        title: Text(
          'ChezSoi',
          style: textTheme.displaySmall?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.primaryContainer,
                  width: 2,
                ),
                image: const DecorationImage(
                  image: NetworkImage(
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuDUyS4rqnq2bF1t0rWJhBMYwTfKCjkdiRshMshQZDixFkgKatEZQSqMMD3BA8RWXor5B126wy-AwaVNkcQoLNil38LGOLvhKV0rR-BLPckW3c6TKHscq8jO6WGZxxYQ5Wz7q9CQFxmZAYN8Q8rlby6alcLSAySy8hW3c0lTMskyMRoLwzEHrdSS23UoaQtVkel-Dbj9d5ea_NOoOY81yq0lc6tixpqI209vzIpaOX4Qg9Qt85vvIr9b-sf19LeXn3vooma9ofkzqvE',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Comment souhaitez-vous utiliser ChezSoi ?',
                style: textTheme.displayLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontSize: 32, // Adjusted for mobile view
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Sélectionnez votre profil pour une expérience personnalisée.',
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Locataire Card
              _buildProfileCard(
                context: context,
                imageUrl:
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuDwBLO0ZQg-CU_4Xd5h0YVGR-hKMRq9TycgeaDK17ucEr_PChNkoteUKHYVCXlQFJY5sPa2iSFzuMnGPEXvQWKYkqWCPYbdHQ_XBB-9jhx9mxdul9bo4XHQWHVUiDChPezeUKDsTqxz4vwwUhE3wReHDB9Q3G3OFzDiC7JQj6Jtnzio3y70KjK4i60P2Zdll5H0jnR8TqSarQlXZrzULdxF47UuyrXcWJ8-2PhJ5bU2r5iIHudiJN3M_kzWDm9wkPXcS1vo1sefqOw',
                tagText: 'Recherche Permanente',
                tagColor: colorScheme.primaryContainer,
                tagTextColor: colorScheme.onPrimaryContainer,
                icon: Icons.home,
                title: 'Locataire',
                description:
                    'Je cherche un logement pour y vivre avec des contrats annuels sécurisés et sans bureaucratie excessive.',
                actionText: 'Entrer comme Locataire',
              ),

              const SizedBox(height: 24),

              // Propriétaire Card
              _buildProfileCard(
                context: context,
                imageUrl:
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuAVRdvKGt-SIJICIbOGXNma9Pma--XUQkaIb6R-8_It-o0EPwfLlfC-L45X4USZ9pltInIQ-rmZuqXL5hRINGW7pGEgfMzPjLiBEq7zB_Nw-bhAhMVB_gqfHI7TgQQ8oFS1mGVUPH0k7EmaJf-Z2NKwRwgHY7VwE8YwJvvIoZ5_zMrllKDy4fXTt2yV6qN5hU8hleWCqEFqj6CFNfV9Kisu325HsB_Htcn7t6lgawNP7wPxXBbFNk_zOMSL2O6xwFiq0cKrFaDZICI',
                tagText: "Gestion d'Actifs",
                tagColor: colorScheme.secondaryContainer,
                tagTextColor: colorScheme.onSecondaryContainer,
                icon: Icons.monitor_heart,
                title: 'Propriétaire',
                description:
                    'Je souhaite lister mon bien pour des locataires vérifiés et gérer des contrats de longue durée.',
                actionText: 'Entrer comme Propriétaire',
              ),

              const SizedBox(height: 48),

              // Info Section
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoItem(
                    context: context,
                    icon: Icons.verified_user_outlined,
                    title: 'Dossier Sécurisé',
                    description: 'Protection totale de vos documents.',
                  ),
                  _buildInfoItem(
                    context: context,
                    icon: Icons.calendar_today_outlined,
                    title: 'Contrat Annuel',
                    description: 'Stabilité pour votre nouvelle demeure.',
                  ),
                  _buildInfoItem(
                    context: context,
                    icon: Icons.support_agent_outlined,
                    title: 'Support Local',
                    description: 'Assistance en français et en portugais.',
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: Colors.grey.shade400,
          selectedLabelStyle: textTheme.labelSmall?.copyWith(fontSize: 11),
          unselectedLabelStyle: textTheme.labelSmall?.copyWith(fontSize: 11),
          items: [
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _selectedIndex == 0
                      ? colorScheme.primary.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.search),
              ),
              label: 'Explorer',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _selectedIndex == 1
                      ? colorScheme.primary.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.description_outlined),
              ),
              label: 'Contrats',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _selectedIndex == 2
                      ? colorScheme.primary.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.favorite_border),
              ),
              label: 'Favoris',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _selectedIndex == 3
                      ? colorScheme.primary.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_outline),
              ),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard({
    required BuildContext context,
    required String imageUrl,
    required String tagText,
    required Color tagColor,
    required Color tagTextColor,
    required IconData icon,
    required String title,
    required String description,
    required String actionText,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.network(imageUrl, fit: BoxFit.cover),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.6),
                            Colors.transparent,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: tagColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        tagText,
                        style: textTheme.labelSmall?.copyWith(
                          color: tagTextColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: textTheme.displaySmall?.copyWith(
                            color: colorScheme.onSurface,
                            fontSize: 24,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      description,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Text(
                          actionText,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: colorScheme.primary),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
