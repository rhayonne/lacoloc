# Messagerie - Chat + Demandes de Contact

## Overview

Sistema de comunicação entre locataire e proprietaire. Um fil de chat por demanda de contato.

### Fluxo

```
Locataire quer contactar proprietaire
  ↓
Clica "Entrer en contact" na carte de chambre
  ↓
Cria Demandes_Contact (contact_etabli = false)
  ↓
Proprietaire vê em Interactions
  ↓
Toggle "Contact établi" = true (aceita)
  ↓
💬 Chat abre (ambos os lados)
  ↓
Ambos podem trocar mensagens
```

### Tabelas

- **Demandes_Contact**: Requisição de contato
- **Messages**: Mensagens do chat (N per demande)

### RLS

- Locataire lê as suas demandas
- Proprietaire lê as de suas propriedades
- INSERT em Messages só se `contact_etabli = true`
- DELETE só do próprio sender

---

## 🔗 Relacionados

- DATASOURCES.md — MessagesDatasource, DemandesContactDatasource
- DATA_MODEL.md — Tabelas
- FLOWS.md — Workflow detalhado
- RLS.md — Políticas
- NOTIFICATIONS.md — Evento `nouvelle_demande`

**Ver também**: CLAUDE.md seção "Messagerie"
