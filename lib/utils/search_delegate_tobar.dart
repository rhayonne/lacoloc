import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

/// Busca local entre quartos já carregados em cache.
/// Retorna a Chambre selecionada via `close`.
class SearchDelgateTobar extends SearchDelegate<ChambreModel?> {
  final List<ChambreModel> chambres;

  SearchDelgateTobar({required this.chambres})
      : super(searchFieldLabel: 'Rechercher une chambre...');

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear_outlined),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildList(context, _filter());

  @override
  Widget buildSuggestions(BuildContext context) =>
      _buildList(context, _filter());

  List<ChambreModel> _filter() {
    final q = query.toLowerCase();
    return chambres.where((c) {
      return c.roomName.toLowerCase().contains(q) ||
          (c.immeubleName?.toLowerCase().contains(q) ?? false) ||
          (c.immeubleAddress?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Widget _buildList(BuildContext context, List<ChambreModel> list) {
    if (list.isEmpty) {
      return Center(
        child: Text("Aucun résultat.", style: AppTypography.bodyMd),
      );
    }
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final c = list[index];
        return ListTile(
          leading: const Icon(Icons.bed_outlined),
          title: Text(c.roomName, style: AppTypography.titleLg),
          subtitle: c.immeubleName != null
              ? Text(c.immeubleName!, style: AppTypography.bodyMd)
              : null,
          onTap: () {
            close(context, c);
            Navigator.of(context).pushNamed('/chambre', arguments: c.id);
          },
        );
      },
    );
  }
}
