# Inventory - Móveis

## Estrutura

Cada item tem:
- `chambre_id` ou `piece_id` (exclusivo)
- `meuble_ref_id` → `Meubles_Reference`
- `dans_annonce` (bool): Aparece na descrição pública

## Categorias

De `Meubles_Reference`:
- Électroménager
- Literie
- Mobilier
- etc.

**Vétusté**: Campos `date_acquisition`, `valeur_achat`, `categorie_vetuste`

**Ver**: CLAUDE.md seção "Inventaire"
