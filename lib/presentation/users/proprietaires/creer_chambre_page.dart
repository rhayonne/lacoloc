import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/chambres.dart';
import 'package:lacoloc_front/data/datasources/immeubles.dart';
import 'package:lacoloc_front/data/datasources/reference.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/data/models/immeubles.dart';
import 'package:lacoloc_front/data/models/reference.dart';
import 'package:lacoloc_front/presentation/widgets/photo_picker_field.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/utils/currency.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

class CreerChambrePage extends StatefulWidget {
  final ChambreModel? chambre;
  final VoidCallback? onSaved;

  const CreerChambrePage({super.key, this.chambre, this.onSaved});

  @override
  State<CreerChambrePage> createState() => _CreerChambrePageState();
}

class _CreerChambrePageState extends State<CreerChambrePage> {
  final _formKey = GlobalKey<FormState>();
  final _roomNameCtrl = TextEditingController();
  final _m2Ctrl = TextEditingController();
  final _prixLoyerCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  late Future<_FormBundle> _bundleFuture;
  ImmeublesModel? _selectedImmeuble;
  final Set<int> _selectedOptionIds = {};
  List<String> _roomPhotos = [];
  String? _mainPhoto;
  bool _isActive = true;
  bool _estLoue = false;
  bool _isSubmitting = false;

  bool get _isEditing => widget.chambre != null;

  @override
  void initState() {
    super.initState();
    _bundleFuture = _loadBundle();
    final ch = widget.chambre;
    if (ch != null) {
      _roomNameCtrl.text = ch.roomName;
      _m2Ctrl.text = ch.m2?.toStringAsFixed(2) ?? '';
      _prixLoyerCtrl.text = ch.prixLoyer?.toStringAsFixed(2) ?? '';
      _descriptionCtrl.text = ch.description ?? '';
      _roomPhotos = List.from(ch.roomPhotos);
      _mainPhoto = ch.mainPhoto;
      _isActive = ch.isActive;
      _estLoue = ch.estLoue;
      _selectedOptionIds.addAll(ch.selectedOptionIds);
      _bundleFuture.then((bundle) {
        if (!mounted) return;
        final match = bundle.immeubles
            .where((i) => i.id == ch.immeubleId)
            .firstOrNull;
        if (match != null) setState(() => _selectedImmeuble = match);
      });
    }
  }

  Future<_FormBundle> _loadBundle() async {
    final ownerId = AuthService.currentUser?.id;
    final immeubles = ownerId == null
        ? <ImmeublesModel>[]
        : await ImmeublesDatasource.listByOwner(ownerId);
    final options = await ReferenceDatasource.roomOptions();
    return _FormBundle(immeubles: immeubles, options: options);
  }

