import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/immeubles.dart';

class ImmeublesList extends StatefulWidget {
  const ImmeublesList({super.key});

  @override
  State<ImmeublesList> createState() => _ImmeublesListState();
}

class _ImmeublesListState extends State<ImmeublesList> {
  // carrega os imoveis somente uma vez e recebe os imoveis do get
  late Future<List<ImmeublesModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _getImmeubles();
  }

  // busca os imveis
  Future<List<ImmeublesModel>> _getImmeubles() async {
    final response = await Supabase.instance.client.from('Immeubles').select();
    return (response as List)
        .map((item) => ImmeublesModel.fromMap(item))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ImmeublesModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final listImmeubles = snapshot.data ?? [];

        if (listImmeubles.isEmpty) {
          return const Center(child: Text("Il n'y a pas d'immeubles"));
        }

        return ListView.builder(
          // Como este widget será usado dentro de uma Column na Home,
          // certifique-se de que a Home use Expanded() em volta dele.
          itemCount: listImmeubles.length,
          itemBuilder: (context, index) {
            final immeuble = listImmeubles[index];
            return ListTile(
              leading: const Icon(Icons.home_work),
              title: Text(immeuble.nome),
              subtitle: Text(
                immeuble.description ?? "L'immeuble n'a pas de description",
              ),
              trailing: Text(immeuble.id.toString()),
            );
          },
        );
      },
    );
  }
} // Fechamento correto da classe State
