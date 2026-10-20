import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/rast_colors.dart';
import '../theme/rast_theme.dart';

/// Rounded input: fill, 1px border, radius 14, min height 54, 16px text.
class RastTextField extends StatelessWidget {
  const RastTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.textAlign = TextAlign.start,
    this.style,
    this.autofocus = false,
    this.textInputAction,
    this.semanticLabel,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final int maxLines;
  final int? minLines;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextAlign textAlign;
  final TextStyle? style;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final String? semanticLabel;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      maxLines: maxLines,
      minLines: minLines,
      autofillHints: autofillHints,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textAlign: textAlign,
      autofocus: autofocus,
      textInputAction: textInputAction,
      cursorColor: c.accent,
      style: style ?? RastText.input(c),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: (style ?? RastText.input(c)).copyWith(
          color: c.isDark ? const Color(0xFF94909C) : const Color(0xFFC4C4CC),
        ),
        counterText: '',
        filled: true,
        fillColor: c.inputFill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        constraints: const BoxConstraints(minHeight: 54),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.inputBorder),
        ),
      ),
    );
    final labelled = semanticLabel != null ? Semantics(label: semanticLabel, textField: true, child: field) : field;
    if (label == null) return labelled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label!),
        const SizedBox(height: 12),
        labelled,
      ],
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: RastText.fieldLabel(context.colors));
}

/// Inline validation message. Hidden when [message] is null or empty.
class FormError extends StatelessWidget {
  const FormError(this.message, {super.key});
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(message!, style: RastText.error(context.colors)),
      ),
    );
  }
}

/// Small helper text under a field.
class FormHelp extends StatelessWidget {
  const FormHelp(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 11),
        child: Text(text, style: RastText.help(context.colors)),
      );
}

/// Checkbox row with muted 12px label.
class OptionCheck extends StatelessWidget {
  const OptionCheck({super.key, required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: c.accent,
                checkColor: c.onPrimary,
                side: BorderSide(color: c.isDark ? const Color(0xFF6B6672) : const Color(0xFFB8B8C2)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: rastStyle(size: 12, weight: 450, height: 1.6, color: c.isDark ? c.body : const Color(0xFF73737E))),
            ),
          ],
        ),
      ),
    );
  }
}
