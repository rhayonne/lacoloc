# 🤖 Workflow Automático de Code Review + Fix + Push

> **⚠️ OBSOLETO (09/08/2026)**: este documento descreve um pipeline interativo (`.claude/settings.json` hooks, `scripts/pre-commit-auto-fix.sh`) que **nunca funcionou de verdade** — não existia mecanismo real por trás. Foi substituído por um **git hook nativo real e testado**: `scripts/git-hooks/pre-commit` (instalar com `bash scripts/install-git-hooks.sh`). Ver **`DEVELOPMENT_WORKFLOW.md`** (seção 4) para a versão correta e atual. Este arquivo fica só como histórico; não siga as instruções abaixo.

## O que é? (histórico, não vale mais)

Um sistema automático que:
1. ✅ **Intercepta cada commit** que você tenta fazer
2. 🔍 **Roda code review automático** procurando por bugs
3. 📋 **Explica os erros encontrados** de forma clara
4. 🔧 **Corrige os bugs automaticamente** (quando possível)
5. ✨ **Reporta todas as correções** que foram aplicadas
6. ❓ **Pergunta se pode fazer push** ou se você faz depois

---

## 🚀 Como Funciona

### Cenário: Você faz um commit

```bash
# Você fez alterações e está pronto para commitar
git add lib/presentation/novo_widget.dart
git commit -m "feat: novo widget responsivo"
```

### O Hook Automaticamente:

```
🤖 PRE-COMMIT AUTO FIX WORKFLOW
════════════════════════════════════════════════════════

✅ Mudanças detectadas

📋 Arquivos a revisar:
   • lib/presentation/novo_widget.dart

🔍 Iniciando análise automática com Claude Code...
────────────────────────────────────────────────

💡 Dica: O code review vai rodar no Claude Code.
   Verifique a janela do Claude Code para aprovação de mudanças.

⏳ Aguardando resultado da análise...

   Execute isto no seu Claude Code:
   /code-review --fix
   (isso vai analisar, encontrar bugs, e corrigi-los)

📌 Quando terminar:
   1. Volte para este terminal
   2. Pressione ENTER para continuar

➡️  Pressione ENTER quando o code review terminar...
```

### Você executa no Claude Code:

```
/code-review --fix
```

O Claude Code vai:
- 🔍 **Analisar o diff** e encontrar bugs
- 📝 **Explicar cada erro** encontrado
- 🔧 **Corrigir automaticamente** (se conseguir)
- ✨ **Aplicar as fixes** aos arquivos

### De volta ao terminal:

```
✨ CORREÇÕES APLICADAS!

📝 Resumo das mudanças:
────────────────────────────────────────────────
   @@-45,3 +45,8 @@
   -  } catch (e) {
   +  } catch (e) {
   +    print('Erro de null-safety: $e');
   +    return null;
   +  }

📦 Fazendo stage dos arquivos corrigidos...
✅ Arquivos staged

════════════════════════════════════════════════════════
  ✨ TODAS AS CORREÇÕES FORAM APLICADAS
════════════════════════════════════════════════════════

❓ O que você gostaria de fazer?

   1 - Criar commit e continuar com o push
   2 - Revisar mudanças antes de commitar
   3 - Cancelar e descartar mudanças

Escolha (1/2/3): 1
```

### Pergunta sobre o Push:

```
❓ Deseja fazer push automaticamente?

   1 - Fazer push agora
   2 - Você faz o push depois

Escolha (1/2): 1

📤 Fazendo push para main...
✅ Push realizado com sucesso!

════════════════════════════════════════════════════════
  ✅ WORKFLOW CONCLUÍDO COM SUCESSO
════════════════════════════════════════════════════════
```

---

## ⚙️ Configuração

### Está tudo configurado! ✅

Os arquivos necessários já foram criados:

```
scripts/
├── pre-commit-auto-fix.sh         ← Hook principal (executável)
└── auto-review-and-fix.py         ← Script Python (backup)

.claude/
└── settings.json                  ← Configuração do hook
```

### Como o Hook Funciona

O arquivo `.claude/settings.json` tem:

```json
{
  "hooks": {
    "before_commit": "bash ./scripts/pre-commit-auto-fix.sh"
  }
}
```

Isso significa: **Sempre que você tenta fazer commit, antes disso roda o script `pre-commit-auto-fix.sh`.**

---

## 📖 Passo a Passo de Uso

### 1️⃣ Fazer suas alterações

