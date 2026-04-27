import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/models/immeubles.dart';
import 'package:lacoloc_front/presentation/immeubles_list.dart';
import 'package:lacoloc_front/utils/search_delegate_tobar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<ImmeublesModel> listImmeubleCache = [];
  bool _isExpanded = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_isExpanded) {
          setState(() => _isExpanded = false);
          FocusScope.of(context).unfocus();
        }
      },
      child: Scaffold(
        drawer: Drawer(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                currentAccountPicture: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: Image.network(
                    'https://plus.unsplash.com/premium_vector-1719858611039-66c134efa74d?q=80&w=1480&auto=format&fit=crop',
                  ),
                ),
                accountName: const Text('Nome'),
                accountEmail: const Text('Email'),
              ),
            ],
          ),
        ),
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          centerTitle: true,
          title: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _isExpanded ? 400 : 220,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                if (_isExpanded)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onTap: () => setState(() => _isExpanded = true),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                prefixIcon: _searchQuery.isEmpty
                    ? const Icon(Icons.search, size: 20)
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 7,
                  horizontal: 15,
                ),
                // posiciona icone na direita se ha texto no campo de busca
                suffixIcon: _searchQuery.isNotEmpty
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Posiciona a lupa na direita
                          IconButton(
                            icon: const Icon(
                              Icons.search,
                              size: 18,
                              color: Colors.deepPurple,
                            ),
                            onPressed: () {
                              FocusScope.of(context).unfocus();
                              /*// Futuramente, criar a tabela para guardar o que é pesquisado no site, para ver tendencias.
                              Uma vez criado pode ser usado o codigo abaixo para fazer o insert na tabela*/

                              // Supabase.instance.client.from('search_logs').insert({'term': _searchQuery});
                            },
                          ),
                          // Botão de Limpar - Só aparece se houver texto
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          ),
                          const SizedBox(width: 5),
                        ],
                      )
                    : null,
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search_outlined),
              onPressed: () {
                showSearch(
                  context: context,
                  delegate: SearchDelgateTobar(immeubles: listImmeubleCache),
                );
              },
            ),
          ],
        ),
        body: ImmeublesList(
          filter: _searchQuery,
          onDataLoaded: (data) {
            listImmeubleCache = data;
          },
        ),
      ),
    );
  }
}
