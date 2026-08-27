import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class AppToggleSwitch extends StatelessWidget {
  const AppToggleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final glassSwitch = GlassSwitch(
      value: value,
      onChanged: onChanged ?? (_) {},
      activeColor: CupertinoColors.systemBlue.resolveFrom(context),
      useOwnLayer: true,
      quality: GlassQuality.premium,
    );
    if (onChanged != null) return glassSwitch;

    return Semantics(
      toggled: value,
      enabled: false,
      child: ExcludeSemantics(
        child: IgnorePointer(child: Opacity(opacity: 0.5, child: glassSwitch)),
      ),
    );
  }
}
