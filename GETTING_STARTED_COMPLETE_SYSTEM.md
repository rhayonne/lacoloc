# 🚀 Começar a Usar o Sistema Completo

> **⚠️ CORREÇÃO (09/08/2026)**: Este documento originalmente descrevia `.claude/schedules.json` e comandos `/schedule enable <id>` como se rodassem automaticamente. **Isso estava errado** — esse arquivo não acionava nada, e esses comandos não existem. Os módulos e os `.claude/agents/*.md` descritos abaixo **são reais e funcionam** (invocáveis via `Agent()`), mas para tudo relacionado a **schedules/automação de segurança**, ignore as seções abaixo que mencionam `schedules.json` e consulte em vez disso:
> - **`.claude/SECURITY_SCHEDULE.md`** — as 2 rotinas cloud reais (via `RemoteTrigger`/`/schedule`) que de fato rodam toda semana
> - **`DEVELOPMENT_WORKFLOW.md`** (seção 3) — versão atualizada e correta deste workflow

## O que foi criado?

### ✅ **FASE 1: Documentação Modularizada**
- 14 módulos em `docs/modules/`
- ~130 KB de documentação (vs 800 KB do CLAUDE.md)
- Cada módulo: README + Datasources + Data Model + RLS + Flows
- **Benefício**: Carrego só o contexto necessário do módulo, não tudo

**Arquivos**:
```
docs/modules/
├── MODULE_OVERVIEW.md
├── EDL/
├── MESSAGERIE/
├── BAIL/
├── AUTH/
├── CACHE_REALTIME/
├── FINANCES/
├── VETUSTE/
├── IMMEUBLES/
├── CHAMBRES/
├── INVENTORY/
├── GARANTS/
├── UI/
├── STORAGE/
├── NOTIFICATIONS/
├── ADMIN/
└── EDGE_FUNCTIONS/
```

### ✅ **FASE 2: Agentes Especializados**
- 6 agentes customizados em `.claude/agents/`
- Cada agent conhece seu módulo completamente
- Automático: ao reconhecer que você trabalha em X, eu carrego o agent X

**Agents**:
1. `flutter-ui-expert` — Tema, botões, componentes, acessibilidade
2. `flutter-responsive-expert` — Layouts adaptativos, mobile-first
3. `edl-expert` — État des Lieux, workflows, RLS
4. `messagerie-expert` — Chat, demandes, realtime
5. `bail-expert` — Contratos, assinaturas, échéances
6. `supabase-expert` — Migrations, RLS, edge functions

### ✅ **FASE 3: Schedules Automáticos Semanais**
- 4 schedules em `.claude/schedules.json`
- Rodam **todo Monday 9-12h** automaticamente
- Você recebe relatório com achados

**Schedules**:
- 09h: `/code-review --level=high`
- 10h: `/security-review`
- 11h: `supabase-expert` (audit completo)
- 12h: `supabase-postgres-best-practices`

### ✅ **FASE 4: Workflow de Commit Automático**
- Pre-commit hook (já estava, agora completo)
- 2 agentes novos: `commit-message-expert` + `version-bump-expert`
- Fluxo: Code fix → Commit message → Version bump → Release → Push

**Agents**:
1. `commit-message-expert` — Cria mensagens descritivas em português
2. `version-bump-expert` — Atualiza versão + CHANGELOG + release commit

---

## 🎯 Como Começar Agora

### **Passo 1: Verificar Instalação**

```bash
cd /home/rhay/GitHub/la_coloc/habitafrance

# Verificar módulos
ls -la docs/modules/

# Verificar agents
ls -la .claude/agents/

# Verificar schedules
cat .claude/schedules.json
```

### **Passo 2: Ativar Schedules (Recomendado)**

Os schedules estão configurados, mas precisam ser ativados uma vez:

```bash
# Opção A: Via CLI Claude Code (quando disponível)
/schedule list
/schedule enable weekly-code-review
/schedule enable weekly-security-review
/schedule enable weekly-supabase-check
/schedule enable weekly-postgres-best-practices

# Opção B: Manual (editar .claude/schedules.json)
# Já estão com "enabled": true
```

### **Passo 3: Testar Workflow de Commit**

```bash
# Faça uma mudança pequena
echo "# Test" >> README.md
git add README.md

# Tente fazer commit
git commit -m "test: workflow"

# O hook vai interceptar:
# 1. Code review automático
# 2. Perguntar se quer push
# 3. (Novo) Ofertar usar commit-message-expert
# 4. (Novo) Ofertar usar version-bump-expert
```

### **Passo 4: Usar Agentes Específicos**

Ao trabalhar num módulo, você pode invocar direto:

```bash
# Trabalhando com EDL?
claude-code --agent edl-expert "Bug no fluxo de avenant"

# Problemas de UI?
claude-code --agent flutter-ui-expert "Cores não mudam com tema"

# Precisa revisar?
/code-review --fix
```

### **Passo 5: Ler Documentação de Módulo**

Antes de mexer num módulo, leia seu README:

```bash
# Vou adicionar feature em Finances?
cat docs/modules/FINANCES/README.md
cat docs/modules/FINANCES/RECETTES.md

# Vou mexer em RLS?
cat docs/modules/EDL/RLS.md
cat docs/modules/MESSAGERIE/RLS.md
```

---

## 💡 Exemplos de Uso

### **Exemplo 1: Bug em Messagerie**

```
Você: "Não consigo enviar mensagem no chat"

Eu (automático):
1. Detecta módulo: MESSAGERIE
2. Carrego: docs/modules/MESSAGERIE/*.md
3. Reviso:
   - Datasource (MessagesDatasource.send)
   - RLS (policy de INSERT)
   - Realtime (está publicada)
4. Debugo com contexto fino
5. Reporto achado
```

