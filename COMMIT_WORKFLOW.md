# 🚀 Workflow de Commit Automático com Agents

> **⚠️ OBSOLETO (09/08/2026)**: este documento descreve commit-message-expert/version-bump-expert como se disparassem sozinhos após um commit. **Isso não acontece automaticamente** — são subagentes reais, mas só rodam quando você pede numa conversa. Ver **`DEVELOPMENT_WORKFLOW.md`** (seção 4) para o fluxo real e atual (git hook nativo testado + agentes sob pedido). Este arquivo fica só como histórico.

## Novo Fluxo (histórico, não vale mais)

```
1️⃣  Você edita código
    ↓
2️⃣  git add .
3️⃣  git commit -m "..."
    ↓
4️⃣ 🤖 Pre-commit hook
    - Code review automático
    - Correção de bugs
    - Pedido de confirmação de push
    ↓
5️⃣ ✅ Se passou, commit criado
    ↓
6️⃣ 🤖 (NOVO) Commit message agent
    - Lê o diff criado
    - Gera mensagem descritiva profissional
    - Suggere tipo de commit (feat/fix/refactor)
    - Você aceita ou edita
    ↓
7️⃣ 📝 Commit message é refinada
    ↓
8️⃣ 🤖 (NOVO) Version bump agent
    - Detecta tipo de mudança (feat→minor, fix→patch)
    - Atualiza pubspec.yaml (X.Y.Z+build)
    - Gera/atualiza CHANGELOG.md
    - Cria commit de release: chore(release): vX.Y.Z
    ↓
9️⃣ 📤 Pronto para push!
    - `git push origin <branch>`
```

---

## 🎯 Como Usar

### **Opção A: Automático (Recomendado)**

Após o code review passar:

```bash
# Terminal detecta automaticamente o novo fluxo
# Convida você para ativar os agents
```

### **Opção B: Manual**

```bash
# Após git commit bem-sucedido
claude-code commit-workflow --auto-message --auto-version

# Ou passo a passo:
# 1. Gerar mensagem
Agent({ subagent_type: "commit-message-expert", prompt: "Gere mensagem para este commit" })

# 2. Atualizar versão
Agent({ subagent_type: "version-bump-expert", prompt: "Detecte tipo de mudança e atualize versão + CHANGELOG" })
```

---

## 🤖 Agents Envolvidos

### **commit-message-expert**

```
Entrada: git diff (staged)
Saída: Mensagem descritiva em português

Exemplo:
feat(edl): suporte a avenant com janela configurável

- Adiciona coluna etat_de_lieux.avenant_window_days
- Auto-calculates janela (snapshot)
- Botão "Avenant" aparece só durante janela aberta

Migration: 20260809000001_...
```

### **version-bump-expert**

```
Entrada: Tipo de mudança (feat/fix/refactor)
Saída: 
  - Atualiza pubspec.yaml (X.Y.Z+build)
  - Cria/atualiza changelogs/v1/X.Y.md
  - Cria commit: chore(release): vX.Y.Z

Exemplo:
  v1.10.0 → v1.11.0 (feat)
  v1.11.0 → v1.11.1 (fix)
  v1.11.1 → v2.0.0 (breaking)
```

---

## 📊 Categorias de Commit (Automáticas)

```
feat(módulo): descrição
  ↓
  bump minor (1.10.0 → 1.11.0)

fix(módulo): descrição
  ↓
  bump patch (1.11.0 → 1.11.1)

refactor(módulo): descrição
  ↓
  sem bump de versão (1.11.1 → 1.11.1+43)

breaking: new API!
  ↓
  bump major (1.11.1 → 2.0.0)
```

---

## 📝 CHANGELOG Automático

Arquivo: `changelogs/v1/X.Y.md`

```markdown
## 1.11.0 — 2026-08-09

### Features
- feat(edl): avenant window configurável
- feat(messagerie): search em conteúdo

### Fixes
- fix(ui): cores em tema escuro
- fix(cache): N+1 bugs

### Performance
- perf(realtime): 12s → 2s

### Breaking Changes
- ⚠️ Migrations: 20260809000001_...
- ⚠️ Edge Functions: notify-edl novo param

### Developer Experience
- docs(modules): Estrutura modularizada
- chore(agents): 6 agents + schedules
```

---

## ⚙️ Configuração

### Automático (Recomendado)

O workflow é ativado automaticamente após o pre-commit hook passar:

```bash
git commit -m "..."
# ↓ hook passa
# ↓ "Quer usar commit-message-expert?" 
# Responda sim/não
```

### Manual via Settings

Editar `.claude/settings.json`:

```json
{
  "hooks": {
    "before_commit": "bash ./scripts/pre-commit-auto-fix.sh",
    "after_commit": "bash ./scripts/post-commit-agents.sh"
  },
  "agents": {
    "auto_commit_message": true,
    "auto_version_bump": true
  }
}
```

---

## 🎯 Exemplo de Fluxo Real

```bash
# 1. Você faz um fix
git add lib/presentation/ui.dart
git commit -m "fix color bug"

# ↓ Pre-commit hook passa

# 2. (Novo) Agente gera mensagem melhor
"🤖 Gerando mensagem de commit..."
# Output:
# fix(ui): cores em tema escuro não eram computed dinamicamente
#
# - AppColors.<token> agora é getter (não const)
# - Rebuild do MaterialApp ao trocar tema
# - Testa em light/dark/custom palettes
#
# Fixes: lacoloc/lacoloc-issues#42

# 3. Você aprova (ou edita)
# ✅ "Mensagem aprovada!"

# 4. (Novo) Agente atualiza versão
"🤖 Detectando tipo de mudança: fix → patch"
# pubspec.yaml: 1.10.0 → 1.10.1
# CHANGELOG.md: adicionada seção 1.10.1 com fix

# ✅ Commit criado: chore(release): v1.10.1

# 5. Pronto para push
git push origin main
```

---

## 🚨 Troubleshooting

### "Agente não respondeu"

```bash
# Retry manualmente
Agent({ 
  subagent_type: "commit-message-expert",
  prompt: "git diff --cached | head -100"
})
```

### "Versão ficou errada"

```bash
# Revert manualmente
git revert HEAD~1  # Volta o release commit
# Ajuste pubspec.yaml + CHANGELOG
git add pubspec.yaml changelogs/
git commit -m "chore(release): fix versioning"
```

### "Quer pular o agente?"

```bash
git commit --no-verify  # Pula o hook
git commit --no-message-agent  # Pula só commit-message-expert
```

---

## 📚 Agents Relacionados

- `code-review` (skill) — Revisa antes do commit
- `security-review` (skill) — Auditoria antes de release
- `commit-message-expert` (custom) — Cria mensagem
- `version-bump-expert` (custom) — Atualiza versão

---

## 🔄 Checklist Pré-Release

Antes de fazer `git push`:

- [ ] `git log --oneline -5` (mensagens parecem boas?)
- [ ] `cat pubspec.yaml` (versão está certa?)
- [ ] `cat changelogs/v1/X.Y.md` (CHANGELOG preenchido?)
- [ ] `git status` (sem uncommitted changes?)
- [ ] `/code-review --fix` (sem bugs?)
- [ ] `/security-review` (sem vulnerabilities?)

---

## 💡 Pro Tips

1. **Mensagens claras** → Histórico melhor → Blame/bisect mais fácil
2. **Versão correta** → Usuarios sabem o que é breaking change
3. **CHANGELOG** → Release notes automáticas
4. **Agents checam** → Menos erros manuais

---

**Última atualização**: 09/08/2026 | Integração completa de agents
