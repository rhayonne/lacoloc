# 📚 Documentação Modularizada - habitafrance

## O que é?

Documentação dividida por **módulo/domínio** do sistema. Cada módulo tem sua própria pasta com documentos específicos.

**Benefício**: Ao trabalhar num módulo, carrego só seu contexto (não toda a aplicação).

---

## 📂 Estrutura de Módulos

```
docs/modules/
├── MODULE_OVERVIEW.md                    ← Você está aqui
│
├── EDL/                                  (État des Lieux - Formulários)
│   ├── README.md                         (Overview + tipos de EDL)
│   ├── DATASOURCES.md                    (EtatDesLieuxDatasource, EdlDetailsDatasource)
│   ├── DATA_MODEL.md                     (Tabelas: etat_de_lieux, observations, preneurs, etc)
│   ├── FLOWS.md                          (Criar, editar, finaliser, sortie, avenant)
│   ├── RLS.md                            (Políticas de Row-Level Security)
│   └── CONVENTIONS.md                    (Padrões específicos do EDL)
│
├── MESSAGERIE/                           (Chat + Demandes de Contact)
│   ├── README.md                         (Overview + refonte 2026-07)
│   ├── DATASOURCES.md                    (MessagesDatasource, DemandesContactDatasource)
│   ├── DATA_MODEL.md                     (Tabelas: Demandes_Contact, Messages)
│   ├── FLOWS.md                          (Workflow: demanda → accepter → chat)
│   └── RLS.md                            (Políticas de segurança)
│
├── BAIL/                                 (Contrato de Aluguel)
│   ├── README.md                         (Overview + assinaturas separadas)
│   ├── GENERATION.md                     (Geração a partir de EDL)
│   ├── SIGNATURES.md                     (Assinatura do locataire + proprietaire)
│   ├── RESOLUTION.md                     (Rescisão + acerto de caution)
│   └── DATASOURCES.md                    (EtatDesLieuxDatasource + related)
│
├── VETUSTE/                              (Vétusté - Desgaste)
│   ├── README.md                         (Overview + Option B)
│   ├── CALCULATION.md                    (Cálculo de abatement)
│   ├── DETECTION.md                      (Auto-detecção na sortie)
│   ├── DATASOURCES.md                    (VetusteDatasource, helpers)
│   └── PDF.md                            (Geração de decompte PDF)
│
├── IMMEUBLES/                            (Imóveis)
│   ├── README.md                         (Overview + tipos)
│   ├── DATASOURCES.md                    (ImmeublesDatasource)
│   ├── DATA_MODEL.md                     (Tabela Immeubles)
│   ├── COMMON_PARTS.md                   (Geração automática de pièces)
│   └── CHARGES.md                        (Charges locatives)
│
├── CHAMBRES/                             (Quartos)
│   ├── README.md                         (Overview)
│   ├── DATASOURCES.md                    (ChambresDatasource)
│   ├── DATA_MODEL.md                     (Tabela Chambres)
│   ├── SEARCH.md                         (Busca pública + filtros)
│   └── AVAILABILITY.md                   (Disponibilidade + RPC)
│
├── INVENTORY/                            (Inventário de Móveis)
│   ├── README.md                         (Overview)
│   ├── DATASOURCES.md                    (InventaireDatasource)
│   ├── DATA_MODEL.md                     (Tabela Inventaire)
│   └── CATEGORIZATION.md                 (Meubles_Reference + categorias)
│
├── FINANCES/                             (Recettes + Facturas)
│   ├── README.md                         (Overview)
│   ├── DATASOURCES.md                    (RecettesDatasource, FacturesDatasource)
│   ├── RECETTES.md                       (Échéances de loyer + caution)
│   ├── GENERATION.md                     (Auto-geração a partir do bail)
│   └── DECOMPTE.md                       (Decompte de réparations - vétusté)
│
├── GARANTS/                              (Garants - Avalistas)
│   ├── README.md                         (Overview)
│   ├── DATASOURCES.md                    (GarantsDatasource)
│   ├── DATA_MODEL.md                     (Tabela Garants + linking)
│   └── AUTOMATION.md                     (Auto-linking ao bail)
│
├── AUTH/                                 (Autenticação + Permissões)
│   ├── README.md                         (Overview + tipos de usuário)
│   ├── USER_TYPES.md                     (locataire, proprietaire, super_admin)
│   ├── PERMISSIONS.md                    (System de permissões + Permissions_Reference)
│   ├── DATASOURCES.md                    (AuthService, UserManagementDatasource)
│   └── EDGE_FUNCTIONS.md                 (invite-locataire, manage-user-auth, delete-account)
│
├── CACHE_REALTIME/                       (Cache + Realtime)
│   ├── README.md                         (Overview)
│   ├── DATACACHE.md                      (DataCache + TTL + dedup)
│   ├── REALTIME_SERVICE.md               (Supabase Realtime + RLS)
│   ├── INTEGRATION.md                    (Como integrar novo datasource)
│   └── PERFORMANCE.md                    (Otimizações, list_changes lento)
│
├── UI/                                   (Tema + Componentes)
│   ├── README.md                         (Overview + idioma)
│   ├── THEME_SYSTEM.md                   (Paletas dinâmicas 3 cores)
│   ├── BUTTON_SYSTEM.md                  (AppButton + AppButtonSizes)
│   ├── FORM_COMPONENTS.md                (FormPageHeader, FormHeaderActions, validators)
│   ├── RESPONSIVE.md                     (LayoutBuilder, breakpoints, fiches détail)
│   └── CONVENTIONS.md                    (Padrões globais)
│
├── STORAGE/                              (Buckets: photos + documents)
│   ├── README.md                         (Overview + 2 buckets)
│   ├── BUCKETS.md                        (photos públicas vs documents privados)
│   ├── DATASOURCES.md                    (StorageService)
│   └── SECURITY.md                       (RLS no storage, URLs assinadas)
│
├── NOTIFICATIONS/                        (Notificações In-App)
│   ├── README.md                         (Overview)
│   ├── DATASOURCES.md                    (NotificationsDatasource)
│   ├── DATA_MODEL.md                     (Tabela Notifications)
│   ├── TYPES.md                          (Tipos: edl_accepte, edl_addition, nouvelle_demande, etc)
│   └── DASHBOARD.md                      (Seção Notifications no dashboard)
│
├── ADMIN/                                (Super Admin + Manutenção)
│   ├── README.md                         (Overview + 8 seções)
│   ├── USERS.md                          (UtilisateursAdminPage + CRUD)
│   ├── REFERENCES.md                     (Tabelas de referência: tipos, categorias)
│   ├── THEMES.md                         (Temas dinâmicos)
│   ├── COMMUNICATION.md                  (Broadcast de mensagens)
│   ├── MAINTENANCE.md                    (Logs, services, email test)
│   └── DATASOURCES.md                    (UserManagementDatasource, etc)
│
└── EDGE_FUNCTIONS/                       (Deno - Backend Serverless)
    ├── README.md                         (Overview + lista de functions)
    ├── invite-locataire.md               (create/resend/test)
    ├── notify-edl.md                     (accepte, addition, a_signer)
    ├── notify-rendezvous.md              (Convites de rendez-vous)
    ├── manage-user-auth.md               (ban, unban, set_password)
    ├── delete-account.md                 (Soft-delete de usuário)
    └── SECURITY.md                       (JWT validation, CORS, malicious input)
```

