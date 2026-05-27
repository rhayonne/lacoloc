# docs/ — La Coloc

## `openapi.yaml`

Especificação OpenAPI 3.0 da superfície de API Supabase consumida pelo app
(`lacoloc_front`). Cobre **todos os objetos de dados** do código (tabelas + modelos Dart,
em `components/schemas`) e os endpoints de **PostgREST**, **RPC**, **Edge Functions**,
**Auth** e **Storage**.

### Como visualizar

- **Swagger Editor online**: cole o conteúdo em https://editor.swagger.io
- **Redocly CLI**:
  ```bash
  npx @redocly/cli preview-docs docs/openapi.yaml
  ```
- **VS Code**: extensão "OpenAPI (Swagger) Editor" → abrir `docs/openapi.yaml`
- **Gerar HTML estático**:
  ```bash
  npx @redocly/cli build-docs docs/openapi.yaml -o docs/api.html
  ```

### Convenções

- `*Write` = corpo de inserção/atualização (espelha `Model.toInsert()`).
- Os embeds PostgREST (joins) estão descritos no campo `description` de cada path
  e refletem as constantes `_select` dos datasources.
- A autenticação é `apikey` (anon) + `Authorization: Bearer <jwt>`; o acesso real
  é regido por **RLS** no PostgreSQL.

> Diagramas de comportamento/arquitetura: [`../diagrams/`](../diagrams/).
