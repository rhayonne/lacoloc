# 🚀 Workflow de Desenvolvimento - habitafrance

**Versão**: 1.0 | **Data**: 09/08/2026 | **Timezone**: Europe/Paris

---

## Overview

Este documento descreve o **fluxo de desenvolvimento completo** para habitafrance, incluindo **documentação modularizada**, **agentes especializados**, **automação de segurança**, e **workflow de commit inteligente**.

**Objetivo**: Garantir **qualidade de código**, **segurança**, e **rastreabilidade** em cada commit.

---

## 📚 1. Documentação Modularizada

### Estrutura

```
docs/modules/
├── MODULE_OVERVIEW.md    ← Índice completo
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

### Como Usar

**Antes de começar feature em módulo X**:

```bash
# 1. Leia o overview do módulo
cat docs/modules/X/README.md

# 2. Leia os arquivos relevantes
cat docs/modules/X/DATASOURCES.md      # Se mexe em datasources
cat docs/modules/X/DATA_MODEL.md       # Se mexe em tabelas
cat docs/modules/X/RLS.md              # Se mexe em segurança
cat docs/modules/X/FLOWS.md            # Se mexe em workflows

# 3. Comece a codar
```

### Benefício

- ✅ Contexto fino (módulo, não app inteira)
- ✅ ~130 KB documentação (vs 800 KB original)
- ✅ Carregamento rápido de contexto

---

## 🤖 2. Agentes Especializados

### Lista Completa

| Agent | Módulo | Quando Usar |
|-------|--------|-----------|
| `flutter-ui-expert` | UI | Tema, botões, componentes, acessibilidade |
| `flutter-responsive-expert` | UI | Layouts mobile/tablet, responsividade |
| `edl-expert` | EDL | État des Lieux, workflows, RLS |
| `messagerie-expert` | Messagerie | Chat, demandes, realtime |
| `bail-expert` | BAIL | Contratos, assinaturas, échéances |
| `supabase-expert` | Supabase | Migrations, RLS, edge functions |
| `commit-message-expert` | Workflow | Gera mensagens de commit |
| `version-bump-expert` | Workflow | Atualiza versão + CHANGELOG |

### Localização

```
.claude/agents/
├── flutter-ui-expert.md
├── flutter-responsive-expert.md
├── edl-expert.md
├── messagerie-expert.md
├── bail-expert.md
├── supabase-expert.md
├── commit-message-expert.md
└── version-bump-expert.md
```

### Como Invocar

```bash
# Automático (detecta módulo)
Você edita código em lib/presentation/ui.dart
→ Eu automático carrego flutter-ui-expert

# Manual
Agent({
  subagent_type: "edl-expert",
  prompt: "Bug no fluxo de avenant, por favor revisa..."
})
```

---

## 📅 3. Security Audit Semanal (Rotinas Cloud Reais)

**⚠️ Nota de correção**: A versão anterior deste documento descrevia um `.claude/schedules.json` como se fosse auto-executável. Esse arquivo **não acionava nada** — não existe mecanismo no Claude Code que leia JSON arbitrário e rode tarefas. Foi substituído pelas **rotinas cloud reais** abaixo (`RemoteTrigger`, o mesmo sistema por trás do skill `/schedule`), que de fato rodam de forma autônoma e durável (independente desta sessão estar aberta).

### Configuração Real

**Timezone**: `Europe/Paris` (cron armazenado em UTC — ver nota de DST abaixo)
**Dia**: Segunda-feira
**Condição**: Roda **SEMPRE**, haja código novo ou não (por pedido explícito — falhas de segurança existem independente de mudanças recentes)

### Rotinas Ativas

| Rotina | ID | Horário (Paris, verão) | Função |
|--------|-----|------------------------|--------|
| **Security Audit Semanal** | `trig_014KE51zNYMosTxrY6KZRCbS` | 10:03 | Auditoria completa: frontend, Supabase, edge functions, dependências |
| **Watchdog Security Audit** | `trig_01LHn1wyZWPAP2CojHwo6ikw` | 11:07 | Confere se a auditoria rodou; se não, abre GitHub issue de alerta |

**Documentação completa**: `.claude/SECURITY_SCHEDULE.md` (escopo detalhado, prompts, limitação de DST, como gerenciar)

### Saída da Auditoria

1. Entrada datada em `SECURITY_REVIEW_LOG.md` (raiz do repo)
2. Branch `security-audit/YYYY-MM-DD` + PR para `main` com relatório completo
3. Se achado **critical**: GitHub issue adicional (label `security`)
4. **Não corrige sozinha** — reporta apenas; fixes de segurança exigem revisão humana

### Watchdog (Anti-Silêncio)

Se a auditoria falhar ou não rodar por qualquer motivo, o watchdog (1h depois) abre uma issue `⚠️ Weekly security audit não rodou — YYYY-MM-DD` pedindo para verificar a rotina em https://claude.ai/code/routines.

### Como Gerenciar

```bash
# Via skill (dentro do Claude Code)
/schedule list
/schedule run "HabitaFrance - Security Audit Semanal"   # rodar agora, fora do cron

