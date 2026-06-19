---
name: changelog-deploy
description: Regra — todo deploy/merge para main exige uma nota de changelog detalhada do que mudou
metadata:
  type: feedback
---

O usuário exige que **toda atualização do sistema que vai para produção** (merge/push em `main`, deploy do web e/ou de edge functions) seja acompanhada de uma **nota de changelog detalhada** do que foi alterado. Ele notou que isto foi esquecido num merge para `main` (deploy em prod) e pediu para ser sempre feito.

**How to apply (a cada deploy):**
1. Bumpar a versão em [pubspec.yaml](pubspec.yaml) (`X.Y.Z+build`): patch=correção/hotfix, minor=nova funcionalidade, major=ruptura.
2. Editar [changelogs/vX/X.Y.md](changelogs/) → secção `## X.Y.Z — AAAA-MM-DD` com **Notes** detalhadas, agrupadas por tema (Sécurité, Stockage, Fonctionnalités, Corrections…), em **francês**. O workflow `release-notes.yml` é idempotente (não duplica se `## X.Y.Z` já existir).
3. Lembrar que o CI (`deploy.yml`) só publica o **web** (GitHub Pages); **edge functions** e mudanças de **schema/RLS/RPC** precisam de deploy/aplicação à parte — incluir na nota.

**Why:** o usuário quer um histórico legível e rastreável de cada versão em produção, sem depender só dos commits.

Ver [[storage-securite]] (exemplo: entrada v1.0.1 — sécurité & stockage).
