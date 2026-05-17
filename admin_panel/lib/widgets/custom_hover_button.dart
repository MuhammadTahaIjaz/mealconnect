import 'package:flutter/material.dart';

class CustomHoverButton extends StatefulWidget {
  final Widget child;
  final Widget? hoveredChild;
  final Decoration decoration;
  final Decoration hoverDecoration;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const CustomHoverButton({
    super.key,
    required this.child,
    required this.decoration,
    required this.hoverDecoration,
    this.hoveredChild,
    this.onTap,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<CustomHoverButton> createState() => _CustomHoverButtonState();
}

class _CustomHoverButtonState extends State<CustomHoverButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: widget.padding,
          decoration: _hovered ? widget.hoverDecoration : widget.decoration,
          child: _hovered && widget.hoveredChild != null
              ? widget.hoveredChild!
              : widget.child,
        ),
      ),
    );
  }
}
