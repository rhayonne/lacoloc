# Button System

**AppButton** (widget único)
- Variantes: primary, save, cancel, delete, edit, document
- Tamanhos: standard (48dp), compact (44dp), small (36dp)

```dart
AppButton.save(
  label: 'Enregistrer',
  onPressed: () => save(),
  size: AppButtonSize.compact
)
```

**Nunca use** ElevatedButton/FilledButton cru.
