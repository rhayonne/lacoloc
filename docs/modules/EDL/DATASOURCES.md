# EDL - Datasources

## EtatDesLieuxDatasource

Operações principais no EDL:

```dart
// Listar
static Future<List<EtatDesLieuxModel>> listForLocataire(uid)
static Future<List<EtatDesLieuxModel>> listForProprietaire(uid)
static Future<List<EtatDesLieuxModel>> listByImmeuble(immeubleId)

// CRUD
static Future<EtatDesLieuxModel> findById(id)
static Future<int> create(model, /* ... */)
static Future<void> update(id, updates)
static Future<void> delete(id)  // ⚠️ Bloqueia se finalise

// Operações especiais
static Future<void> finaliser(id, proprietaireSignatureUrl)
static Future<void> locataireAccepter(id, locataireSignatureUrl)
static Future<void> ensureCollectif(immeubleId, typeBail)  // Auto-create
static Future<EtatDesLieuxModel?> findCollectif(immeubleId, typeBail)
static Future<EtatDesLieuxModel?> findPrivatif(chambreId, typeEdl)
static Future<List<EtatDesLieuxModel>> listPrivativesByCollectif(collectifId)

// Sortie
static Future<void> createSortieFromEntree(entree)
static Future<EtatDesLieuxModel?> findSortieForEntree(entreeId)

// Bail + Signatures
static Future<void> setBailSignature(id, role, signatureUrl)
static Future<void> ensureBailEcheances(id)  // Rattrapage de échéances

// Garants
static Future<void> linkGarant(edlId, garantId)
static Future<void> unlinkGarant(edlId, garantId)
static Future<List<GarantModel>> garantsForEdl(edlId)

// Assinaturas (base64 → doc:* storage)
static Future<void> materializeSignatures(id)

// Email
static Future<void> requestSignature(id)  // Anti-spam: 1×/5 dias
static Future<void> notifyAddition(edlId, comodo, texte)

// Admin
static Future<void> setActive(id, active)  // Soft-delete
static Future<void> deleteHardAdmin(id)    // Hard-delete (super admin only)
```

## EdlDetailsDatasource

Tabelas filhas:

```dart
// Preneurs
static Future<List<EdlPreneurModel>> listPreneurs(edlId)
static Future<void> addPreneur(edlId, locataireId)
static Future<void> deletePreneur(edlId, preneurId)
static Future<void> deletePreneurByLocataire(edlId, locataireId)

// Relevés (compteurs)
static Future<List<EdlReleveModel>> listReleves(edlId)
static Future<void> upsertReleve(edlId, model)
static Future<void> deleteReleve(releveId)
static Future<void> copyReleves(sourceEdlId, targetEdlId)

// Clés
static Future<List<EdlCleModel>> listCles(edlId)
static Future<void> upsertCle(edlId, model)
static Future<void> deleteCle(cleId)
static Future<void> copyCles(sourceEdlId, targetEdlId)

// Sections + Lignes (equipamentos)
static Future<List<EdlSectionModel>> listSections(edlId)
static Future<void> upsertSection(edlId, model)
static Future<void> deleteSection(sectionId)
static Future<void> copyStructure(sourceEdlId, targetEdlId)  // Sem estados

// Garants linking
static Future<void> linkGarant(edlId, garantId)
static Future<void> unlinkGarant(edlId, garantId)
```

## ObservationsEdlDatasource

```dart
// Observations (murs)
static Future<List<EdlObservationModel>> listObservations(edlId)
static Future<void> upsertObservation(edlId, model)
static Future<void> deleteObservation(obsId)
static Future<void> copyObservations(sourceEdlId, targetEdlId)

// Additions (après finalisation)
static Future<void> insertAddition(edlId, pieceId, chambreId, observation, photo)
static Future<List<EdlObservationModel>> listAdditions(edlId)
```

---

## Cache & Realtime

**Chave de cache**: `edl:<scope>` (ex: `edl:owner:uid123`)

```dart
// Com cache automático
static Future<List<EtatDesLieuxModel>> listForLocataire(uid, {bool refresh = false})
  // 1ª vez: cache vazio → DB
  // Próxima: retorna cache (TTL 5 min)
  // refresh=true: força DB agora

// Write invalida
static Future<void> delete(id) {
  await db.from('etat_de_lieux').delete().eq('id', id);
  DataCache.invalidatePrefix('edl:');  // Próxima leitura → DB
}
```

**Realtime**: Não publicado (RLS cara). Usa cache + `RealtimeRefreshMixin` nas páginas.

---

## RLS (Row-Level Security)

### Proprietaire
- Lê/escreve EDLs onde `proprietaire_id = auth.uid()`
- Lê tabelas filhas (preneurs, relevés, etc.)

### Locataire
- Lê/escreve **privatif** onde `locataire_id = auth.uid()`
- Lê/escreve observações onde `author_role = 'locataire'` (só as suas)
- Lê parties comuns se é preneur (`is_edl_preneur`)

### Super Admin
- Sem RLS (pode tudo) + `setActive`/`deleteHardAdmin`

---

**Ver também**: EDL/RLS.md, EDL/FLOWS.md