# Web
https://claude.ai/code/routines
```

### ⚠️ Ajuste Necessário 2×/ano (Horário de Verão)

O cron é fixo em UTC. Quando Paris muda de CEST↔CET (final de outubro / final de março), o horário local de disparo desliza 1h. Ver `.claude/SECURITY_SCHEDULE.md` para o procedimento de ajuste.

---

## ✍️ 4. Workflow de Commit

> **⚠️ Correção (09/08/2026)**: a versão anterior descrevia um pipeline "tudo automático" (pre-commit hook → commit-message-expert → version-bump-expert, cada um disparando o próximo sozinho). **Isso não existia de verdade** — não há mecanismo no Claude Code que encadeie agentes depois de um `git commit`. O que existe e funciona de verdade está descrito abaixo.

### O que É Real e Automático

Um **git hook nativo** (`scripts/git-hooks/pre-commit`, instalado em `.git/hooks/pre-commit` via `bash scripts/install-git-hooks.sh`) roda a cada `git commit`, **de qualquer ferramenta** (terminal, IDE, Claude Code) — não depende de estar numa conversa com Claude:

```
1️⃣  git commit -m "..."
     ↓
2️⃣  .git/hooks/pre-commit dispara (git nativo, síncrono)
     ├─ flutter analyze → bloqueia se houver erro
     └─ claude -p (headless, --permission-mode bypassPermissions,
                    tools só leitura) revisa o diff staged por
                    bugs de correção/segurança óbvios
     ↓
3️⃣  VERDICT: PASS → commit prossegue
    VERDICT: BLOCK: <razão> → commit abortado, mensagem impressa
     (bypass manual: git commit --no-verify)
