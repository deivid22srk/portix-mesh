import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';

/// Entrada escalonada (fade + leve subida) para os primeiros itens de uma
/// lista/grade. Cada item anima uma vez, ao ser montado.
class RevealOnMount extends StatefulWidget {
  const RevealOnMount({
    super.key,
    required this.child,
    this.index = 0,
    this.maxStagger = 8,
  });

  final Widget child;
  final int index;
  final int maxStagger;

  @override
  State<RevealOnMount> createState() => _RevealOnMountState();
}

class _RevealOnMountState extends State<RevealOnMount>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.out,
  );

  @override
  void initState() {
    super.initState();
    final int steps = widget.index.clamp(0, widget.maxStagger);
    final Duration delay = Duration(milliseconds: steps * 45);
    Future<void>.delayed(delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduced motion: a entrada é instantânea (o conteúdo aparece pronto).
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}
