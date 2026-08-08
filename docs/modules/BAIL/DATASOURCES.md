# Bail - Datasources

Não há tabela 'Bail' no DB. É gerado em memória a partir de EDL.

```dart
BailPdfData.fromEdl(edl)          // Carrega dados do bail
BailPdfBuilder.build(bailData)    // Gera PDF
RecettesDatasource.generateFromBail(edlId)  // Cria échéances
```

**Colunas adicionadas ao EDL**:
- `bail_avec_garant` (bool)
- `bail_locataire_signature_url` (doc:*)
- `bail_proprietaire_signature_url` (doc:*)
- `bail_locataire_signed_at` (timestamp)
- `bail_proprietaire_signed_at` (timestamp)
