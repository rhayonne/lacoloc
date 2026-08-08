# Vétusté - Desgaste

Cálculo e decompte de desgaste de móveis.

## Fluxo

1. **Auto-detecção**: Comparar estado (sortieavs entrée)
2. **Cálculo**: `abattement% = (âge - franchise) × coef%`
3. **Decompte**: Criar linhas de desgaste
4. **PDF**: Imprime decompte de réparations
5. **Recettes**: Pode gerar a_recevoir para cobrar

## Tabelas

- `vetuste_bareme`: Vida útil + coef por categoria
- `vetuste_decompte`: Uma por EDL sortie
- `vetuste_decompte_ligne`: Itens com desgaste

**Ver**: CLAUDE.md seção "Vétusté Option B"
