# Diagramas — La Coloc

Documentação visual (MermaidJS) de como o sistema funciona. Renderiza no GitHub e em
qualquer visualizador compatível com Mermaid.

| # | Arquivo | Conteúdo |
|---|---|---|
| 01 | [01_casos_de_uso.md](01_casos_de_uso.md) | Casos de uso por ator (Visiteur, Locataire, Propriétaire, Super Admin) |
| 02 | [02_modelo_de_dados.md](02_modelo_de_dados.md) | ERD completo (todas as tabelas, relações e notas de implementação) |
| 03 | [03_arquitetura.md](03_arquitetura.md) | Camadas, datasources, Supabase, edge functions, responsividade |
| 04 | [04_navegacao.md](04_navegacao.md) | Rotas, dashboards (8 seções proprietaire / 4 super admin), auth, demande contact |
| 05 | [05_componentes_ui.md](05_componentes_ui.md) | Hierarquia de widgets, padrões responsivos, campos padronizados |
| 06 | [06_etat_des_lieux.md](06_etat_des_lieux.md) | Ciclo de vida do EDL (criar → finaliser → assinar), observations, vision générale |
| 07 | [07_convite_e_edge_functions.md](07_convite_e_edge_functions.md) | Convite de locataire, edge functions, RPCs |
| 08 | [08_gestion_inventaire.md](08_gestion_inventaire.md) | Gestion Immobilière, Pièces, Inventaire, Agenda Visites |

> Especificação da API (objetos + endpoints Supabase): [`../docs/openapi.yaml`](../docs/openapi.yaml).
