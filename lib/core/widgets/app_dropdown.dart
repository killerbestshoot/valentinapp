import 'package:flutter/material.dart';

class AppDropdown<T> extends StatelessWidget {
  final T initial;
  final String label;
  final List<DropdownMenuEntry<T>> entries;
  final ValueChanged<T?> onSelected;

  const AppDropdown({
    super.key,
    required this.initial,
    required this.label,
    required this.entries,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<T>(
      initialSelection: initial,
      label: Text(label),
      dropdownMenuEntries: entries,
      onSelected: onSelected,
    );
  }
}
