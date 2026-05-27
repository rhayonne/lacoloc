# Diagramas de Casos de Uso — La Coloc

## Visão Geral do Sistema

```mermaid
graph TD
    subgraph Atores
        V(["👤 Visiteur (anônimo)"])
        L(["🏠 Locataire"])
        P(["🏢 Propriétaire"])
        A(["🔑 Super Admin"])
    end

    subgraph Publico["Área Pública"]
        UC1["Visualizar quartos disponíveis"]
        UC2["Filtrar quartos"]
        UC3["Ver detalhes de um quarto"]
        UC5["Criar conta Locataire"]
        UC6["Demander un compte Propriétaire"]
        UC7["Login / Logout"]
    end

    subgraph Compte["Conta"]
        UC9["Editar perfil (nome, telefone, dob)"]
        UC9b["Supprimer mon compte (edge fn)"]
    end

    subgraph LocAcoes["Locataire"]
        UC10["Solicitar contato (Demande de Contact)"]
        UC10b["Completar inscrição via convite"]
        UC10c["Consultar états des lieux recebidos"]
        UC10d["Accepter et signer un EDL finalisé"]
    end

    subgraph PropAcoes["Propriétaire"]
        UC11["Gerenciar imóveis (CRUD)"]
        UC14["Gerenciar quartos (CRUD)"]
        UC14b["Gerenciar pièces (áreas comuns)"]
        UC14c["Gerenciar inventário (móveis)"]
        UC15["Agenda de visitas (CRUD)"]
        UC17["Ver interações (demandes recebidas)"]
        UC18["Marcar contato estabelecido"]
        UC19["Gerenciar fornecedores (dados bancários)"]
        UC20["Gerenciar faturas / recettes"]
        UC21["Consultar documentação"]
        UC22["Criar/gerir états des lieux (entrée/sortie)"]
        UC22b["Convidar locataire (edge fn invite)"]
        UC22c["Finaliser un EDL"]
    end

    subgraph AdminAcoes["Super Admin"]
        UC30["Gerir utilizadores (tipo, ativo, permissões)"]
        UC31["Gerir tipos de pagamento"]
        UC32["Gerir tipos de meuble"]
    end

    V --> UC1 & UC2 & UC3 & UC5 & UC6 & UC7
    L --> UC1 & UC2 & UC3 & UC7 & UC9 & UC9b & UC10 & UC10b & UC10c & UC10d
    P --> UC7 & UC9 & UC11 & UC14 & UC14b & UC14c & UC15 & UC17 & UC18 & UC19 & UC20 & UC21 & UC22 & UC22b & UC22c
    A --> UC7 & UC9 & UC30 & UC31 & UC32
```

---

## UC Detalhado — Fluxo do Locataire

```mermaid
flowchart LR
    L(["👤 Locataire"])

    subgraph Conta
        S1["Criar conta (nome, email, telefone,\ndata nascimento, senha)"]
        S1b["OU completar inscrição\nvinda de convite (e-mail)"]
        S2["Login"]
        S3["Editar perfil"]
        S3b["Supprimer mon compte\n(bloqueado se houver EDL)"]
    end

    subgraph Busca
        S4["Navegar lista de quartos"]
        S5["Filtrar (opções, cidade, região,\ndépartement, bail, m², preço)"]
        S6["Ver detalhe do quarto"]
    end

    subgraph Contato
        S8["Solicitar contato com Propriétaire"]
    end

    subgraph EDL["État des lieux"]
        S9["Ver EDLs (Vision générale / Entrée / Sortie)"]
        S10["Accepter et signer EDL finalisé\n(grava date_finalisation)"]
    end

    L --> S1 & S1b & S2 & S3 & S3b
    L --> S4
    S4 --> S5 & S6
    S6 --> S8
    L --> S9
    S9 --> S10
```

---

## UC Detalhado — Fluxo do Propriétaire

```mermaid
flowchart LR
    P(["🏢 Propriétaire"])

    subgraph Patrimoine["Gestion Immobilière (abas)"]
        M1["Mes Propriétés — CRUD imóveis"]
        M2["Mes Chambres — CRUD quartos"]
        M3["Agenda — Visites (CRUD)"]
        M4["Inventaire (móveis por chambre/pièce)"]
        M5["Détail immeuble → Pièces + Inventaire"]
    end

    subgraph Interactions
        I1["Ver demandes de contato"]
        I3["Marcar contato estabelecido"]
    end

    subgraph Finances
        F1["Fournisseurs (banco/Wero/PayPal)"]
        F2["Factures + recettes (TVA)"]
    end

    subgraph EDL["État des lieux"]
        E1["Vision générale (urgents + invités)"]
        E2["Criar EDL (locataire, lieu, type bail/edl)"]
        E3["Plan 2D — observations por mur"]
        E4["Convidar locataire (e-mail)"]
        E5["Finaliser → aguarda assinatura do locataire"]
    end

    P --> M1 & M2 & M3 & M4
    M1 --> M5
    P --> I1 --> I3
    P --> F1 & F2
    P --> E1 --> E2 --> E3 --> E5
    E1 --> E4
```

---

## UC Detalhado — Fluxo do Super Admin

```mermaid
flowchart LR
    A(["🔑 Super Admin"])

    subgraph Utilisateurs
        U1["Listar todos os utilizadores"]
        U2["Mudar tipo (locataire/proprietaire/super_admin)"]
        U3["Ativar / desativar conta"]
        U4["Gerir permissões (User_Permissions)"]
        U5["Criar utilizador (via edge fn invite)"]
    end

    subgraph Referencias["Tabelas de referência"]
        R1["Types de paiement (CRUD)"]
        R2["Types de meuble (CRUD)"]
    end

    A --> U1 --> U2 & U3 & U4
    A --> U5
    A --> R1 & R2
```
