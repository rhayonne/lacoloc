# Diagramas — Super Loc

Documentação visual (MermaidJS) de como o sistema funciona. Renderiza no GitHub e em
qualquer visualizador compatível com Mermaid.

| # | Arquivo | Conteúdo |
|---|---|---|
| 01 | [01_casos_de_uso.md](01_casos_de_uso.md) | Casos de uso por ator (Visiteur, Locataire, Propriétaire, Super Admin) — menus `AppNavSidebar`, bail/garants/finances, admin EDL/Communication/Maintenance |
| 02 | [02_modelo_de_dados.md](02_modelo_de_dados.md) | ERD completo (todas as tabelas, relações e notas de implementação) |
| 03 | [03_arquitetura.md](03_arquitetura.md) | Camadas, datasources, Supabase, edge functions, responsividade |
| 04 | [04_navegacao.md](04_navegacao.md) | Rotas, dashboards (proprietaire · super admin · locataire), auth, demande contact |
| 05 | [05_componentes_ui.md](05_componentes_ui.md) | Hierarquia de widgets, padrões responsivos, campos padronizados |
| 06 | [06_etat_des_lieux.md](06_etat_des_lieux.md) | Ciclo de vida do EDL (criar → finaliser → assinar), observations, vision générale, **aba Vétusté** |
| 07 | [07_convite_e_edge_functions.md](07_convite_e_edge_functions.md) | Convite de locataire, edge functions, RPCs |
| 08 | [08_gestion_inventaire.md](08_gestion_inventaire.md) | Gestion Immobilière, Pièces, Inventaire (**+ champs vétusté**), cadastro immeuble (draft, électroménager, charges), Agenda Visites |
| 09 | [09_immeuble_vers_bail.md](09_immeuble_vers_bail.md) | Caminho completo Immeuble → Bail : pré-requisitos, Configuration du bail (avenant/caution/garant), assinaturas `bail_*` das 2 partes, échéances geradas, impressão |
| 10 | [10_parcours_location.md](10_parcours_location.md) | **Fluxo de locação detalhado** : criação immeuble→chambres (draft), fases EDL→bail→échéances, résiliation/sortie/avenant, casos de uso, sequência, estados |
| 11 | [11_vetuste.md](11_vetuste.md) | **Vétusté** : barème, détection entrée→sortie, décompte de réparations locatives, PDF, à recevoir (Finances) |
| 12 | [12_finances_recettes.md](12_finances_recettes.md) | **Finances** : factures (TVA) + recettes (loyer/caution/vétusté), ciclo de vida do à recevoir, RLS locataire |
| 13 | [13_notifications.md](13_notifications.md) | **Notifications & badges** : eventos, RPC `notify_edl_*`, Realtime, pastilhas de menu |
| 14 | [14_signatures.md](14_signatures.md) | **Signatures** : flux proprio/locataire, materializeForEdl, `signature_audit`, stockage privé (`doc:`/PrivateImage) |
| 15 | [15_communication.md](15_communication.md) | **Communication** (super admin) : diffusion `admin_broadcast_notification`, audiences, média Markdown/YouTube |

> Especificação da API (objetos + endpoints Supabase): [`../docs/openapi.yaml`](../docs/openapi.yaml).
