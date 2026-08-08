# 2 Buckets

## photos (Público)
- common_photos (imóvel)
- room_photos (quarto)
- photos de pièces
- photos de inventaire

URL pública: `/object/public/photos/...`

## documents (Privado)
- Assinaturas: `signatures/{userId}/...`
- Fotos/obs EDL: `etat_de_lieux/{edlId}/...`

URL: `doc:*` → resolvida via StorageService.resolveUrl() (assinada, ~1h)

**RLS**: Via can_access_edl, user ownership
