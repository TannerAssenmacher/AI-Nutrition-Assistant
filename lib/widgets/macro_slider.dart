import 'package:flutter/material.dart';

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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Protein ${_proteinPercent.toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                Text('Carbs ${_carbPercent.toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                Text('Fats ${_fatPercent.toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),

            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanDown: (details) {
                final dx = details.localPosition.dx;
                final dist1 = (dx - handle1X).abs();
                final dist2 = (dx - handle2X).abs();
                _isDraggingFirst = dist1 < dist2;
              },
              onPanUpdate: (details) {
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
                        color: Colors.grey[300],
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
                          color: Colors.redAccent,
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
                        ),
                      ),
                    ),
                    // Carbs
                    Positioned(
                      left: handle1X,
                      child: Container(
                        height: 10,
                        width: handle2X - handle1X,
                        color: Colors.blueAccent,
                      ),
                    ),
                    // Fats
                    Positioned(
                      left: handle2X,
                      child: Container(
                        height: 10,
                        width: _width - handle2X,
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(5)),
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
          ],
        );
      },
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 16,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
    );
  }
}
