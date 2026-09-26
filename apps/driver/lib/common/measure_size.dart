import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Reports [child]'s size after layout whenever it changes (e.g. a bottom panel over a map, whose
/// height becomes the map's padding so the Google logo stays visible).
class MeasureSize extends SingleChildRenderObjectWidget {
  const MeasureSize({super.key, required this.onChange, super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMeasureSize(onChange);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderMeasureSize).onChange = onChange;
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    final size = child?.size ?? Size.zero;
    if (size == _last) return;
    _last = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(size));
  }
}