---

## 🎯 Como Usar

### **Quando Trabalhar num Módulo**

1. **Identifique o módulo** (ex: "vou adicionar feature em EDL")
2. **Leia o README do módulo** (ex: `docs/modules/EDL/README.md`)
3. **Consulte os arquivos relevantes**:
   - Mudando datasource? → `DATASOURCES.md`
   - Adicionando campo? → `DATA_MODEL.md`
   - Novo fluxo? → `FLOWS.md`
   - Segurança? → `RLS.md`

### **Exemplo: Bug em Messagerie**

```
Você: "Há um bug no chat, os mensagens não aparecem"

Eu:
1. Detecta módulo: MESSAGERIE
2. Carrego: docs/modules/MESSAGERIE/*.md
3. Reviso:
   - DATASOURCES.md (MessagesDatasource)
   - DATA_MODEL.md (tabela Messages)
   - FLOWS.md (workflow)
   - RLS.md (políticas)
4. Debugo com esse contexto fino
```

---

## 📊 Tamanho dos Documentos

| Módulo | Tamanho | Prioridade |
|--------|---------|-----------|
| EDL | ~15 KB | 🔴 Crítico |
| MESSAGERIE | ~8 KB | 🔴 Crítico |
| BAIL | ~10 KB | 🔴 Crítico |
| AUTH | ~10 KB | 🔴 Crítico |
| CACHE_REALTIME | ~8 KB | 🟠 Alto |
| FINANCES | ~8 KB | 🟠 Alto |
| UI | ~12 KB | 🟠 Alto |
| IMMEUBLES | ~6 KB | 🟡 Médio |
| CHAMBRES | ~6 KB | 🟡 Médio |
| VETUSTE | ~8 KB | 🟡 Médio |
| INVENTORY | ~4 KB | 🟡 Médio |
| NOTIFICATIONS | ~4 KB | 🟡 Médio |
| GARANTS | ~4 KB | 🟡 Médio |
| STORAGE | ~4 KB | 🟡 Médio |
| ADMIN | ~8 KB | 🟢 Baixo |
| EDGE_FUNCTIONS | ~10 KB | 🟠 Alto |

**Total**: ~130 KB (vs ~800 KB do CLAUDE.md original)

---

## 🔄 Manutenção

- **Quando adicionar feature**: Atualize o README do módulo
- **Quando mudar datasource**: Atualize DATASOURCES.md + DATA_MODEL.md
- **Quando adicionar RLS**: Atualize RLS.md
- **Mudança grande**: Atualize FLOWS.md também

---

## 🤖 Integração com Agents

Cada módulo pode ter seu próprio **subagente specializado**:

```
code-reviewer-edl          (só entende EDL)
code-reviewer-messagerie   (só entende chat)
code-reviewer-bail         (só entende contrato)
etc.
```

Ainda não criados, mas possível!

---

## 📍 Localização

Todos os arquivos estão em:
```
/home/rhay/GitHub/la_coloc/habitafrance/docs/modules/
```

---

## ✅ Próximas Ações

- [x] Criar estrutura de pastas
- [ ] Preencher cada módulo com conteúdo
- [ ] Atualizar `.claude/settings.json` com contexthints
- [ ] Criar agents por módulo (opcional)
- [ ] Treinar no uso da nova estrutura

---

**Última atualização**: 08/08/2026 | v1.10.0