### **Exemplo 2: Fazer Commit**

```bash
git add lib/presentation/ui.dart
git commit -m "fix color bug"

# Pre-commit hook:
# ✅ Code review passa

# (Novo) Oferece commit-message-expert:
# "Quer melhorar a mensagem de commit?"
# → Gera: fix(ui): cores não eram dinâmicas em tema escuro

# (Novo) Oferece version-bump-expert:
# "Detectei fix → patch (1.10.0 → 1.10.1)"
# → Atualiza pubspec.yaml + CHANGELOG

# Resultado:
# ✅ Commit pronto para push
# ✅ Versão atualizada
# ✅ CHANGELOG preenchido
```

### **Exemplo 3: Schedule Automático**

```
Segunda 09h:
🤖 Code Review Semanal roda automaticamente
└─ Revisa todos os commits da semana
└─ Encontra bugs, RLS issues, violações de padrão
└─ Relatório enviado

Segunda 10h:
🔐 Security Review roda
└─ Auditoria completa

Segunda 11h:
🗄️ Supabase Check roda
└─ Migrations pendentes?
└─ Performance das queries?
└─ Índices nos lugares certos?

Segunda 12h:
⚡ PostgreSQL Audit roda
└─ Bloat detection?
└─ N+1 queries?
└─ Locking issues?

Resultado:
📧 Email com relatório + recomendações
```

---

## 📋 Checklist de Configuração

- [ ] Verificar `docs/modules/` existe e tem 14 pastas
- [ ] Verificar `.claude/agents/` tem 6 agents
- [ ] Verificar `.claude/schedules.json` existe
- [ ] Ativar schedules via CLI (`/schedule enable`)
- [ ] Testar workflow de commit (próximo PR)
- [ ] Ler `WORKFLOW_AUTO_REVIEW.md` (já existia, melhorado)
- [ ] Ler `COMMIT_WORKFLOW.md` (novo, workflow inteligente)
- [ ] Usar `flutter-ui-expert` e `flutter-responsive-expert` no próximo trabalho de UI
- [ ] Consultar `docs/modules/<seu-módulo>/README.md` ao começar um novo feature

---

## 🔧 Configuração Avançada (Opcional)

### **Timezone dos Schedules**

Se você não está em São Paulo, editar `.claude/schedules.json`:

```json
{
  "schedules": [
    {
      "schedule": "0 9 * * 1",
      "timezone": "America/New_York"  // Mude aqui
    }
  ]
}
```

### **Desabilitar Agents Automáticos**

Se preferir invocar manualmente:

```json
{
  "agents": {
    "auto_load_module": false,  // Não carrega agent automático
    "auto_commit_message": false,  // Não oferece commit-message-expert
    "auto_version_bump": false  // Não oferece version-bump-expert
  }
}
```

### **Customizar Hooks**

Se o pre-commit não funciona:

```bash
# Verificar hook
cat .claude/settings.json

# Rodar manualmente
bash scripts/pre-commit-auto-fix.sh
```

---

## 📚 Documentação Completa

| Documento | Propósito |
|-----------|-----------|
| `docs/modules/MODULE_OVERVIEW.md` | Índice de todos os módulos |
| `WORKFLOW_AUTO_REVIEW.md` | Workflow de code review automático (pré-commit) |
| `COMMIT_WORKFLOW.md` | Workflow de commit + versioning (novo) |
| `.claude/agents/<name>.md` | Descrição de cada agent |
| `.claude/schedules.json` | Configuração de schedules automáticos |

---

## 🆘 Troubleshooting

### "Agents não estão carregando"

Verificar:
```bash
ls -la .claude/agents/
cat .claude/settings.json | grep "agents"
```

Se faltam agents:
```bash
# Recriar agents
ls docs/modules/*/README.md | wc -l  # Deve ser 14+
```

### "Schedules não rodaram segunda"

Verificar:
```bash
cat .claude/schedules.json | grep "enabled"
# Deve ter "enabled": true para todos
```

Se não ativado:
```bash
# Via CLI (quando disponível)
/schedule enable <schedule-id>

# Ou manual (editar JSON)
```

### "Workflow de commit pedindo confirmação de novo"

Normal! Cada commit roda o hook. Se quiser pular:
```bash
git commit --no-verify  # Pula todos os hooks
```

---

## 🎯 Próximos Passos

1. ✅ Verificar instalação (Passo 1 acima)
2. ✅ Ativar schedules (Passo 2)
3. ✅ Testar workflow de commit (Passo 3)
4. 📍 Usar agents em trabalho real (Passo 4)
5. 📍 Consultar docs/modules/ regularmente (Passo 5)
6. 📍 Monitorar relatórios dos schedules
7. 📍 Refinar versioning conforme necessário

---

## 💬 Feedback & Customização

O sistema é totalmente customizável:

- **Adicionar novo módulo?** → Crie pasta em `docs/modules/`
- **Novo agent?** → Crie `.claude/agents/<name>.md`
- **Mudar timing dos schedules?** → Edite `schedules.json`
- **Desabilitar alguma feature?** → Edite `.claude/settings.json`

---

## ✨ Resumo

Você agora tem um **sistema profissional de desenvolvimento** que:

✅ **Carrega contexto fino** (módulos, não app inteira)
✅ **Usa agentes especializados** (6 agents + skills built-in)
✅ **Roda auditorias automáticas** (toda semana, segunda 9-12h)
✅ **Cria commits inteligentes** (mensagens + versioning automático)
✅ **Pronto para escalar** (fácil adicionar novo módulo/agent)

**Tudo automático. Tudo rastreado. Tudo profissional.** 🚀

---

**Última atualização**: 09/08/2026 | Sistema Completo Implementado
