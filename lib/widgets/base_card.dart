import 'package:flutter/material.dart';

class BaseCard extends StatelessWidget {
  final Widget? leading;
  final String? title;
  final Widget? titleWidget;
  final String? subtitle;
  final Color? subtitleColor;
  final Widget? trailing;
  final Widget? body;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final List<Widget>? children;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;

  const BaseCard({
    super.key,
    this.leading,
    this.title,
    this.titleWidget,
    this.subtitle,
    this.subtitleColor,
    this.trailing,
    this.body,
    this.onTap,
    this.onDoubleTap,
    this.children,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
  }) : assert(title != null || titleWidget != null);

  @override
  Widget build(BuildContext context) {
    const margin = EdgeInsets.symmetric(horizontal: 10, vertical: 4);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    if (children != null) {
      return Card(
        margin: margin,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                leading: leading,
                title: _buildTitleSection(),
                trailing: trailing,
                initiallyExpanded: initiallyExpanded,
                onExpansionChanged: onExpansionChanged,
                children: children!,
              ),
              if (body != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: body,
                ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: margin,
      shape: shape,
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 12)],
                  Expanded(child: _buildTitleSection()),
                  trailing != null ? trailing! : const SizedBox.shrink(),
                ],
              ),
              if (body != null) ...[const SizedBox(height: 8), body!],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleSection() {
    if (titleWidget != null) {
      return titleWidget!;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: TextStyle(fontSize: 12, color: subtitleColor ?? Colors.grey),
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}
