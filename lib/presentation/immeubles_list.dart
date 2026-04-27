import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/immeubles.dart';

class ImmeublesList extends StatefulWidget {
  const ImmeublesList({super.key});

  @override
  State<ImmeublesList> createState() => _ImmeublesListState();
}

class _ImmeublesListState extends State<ImmeublesList> {
  late Future<List<ImmeublesModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _getImmeubles();
  }

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
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 450,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 380, // Altura fixa de cada card (opcional)
          ),
          itemCount: listImmeubles.length,
          itemBuilder: (context, index) {
            final immeuble = listImmeubles[index];

            // Usando Card para ficar visualmente melhor em Grid
            return Card(
              clipBehavior: Clip.antiAlias,
              elevation: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      'https://imgs.search.brave.com/ceJUDCQ4TFJvaMOFbwlrFM_o8y3HWToF21feC4fOb_s/rs:fit:860:0:0:0/g:ce/aHR0cHM6Ly93d3cu/bG9kZ2lzLmNvbS9w/aG90b3MvbHBhL2Fw/LzI2MDA4L29yYW5n/ZS9hcGFydGFtZW50/by1ydWUtZXNxdWly/b2wtcGFyaXMtMTMt/LXBpY0wuanBnP3Y9/MTc0MTM0NzY1Ng',
                      fit: BoxFit.cover,
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsetsGeometry.fromLTRB(12, 12, 12, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          immeuble.nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          immeuble.description ?? ' Sans description',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  Spacer(),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Text('data');
                        },
                        label: Text('Voir détails'),
                        icon: Icon(Icons.remove_red_eye, size: 18),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