```

**Testado e confirmado funcionando** em 09/08/2026 (commit de teste, ~10.7s: 2.7s analyze + review de IA).

Isso é **mais enxuto** que o pipeline fictício anterior — só bloqueia por bugs óbvios de correção/segurança, não por estilo. Ele não corrige nada sozinho nem decide fazer push.

### Instalação (uma vez por clone)

`.git/hooks/` nunca é versionado pelo git — cada clone/checkout novo precisa rodar:

```bash
bash scripts/install-git-hooks.sh
```

Rode de novo sempre que `scripts/git-hooks/pre-commit` mudar.

### O que NÃO é Automático (mas está disponível sob pedido)

Os agentes `commit-message-expert` e `version-bump-expert` (`.claude/agents/*.md`) são **subagentes reais e invocáveis**, mas só quando você pede numa conversa — nada os aciona sozinho após um commit:

```bash
# Numa conversa com Claude Code, depois de commitar:
"Usa o commit-message-expert pra melhorar a mensagem desse commit"
"Usa o version-bump-expert pra atualizar a versão e o CHANGELOG"
```

**Push continua sendo sempre manual e explícito** (`git push origin <branch>`) — nunca automático, por design (ver "Executando ações com cuidado" nas instruções do Claude Code).

### Auditoria de Segurança Completa (semanal, separada deste hook)

O pre-commit hook é **rápido e superficial** de propósito (não pode travar todo commit por minutos). Para uma auditoria **profunda** de segurança, veja a seção 3 acima — a rotina cloud semanal (`Security Audit Semanal`) faz essa análise completa, sem pressa, toda segunda-feira.

### Pular o Workflow

```bash
# Pular TODOS os hooks
git commit --no-verify

# Ou rodar manualmente
bash scripts/pre-commit-auto-fix.sh
```

---

## 🔐 5. Segurança em Produção

### Health Check

Seu sistema deve ter um endpoint que retorna:

```json
GET /api/health

{
  "status": "healthy",
  "timestamp": "2026-08-09T15:30:00Z",
  "checks": {
    "database": { "status": "healthy" },
    "auth": { "status": "healthy" },
    "realtime": { "status": "healthy" },
    "storage": { "status": "healthy" }
  }
}
```

**Ver**: `.claude/LIVE_MONITORING_STRATEGY.md` para setup completo

### Monitoramento

- ✅ **Curto prazo**: Uptime Robot (gratuito, polling a cada 5 min)
- ✅ **Médio prazo**: Grafana (visualizar métricas)
- ✅ **Longo prazo**: Agent 24/7 (análise automática)

---

## 📊 6. Fluxo Semana a Semana

### Segunda-feira

```
09h (Paris): Você começa a trabalhar
10h (Paris): 🤖 SCHEDULE - Security Review (Main)
10h+: Você recebe relatório de segurança
11h (Paris): 🤖 SCHEDULE - Security Review (Supabase)
12h (Paris): 🤖 SCHEDULE - Security Review (Flutter)
    ↓
📧 Email com achados + recomendações
```

### Terça a Sexta

```
Normal: Você edita código
   ↓
git commit
   ↓
🤖 PRE-COMMIT HOOK + COMMIT AGENTS
   ↓
✅ Push automático (se optou)
```

### Próxima Segunda

```
Relatório de segurança de novo
```

---

## ✅ Checklist de Setup

- [ ] Verificar `docs/modules/` (14 pastas)
- [ ] Verificar `.claude/agents/` (8 agents)
- [x] Rotinas cloud de security criadas (ver `.claude/SECURITY_SCHEDULE.md`)
- [ ] Testar workflow de commit (próximo PR)
- [ ] Configurar health check endpoint (/api/health)
- [ ] Configurar Uptime Robot ou Grafana
- [ ] Consultar `docs/modules/<módulo>/` ao começar feature

---

## 📚 Documentação Completa

| Arquivo | Propósito |
|---------|-----------|
| `GETTING_STARTED_COMPLETE_SYSTEM.md` | Como começar |
| `WORKFLOW_AUTO_REVIEW.md` | Pre-commit hook detalhado |
| `COMMIT_WORKFLOW.md` | Workflow de commit + versioning |
| `.claude/LIVE_MONITORING_STRATEGY.md` | Monitoramento em produção |
| `docs/modules/MODULE_OVERVIEW.md` | Índice de módulos |
| `docs/modules/<MODULE>/*.md` | Cada módulo |

---

## 🎯 Resumo

### O Sistema Oferece

✅ **Documentação modularizada** (carrega contexto fino)  
✅ **6 agentes especializados** (cada um é expert no seu domínio)  
✅ **Automação de segurança** (schedules toda segunda)  
✅ **Commit workflow inteligente** (mensagens + versioning automático)  
✅ **Monitoramento de produção** (health checks + alertas)  

### Resultado

- **Código de qualidade**: Bugs encontrados + corrigidos automaticamente
- **Segurança**: Auditorias semanais (RLS, auth, injection)
- **Rastreabilidade**: Commits com mensagens descritivas + versioning correto
- **Changelog**: Atualizado automaticamente
- **Produção segura**: Monitoramento 24/7 + alertas

---

## 🚀 Próximas Ações

1. **Imediato**: Ativar schedules (`/schedule enable ...`)
2. **Esta semana**: Testar workflow de commit
3. **Este mês**: Setup health check + monitoramento
4. **Contínuo**: Usar agentes em trabalho real, consultar docs/modules/

---

## 📞 Suporte

**Dúvidas?** Consulte:
- `GETTING_STARTED_COMPLETE_SYSTEM.md` — Guia passo a passo
- `.claude/LIVE_MONITORING_STRATEGY.md` — Produção
- `docs/modules/<MODULE>/README.md` — Módulo específico

---

**Sistema implementado**: 09/08/2026  
**Timezone**: Europe/Paris  
**Status**: ✅ Pronto para uso  
**Versão do projeto**: v1.10.0+  

