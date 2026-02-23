import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class MacroSlider extends StatefulWidget {
  final double protein;
  final double carbs;
  final double fats;
  final void Function(double protein, double carbs, double fats) onChanged;

  const MacroSlider({
    super.key,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.onChanged,
  });

  @override
  State<MacroSlider> createState() => _MacroSliderState();
}

class _MacroSliderState extends State<MacroSlider> {
  late double _proteinPercent;
  late double _carbPercent;
  late double _fatPercent;

  @override
  void initState() {
    super.initState();
    _proteinPercent = widget.protein;
    _carbPercent = widget.carbs;
    _fatPercent = widget.fats;
  }

  @override
  void didUpdateWidget(covariant MacroSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.protein != widget.protein ||
        oldWidget.carbs != widget.carbs ||
        oldWidget.fats != widget.fats) {
      setState(() {
        _proteinPercent = widget.protein;
        _carbPercent = widget.carbs;
        _fatPercent = widget.fats;
      });
    }
  }

  double _width = 0;
  bool _isDraggingFirst = false;

  void _onDrag(Offset localPosition, bool isFirstHandle) {
    final dx = localPosition.dx.clamp(0, _width);
    double handle1 = (_proteinPercent / 100) * _width;
    double handle2 = ((_proteinPercent + _carbPercent) / 100) * _width;

    if (isFirstHandle) {
      handle1 = dx.clamp(0, handle2 - 10).toDouble();
    } else {
      handle2 = dx.clamp(handle1 + 10, _width).toDouble();
    }

    final newProtein = (handle1 / _width) * 100;
    final newCarbs = ((handle2 - handle1) / _width) * 100;
    final newFats = 100 - newProtein - newCarbs;

    setState(() {
      _proteinPercent = newProtein;
      _carbPercent = newCarbs;
      _fatPercent = newFats;
    });

    widget.onChanged(_proteinPercent, _carbPercent, _fatPercent);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        final handle1X = (_proteinPercent / 100) * _width;
        final handle2X = ((_proteinPercent + _carbPercent) / 100) * _width;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildMacroLabel(
                    macroKey: 'protein',
                    label: 'Protein',
                    percentage: _proteinPercent,
                    color: AppColors.protein,
                  ),
                ),
                Expanded(
                  child: _buildMacroLabel(
                    macroKey: 'carbs',
                    label: 'Carbs',
                    percentage: _carbPercent,
                    color: AppColors.carbs,
                  ),
                ),
                Expanded(
                  child: _buildMacroLabel(
                    macroKey: 'fats',
                    label: 'Fats',
                    percentage: _fatPercent,
                    color: AppColors.fat,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Semantics(
              label:
                  'Macro split slider. Protein: ${_proteinPercent.toStringAsFixed(0)}%, Carbs: ${_carbPercent.toStringAsFixed(0)}%, Fats: ${_fatPercent.toStringAsFixed(0)}%.',
              hint: 'Drag to adjust',
              slider: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragDown: (details) {
                  final dx = details.localPosition.dx;
                  final dist1 = (dx - handle1X).abs();
                  final dist2 = (dx - handle2X).abs();
                  _isDraggingFirst = dist1 < dist2;
                },
                onHorizontalDragUpdate: (details) {
                  _onDrag(details.localPosition, _isDraggingFirst);
                },
                child: SizedBox(
                  height: 50,
                  child: Stack(
                    children: [
                      // Base bar
                      Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.borderLight,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      // Protein
                      Positioned(
                        left: 0,
                        child: Container(
                          height: 10,
                          width: handle1X,
                          decoration: BoxDecoration(
                            color: AppColors.protein,
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(5),
                            ),
                          ),
                        ),
                      ),
                      // Carbs
                      Positioned(
                        left: handle1X,
                        child: Container(
                          height: 10,
                          width: handle2X - handle1X,
                          color: AppColors.carbs,
                        ),
                      ),
                      // Fats
                      Positioned(
                        left: handle2X,
                        child: Container(
                          height: 10,
                          width: _width - handle2X,
                          decoration: BoxDecoration(
                            color: AppColors.fat,
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(5),
                            ),
                          ),
                        ),
                      ),
                      // Handles
                      Positioned(
                        left: handle1X - 8,
                        top: 0,
                        bottom: 0,
                        child: _buildHandle(),
                      ),
                      Positioned(
                        left: handle2X - 8,
                        top: 0,
                        bottom: 0,
                        child: _buildHandle(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMacroLabel({
    required String macroKey,
    required String label,
    required double percentage,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            key: ValueKey('macro-$macroKey-label'),
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            key: ValueKey('macro-$macroKey-value'),
            '${percentage.toStringAsFixed(0)}%',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 16,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.borderLight),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.15),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}
