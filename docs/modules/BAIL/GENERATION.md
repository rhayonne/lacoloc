# Geração de Bail

Gerado a partir de EDL finalizado + aceito.

## Fluxo
1. EDL entrée finalizado
2. Locataire aceita + assina
3. Proprietaire clica 'Générer bail'
4. PDF do bail é criado via BailPdfBuilder
5. Ambos assinam (colunas bail_*_signature_url)
6. Échéances são geradas automaticamente

**Ver**: BailPdfData, BailPdfBuilder, RecettesDatasource.generateFromBail