```bash
# Edite seus arquivos normalmente
code lib/presentation/novo_widget.dart
```

### 2️⃣ Adicionar ao staging area

```bash
git add lib/presentation/novo_widget.dart
```

### 3️⃣ Tentar fazer commit

```bash
git commit -m "feat: novo widget responsivo"
```

### 4️⃣ O Hook Intercepta

O script `pre-commit-auto-fix.sh` roda **automaticamente**:
- Mostra os arquivos a revisar
- Pede para você rodar `/code-review --fix` no Claude Code
- Aguarda sua interação

### 5️⃣ Você no Claude Code

Abra a janela do **Claude Code** e execute:

```
/code-review --fix
```

Isso vai:
- 🔍 Analisar o diff
- 📋 Explicar bugs encontrados
- 🔧 Corrigir automaticamente
- ✨ Aplicar as mudanças aos arquivos

### 6️⃣ De Volta ao Terminal

Pressione **ENTER** no terminal para continuar:

```
➡️  Pressione ENTER quando o code review terminar...
```

### 7️⃣ Escolher o que fazer

```
❓ O que você gostaria de fazer?

   1 - Criar commit e continuar com o push
   2 - Revisar mudanças antes de commitar
   3 - Cancelar e descartar mudanças

Escolha (1/2/3): 1
```

### 8️⃣ Decidir sobre o Push

```
❓ Deseja fazer push automaticamente?

   1 - Fazer push agora
   2 - Você faz o push depois

Escolha (1/2): 1
```

---

## 🎯 Casos de Uso

### Cenário 1: Tudo OK (sem bugs)

```
✅ Mudanças detectadas
🔍 Iniciando análise...
➡️  [Você roda /code-review --fix no Claude Code]
✅ Nenhuma mudança detectada
   Seu código já estava perfeito! 🎉

❓ O que você gostaria de fazer?
   1 - Criar commit e continuar com o push
   2 - Revisar mudanças antes de commitar
   3 - Cancelar e descartar mudanças
```

### Cenário 2: Bugs encontrados e corrigidos

```
✅ Mudanças detectadas
🔍 Iniciando análise...
➡️  [Você roda /code-review --fix no Claude Code]

✨ CORREÇÕES APLICADAS!
📝 Resumo das mudanças:
   - Removido null sem check
   - Adicionado error handling
   - Formatado código

❓ O que você gostaria de fazer?
   1 - Criar commit e continuar com o push
```

### Cenário 3: Bugs que precisam ser revisados

```
✅ Mudanças detectadas
🔍 Iniciando análise...
➡️  [Você roda /code-review --fix no Claude Code]

✨ CORREÇÕES APLICADAS!

❓ O que você gostaria de fazer?
   1 - Criar commit e continuar com o push
   2 - Revisar mudanças antes de commitar    ← Você escolhe
   3 - Cancelar e descartar mudanças

🔍 Mostrando mudanças...
[Mostra o diff completo]

Faça seus ajustes e tente novamente.
```

---

## 🛑 Como Desabilitar o Hook Temporariamente

Se por algum motivo você quiser **pular** o code review automático:

### Opção 1: Usar `--no-verify`

```bash
git commit -m "fix: algo rápido" --no-verify
```

⚠️ **Aviso**: Isso pula o hook. Use apenas em emergências.

### Opção 2: Desabilitar temporariamente em settings.json

```json
{
  "hooks": {
    "before_commit": ""  ← Deixe vazio ou remova a linha
  }
}
```

Depois reativar:

```json
{
  "hooks": {
    "before_commit": "bash ./scripts/pre-commit-auto-fix.sh"
  }
}
```

---

## 🔧 Troubleshooting

### ❌ Erro: "Script não encontrado"

Certifique-se que está no diretório correto:

```bash
cd /home/rhay/GitHub/la_coloc/habitafrance
git commit -m "..."
```

### ❌ Erro: "Permissão negada"

Os scripts precisam ser executáveis:

```bash
chmod +x scripts/pre-commit-auto-fix.sh
chmod +x scripts/auto-review-and-fix.py
```

### ❌ Hook não está rodando

Verifique que `.claude/settings.json` existe e tem:

```json
{
  "hooks": {
    "before_commit": "bash ./scripts/pre-commit-auto-fix.sh"
  }
}
```

E que o arquivo está no **diretório raiz do projeto** (não em subpasta).

### ❌ Claude Code não está respondendo

Se o `/code-review --fix` não termina:

