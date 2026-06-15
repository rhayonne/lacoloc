---
name: ui-conventions
description: Convenções de UI padronizadas — botão PDF, margem das barras, cor success
metadata:
  type: feedback
---

Convenções de UI que o usuário pediu para padronizar e sempre seguir/manter atualizadas.

**Botão PDF / Document:** SEMPRE usar `DocumentPdfButton` ([lib/presentation/widgets/document_pdf_button.dart](lib/presentation/widgets/document_pdf_button.dart)) — botão bordé com ícone PDF + libellé « Document » (estilo `AppTheme.documentButtonStyle`) — em **todo** lugar que houver função de impressão/visualização de PDF (proprietaire E locataire, em todas as páginas EDL e fiches). Não usar `iconOnly` nem IconButton avulso de PDF.

**Margem padrão das barras:** `AppSpacing.barMargin` (= `xl` = 32px) é a margem horizontal padrão de TODAS as barras/headers (FormPageHeader, AppBar das fiches). Usar sempre essa constante; não usar `lg` (24) para margem de barra.

**Cor success:** `AppColors.success` (+ `onSuccess`, `successContainer`, etc.) existe em [lib/theme/app_colors.dart](lib/theme/app_colors.dart), calcada no Tertiary (verde). Usar para sucesso/validações.

**Why:** o usuário quer aparência consistente do botão de PDF, margem mais aerada e uniforme nas barras, e uma cor semântica de sucesso.

**How to apply:** ao criar tela com PDF → `DocumentPdfButton`; ao criar barra/header → `AppSpacing.barMargin`; sucesso → `AppColors.success`. **Sempre que o tema (theme/) for alterado, atualizar estas instruções e o CLAUDE.md.** Ver [[fenetre-avenant-additions]].