  @override
  void dispose() {
    _roomNameCtrl.dispose();
    _m2Ctrl.dispose();
    _prixLoyerCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  /// Converte o texto digitado ("1 500,50" ou "1500.50") em centavos inteiros.
  int? _parseCents(String text) {
    final normalized = text.trim().replaceAll(',', '.');
    final value = double.tryParse(normalized);
    if (value == null) return null;
    return (value * 100).round();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedImmeuble == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Sélectionnez un immeuble")));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final model = ChambreModel(
        id: widget.chambre?.id ?? 0,
        immeubleId: _selectedImmeuble!.id,
        roomName: _roomNameCtrl.text.trim(),
        m2: double.tryParse(_m2Ctrl.text.replaceAll(',', '.')),
        prixLoyer: double.tryParse(_prixLoyerCtrl.text.replaceAll(',', '.')),
        description: _descriptionCtrl.text.trim().isEmpty
            ? null
            : _descriptionCtrl.text.trim(),
        roomPhotos: _roomPhotos,
        selectedOptionIds: _selectedOptionIds.toList(),
        isActive: _isActive,
        estLoue: _estLoue,
        mainPhoto: _mainPhoto,
      );
      _isEditing
          ? await ChambresDatasource.update(model)
          : await ChambresDatasource.create(model);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Chambre modifiée avec succès'
                : 'Chambre créée com sucesso',
          ),
        ),
      );
      if (_isEditing) {
        widget.onSaved?.call();
      } else {
        _formKey.currentState?.reset();
        _roomNameCtrl.clear();
        _m2Ctrl.clear();
        _descriptionCtrl.clear();
        setState(() {
          _selectedOptionIds.clear();
          _selectedImmeuble = null;
          _roomPhotos = [];
          _mainPhoto = null;
          _isActive = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_FormBundle>(
      future: _bundleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        final bundle = snapshot.data!;

        if (!_isEditing && bundle.immeubles.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: Text(
                "Créez d'abord un immeuble avant d'ajouter une chambre.",
                style: AppTypography.bodyLg,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // --- INÍCIO DA CORREÇÃO DE LARGURA ---
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 800,
            ), // Define limite de largura
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Container(
                // Adiciona um fundo branco e borda se quiser efeito de card no Desktop
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _isEditing ? 'Modifier la chambre' : 'Nouvelle chambre',
                        style: AppTypography.titleLg,
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      if (_isEditing)
                        TextFormField(
                          initialValue:
                              widget.chambre?.immeubleName ??
                              _selectedImmeuble?.name ??
                              '',
                          decoration: const InputDecoration(
                            labelText: 'Immeuble',
                          ),
                          readOnly: true,
                          style: TextStyle(color: AppColors.onSurfaceVariant),
                        )
                      else
                        DropdownButtonFormField<ImmeublesModel>(
                          initialValue: _selectedImmeuble,
                          decoration: const InputDecoration(
                            labelText: 'Immeuble',
                          ),
                          items: bundle.immeubles
                              .map(
                                (i) => DropdownMenuItem(
                                  value: i,
                                  child: Text(i.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedImmeuble = v),
                        ),

                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _roomNameCtrl,
                        decoration: const InputDecoration(labelText: 'Nom'),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Requis' : null,
                      ),

                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _m2Ctrl,
                        decoration: const InputDecoration(
                          labelText: 'Surface (m²)',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.md),
                      ValueListenableBuilder(
                        valueListenable: _prixLoyerCtrl,
                        builder: (context, value, _) {
                          final cents = _parseCents(_prixLoyerCtrl.text);
                          final preview = cents != null && cents > 0
                              ? formatFrenchCurrency(cents)
                              : null;
                          return TextFormField(
                            controller: _prixLoyerCtrl,
                            decoration: InputDecoration(
                              labelText: 'Prix du loyer (€/mois)',
                              prefixIcon: const Icon(Icons.euro),
                              helperText: preview,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              // Permite apenas dígitos e um único separador (. ou ,)
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*[,.]?\d{0,2}'),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _descriptionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          alignLabelWithHint: true,
                        ),
                        maxLines: 4,
                      ),

                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Photos de la chambre',
                        style: AppTypography.labelMd,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      PhotoPickerField(
                        folder: 'chambres',
                        initialPhotos: _roomPhotos,
                        initialMainPhoto: _mainPhoto,
                        onChanged: (urls) => setState(() => _roomPhotos = urls),
                        onMainPhotoChanged: (url) =>
                            setState(() => _mainPhoto = url),
                      ),

                      const SizedBox(height: AppSpacing.lg),
                      Text("Équipements", style: AppTypography.titleLg),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: bundle.options.map((o) {
                          final sel = _selectedOptionIds.contains(o.id);
                          return FilterChip(
                            label: Text(o.name),
                            selected: sel,
                            onSelected: (v) => setState(
                              () => v
                                  ? _selectedOptionIds.add(o.id)
                                  : _selectedOptionIds.remove(o.id),
                            ),
                            selectedColor: AppColors.primaryFixed,
                            checkmarkColor: AppColors.primary,
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: AppSpacing.lg),
                      const Divider(),
                      SizedBox(
                        height: AppSpacing.xl,
                        child: Text(
                          'Autres options',
                          style: AppTypography.titleLg,
                        ),
                      ),
                      CheckboxListTile(
                        value: _estLoue,
                        onChanged: (v) =>
                            setState(() => _estLoue = v ?? false),
                        title: const Text('Chambre louée'),
                        subtitle: const Text(
                          'Marque cette chambre comme actuellement occupée.',
                        ),
                        activeColor: AppColors.primary,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      CheckboxListTile(
                        value: !_isActive,
                        onChanged: (v) =>
                            setState(() => _isActive = !(v ?? false)),
                        title: const Text('Désactiver chambre'),
                        subtitle: const Text(
                          'Cette chambre ne sera plus visible sur le site.',
                        ),
                        activeColor: AppColors.error,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(
                              0xFF006D77,
                            ), // Cor teal do seu design
                            foregroundColor: Colors.white,
                          ),
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: Text(
                            _isEditing
                                ? 'Enregistrer les modifications'
                                : 'Créer la chambre',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        // --- FIM DA CORREÇÃO ---
      },
    );
  }
}

class _FormBundle {
  final List<ImmeublesModel> immeubles;
  final List<ReferenceItem> options;
  _FormBundle({required this.immeubles, required this.options});
}
