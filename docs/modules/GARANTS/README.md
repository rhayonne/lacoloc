# Garants - Avalistas

## Locataire pode ter N garants

```
Garants
  ├─ locataire_id
  ├─ nome
  ├─ contato
  └─ ativo (soft-delete)
```

## Linking ao Bail

Tabela `etat_de_lieux_garants` liga garants ao EDL.

## Auto-linking

Quando garant é criado/ativado, auto-attach aos bails "com garant" sem garant ainda.

**Ver**: CLAUDE.md seção "Bail"
