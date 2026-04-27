import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/models/immeubles.dart';

class SearchDelgateTobar extends SearchDelegate {
  // 1. Criamos uma variável para receber a lista local
  final List<ImmeublesModel> immeubles;

  SearchDelgateTobar({required this.immeubles});

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

  // 2. Filtramos a lista local baseada na 'query'
  @override
  Widget buildResults(BuildContext context) {
    final results = immeubles
        .where((item) => item.nome.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return _buildList(results);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = immeubles
        .where((item) => item.nome.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return _buildList(suggestions);
  }

  // Função auxiliar para não repetir código de design
  Widget _buildList(List<ImmeublesModel> list) {
    if (list.isEmpty) return const Center(child: Text("Aucun résultat."));

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) => ListTile(
        title: Text(list[index].nome),
        onTap: () =>
            close(context, list[index]), // Fecha a busca retornando o item
      ),
    );
  }
}
