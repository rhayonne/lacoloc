import 'package:flutter/material.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_radius.dart';

/// Petit sélecteur de quantité entière autonome (− N +), utilisable hors
/// FormBuilder (contrairement à [NumberStepperField]). Sert aux lignes de
/// collections : sélection de pièces communes, articles d'électroménager…
class QuantityStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final bool enabled;

  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 99,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outline),
        borderRadius: AppRadius.borderSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.remove, enabled && value > min,
              () => onChanged(value - 1)),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 32),
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          _btn(Icons.add, enabled && value < max, () => onChanged(value + 1)),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, bool on, VoidCallback onTap) => InkWell(
        onTap: on ? onTap : null,
        borderRadius: AppRadius.borderSm,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon,
              size: 18,
              color: on ? AppColors.onSurface : AppColors.onSurfaceVariant),
        ),
      );
}