1. Verifique que você tem conexão com a internet
2. Tente novamente em outra aba do Claude Code
3. Se travou, use `Ctrl+C` no terminal para cancelar

---

## 📊 O Fluxo Completo em Diagrama

```
┌─────────────────────────────────┐
│  git add .                      │
│  git commit -m "mensagem"       │
└────────────┬────────────────────┘
             ↓
┌─────────────────────────────────┐
│ 🤖 PRE-COMMIT HOOK               │
│ (scripts/pre-commit-auto-fix.sh) │
└────────────┬────────────────────┘
             ↓
    ┌────────────────────┐
    │ Há mudanças staged?│
    └────┬───────────┬───┘
         │ Não       │ Sim
         ↓           ↓
    [SAIR]     ┌──────────────────┐
               │ Mostrar resumo   │
               │ dos arquivos     │
               └────────┬─────────┘
                        ↓
               ┌──────────────────────────┐
               │ Pedir /code-review --fix │
               │ no Claude Code           │
               └────────┬─────────────────┘
                        ↓
               ┌──────────────────────────┐
               │ Você no Claude Code:     │
               │ /code-review --fix       │
               │                          │
               │ Claude Code:             │
               │ 🔍 Analisa bugs          │
               │ 📝 Explica erros         │
               │ 🔧 Corrige erros         │
               │ ✨ Aplica mudanças      │
               └────────┬─────────────────┘
                        ↓
        ┌───────────────────────────┐
        │ Voltar ao terminal        │
        │ Pressionar ENTER          │
        └────────┬──────────────────┘
                 ↓
        ┌───────────────────────────┐
        │ Houve mudanças após fix?  │
        └────┬──────────────┬───────┘
             │ Sim          │ Não
             ↓              ↓
    ┌──────────────┐   ┌─────────────────┐
    │ Mostrar fix  │   │ Mostrar resumo  │
    │ Stage files  │   │ (código OK!)    │
    │ Stage files  │   └────────┬────────┘
    └─────┬────────┘            │
          └────────┬────────────┘
                   ↓
        ┌───────────────────────────┐
        │ ❓ O que fazer?           │
        │                           │
        │ 1. Commit + Push agora    │
        │ 2. Revisar antes         │
        │ 3. Cancelar              │
        └───┬───────────────┬──┬────┘
    ┌───┘   │               │  └──────┐
    ↓       ↓               ↓         ↓
  [COMMIT] [DIFF] ┌─────────────┐ [RESET]
            +     │ Revisar     │
         [EDIT]   │ Tentar      │
                  │ novamente   │
                  └─────────────┘
         ↓
  ┌──────────────────────┐
  │ ❓ Fazer push?       │
  │                      │
  │ 1. Push agora        │
  │ 2. Você faz depois   │
  └───┬──────────────┬───┘
      ↓              ↓
   [PUSH]      [SAIR COM SUCESSO]
      ↓
  ✅ WORKFLOW COMPLETO!
```

---

## 📝 Notas Importantes

### ✅ O Hook É Inteligente

- ✅ Só ativa se houver mudanças staged
- ✅ Permite revisar antes de commitar
- ✅ Permite cancelar e descartar
- ✅ Pergunta antes de fazer push
- ✅ Não força push se você não quer

### ⚠️ Você Tem Controle Total

- Você escolhe se quer push automático ou manual
- Você pode revisar as mudanças antes
- Você pode cancelar a qualquer momento
- Você pode usar `--no-verify` para pular (emergências)

### 🎯 Objetivo

Garantir que **todo código que vai para o `main` seja limpo e sem bugs**, sem ser chato ou invasivo.

---

## 🆘 Precisa de Ajuda?

Se algo não funcionar:

1. Verifique que os scripts estão executáveis:
   ```bash
   ls -la scripts/pre-commit-auto-fix.sh
   ```

2. Verifique o arquivo de settings:
   ```bash
   cat .claude/settings.json
   ```

3. Tente rodar o script manualmente:
   ```bash
   bash scripts/pre-commit-auto-fix.sh
   ```

4. Se continuar com problema, revert tudo:
   ```bash
   git reset HEAD~1  # Desfaz último commit
   git checkout .    # Desfaz mudanças
   ```

---

## 🚀 Próximos Passos

Agora você tem um workflow automático de code review! 

Próxima vez que tentar fazer commit:

```bash
git add .
git commit -m "seu código"
# 🤖 O hook vai rodar automaticamente!
```

Aproveite! 🎉
