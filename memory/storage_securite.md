---
name: storage-securite
description: Dois buckets de Storage (photos público / documents privado), PrivateImage, refs doc:, e correções de segurança das edge functions/RPC
metadata:
  type: project
---

Arquitetura de Storage e correções de segurança aplicadas (sessão de jun/2026).

**Dois buckets:**
- **`photos`** (público) — conteúdo de anúncio (immeubles/chambres/pièces/inventaire). Guarda a **URL pública** na BD. Política `photos_public_read` (listing) **removida** — só URLs diretas servem; a app nunca lista.
- **`documents`** (privado) — conteúdo sensível: **assinaturas** + **fotos/observações de EDL**. Guarda **referência `doc:<path>`** (não URL); exibição via **URL assinada** temporária (`StorageService.resolveUrl`, cache ~1h).

**RLS em `storage.objects` (bucket documents):**
- EDL: caminho `etat_de_lieux/{edlId}/...` → CRUD das **duas partes** via `can_access_edl(edlId)`. Por isso o `edlId` é **embutido no `folder`** nos uploads de EDL (3 diálogos em [etat_de_lieux_page.dart](lib/presentation/users/proprietaires/etat_de_lieux_page.dart): murs/general/additions).
- Assinaturas guardadas: `signatures/{userId}/...` → só o dono.

**Regras de código:**
- Exibir conteúdo possivelmente sensível SEMPRE com **`PrivateImage`** ([lib/presentation/widgets/private_image.dart](lib/presentation/widgets/private_image.dart)) — nunca `Image.network`/`CachedNetworkImage` cru. Conteúdo público (quartos/imóveis/pièces) continua com `CachedNetworkImage`.
- Assinatura no PDF (cross-party): `SignaturesDatasource.materializeForEdl` copia a assinatura do utilizador para `etat_de_lieux/{edlId}/signatures/{role}-*.png` ao **finalizar/aceitar**; o PDF usa `StorageService.downloadBytes` (trata `doc:` e público).
- Compatibilidade: URLs públicas legadas continuam a funcionar (detetadas por ausência do prefixo `doc:`).

**Correções de segurança (edge functions/RPC):**
- `invite-locataire` **create/resend** e `notify-edl`: agora exigem **JWT + autorização** (gestor/super_admin; `notify-edl` valida `can_access_edl` lendo o EDL com o cliente do chamador). Antes eram abertos → roubo de conta / spam por enumeração de `edlId`.
- `notify-edl`: escape HTML em `locataireNom`/`comodo`/`texte` (+ nomes).
- `search_locataires`, `list_invited_locataires`, `notify_edl_*`: `EXECUTE` revogado de `anon`/`PUBLIC` + guarda interna de papel.
- `mailTo` (override de e-mail de teste) só honrado com secret de servidor **`ALLOW_CLIENT_MAIL_OVERRIDE=true`**. Projeto Supabase é **único** (dev=prod) → secret não definido; em dev convidar com e-mail próprio.

**Pendências conhecidas:** as edge functions `invite-locataire`/`notify-edl` precisam de **deploy** (o CI `deploy.yml` só faz deploy do web/GitHub Pages). 1 assinatura legada continua no bucket `photos` (referenciada por um EDL finalizado); será migrada quando re-assinada.

Ver convenções em [[ui-conventions]].
