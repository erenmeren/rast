import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../discovery/people_directory.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/rast_colors.dart';
import '../../../core/theme/rast_theme.dart';
import '../../../core/ui/ui.dart';
import '../../chat/threads_notifier.dart';
import '../safety_actions.dart';

/// Remove connection (when matched), Report profile, Block profile.
/// [returnTo] is where the member lands after a removal.
Future<void> showPersonMenu(BuildContext context, WidgetRef ref, String personId, {required String returnTo}) {
  final person = ref.person(personId);
  if (person == null) return Future.value();
  final matched = ref.read(threadsProvider.notifier).byPerson(personId) != null;
  return showRastSheet<void>(
    context,
    title: '${person.age} · Crossed paths',
    builder: (sheetContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your connection. Your choice.', style: rastStyle(size: 13, weight: 450, height: 1.65, color: sheetContext.colors.body)),
        const SizedBox(height: 8),
        if (matched)
          MenuRow(
            label: 'Remove connection',
            detail: 'Delete this chat. Never match again.',
            icon: 'close',
            onTap: () {
              Navigator.of(sheetContext).pop();
              showRemoveConnectionSheet(context, ref, personId, returnTo: returnTo);
            },
          ),
        MenuRow(
          label: 'Report profile',
          detail: 'Tell us about a concern',
          icon: 'flag',
          onTap: () {
            Navigator.of(sheetContext).pop();
            showReportSheet(context, ref, personId, returnTo: returnTo);
          },
        ),
        MenuRow(
          label: 'Block profile',
          detail: 'Prevent this profile from reaching you',
          icon: 'block',
          onTap: () {
            Navigator.of(sheetContext).pop();
            showBlockConfirmSheet(context, ref, personId, returnTo: returnTo);
          },
        ),
      ],
    ),
  );
}

Future<void> showRemoveConnectionSheet(BuildContext context, WidgetRef ref, String personId, {required String returnTo}) {
  return showRastSheet<void>(
    context,
    title: 'Remove this connection?',
    builder: (sheetContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your match and this conversation will be deleted. You will no longer see each other in Discover or Likes You, and you cannot match again.', style: rastStyle(size: 13, weight: 450, height: 1.65, color: sheetContext.colors.body)),
        const SizedBox(height: 12),
        const SettingTip(icon: 'lock', text: 'This is permanent. You can still report this person from Removed connections.'),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Remove connection',
          onPressed: () {
            Navigator.of(sheetContext).pop();
            if (ref.read(safetyActionsProvider).removePerson(personId)) {
              _leave(context, returnTo);
              showToast(context, 'Connection removed permanently. You will not match again.');
            }
          },
        ),
        const SizedBox(height: 9),
        SecondaryButton(label: 'Keep connection', onPressed: () => Navigator.of(sheetContext).pop()),
      ],
    ),
  );
}

Future<void> showBlockConfirmSheet(BuildContext context, WidgetRef ref, String personId, {required String returnTo}) {
  final matched = ref.read(threadsProvider.notifier).byPerson(personId) != null;
  return showRastSheet<void>(
    context,
    title: 'Block this profile?',
    builder: (sheetContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          matched
              ? 'Your match and messages will be removed permanently. You will not match again, even if you later unblock this profile.'
              : 'You will no longer see each other while this profile is blocked. Manage your blocked profiles in Safety & account.',
          style: rastStyle(size: 13, weight: 450, height: 1.65, color: sheetContext.colors.body),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Block profile',
          onPressed: () {
            Navigator.of(sheetContext).pop();
            ref.read(safetyActionsProvider).removePerson(personId, block: true);
            _leave(context, returnTo);
            showToast(context, 'Profile blocked. You will no longer see each other.');
          },
        ),
        const SizedBox(height: 9),
        SecondaryButton(label: 'Cancel', onPressed: () => Navigator.of(sheetContext).pop()),
      ],
    ),
  );
}

Future<void> showReportSheet(BuildContext context, WidgetRef ref, String personId, {required String returnTo}) {
  final matched = ref.read(threadsProvider.notifier).byPerson(personId) != null;
  return showRastSheet<void>(
    context,
    title: 'What would you like to report?',
    builder: (sheetContext) => _ReportSheetBody(
      matched: matched,
      onSubmit: (reason, alsoBlock) {
        Navigator.of(sheetContext).pop();
        ref.read(safetyActionsProvider).report(personId, reason, alsoBlock: alsoBlock);
        if (alsoBlock) _leave(context, returnTo);
        showToast(
          context,
          alsoBlock
              ? 'Report saved and profile blocked in this preview. No real report was sent.'
              : 'Report saved in this preview. No real report was sent.',
        );
      },
    ),
  );
}

class _ReportSheetBody extends StatefulWidget {
  const _ReportSheetBody({required this.matched, required this.onSubmit});
  final bool matched;
  final void Function(String reason, bool alsoBlock) onSubmit;

  @override
  State<_ReportSheetBody> createState() => _ReportSheetBodyState();
}

class _ReportSheetBodyState extends State<_ReportSheetBody> {
  String? _reason;
  bool _alsoBlock = true;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose the reason that fits best.', style: rastStyle(size: 13, weight: 450, height: 1.65, color: c.body)),
        const SizedBox(height: 8),
        for (final r in reportReasons)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _ReportOption(label: r, selected: _reason == r, onTap: () => setState(() => _reason = r)),
          ),
        const SizedBox(height: 10),
        RastTextField(
          controller: _details,
          hint: 'Anything else to add? (optional)',
          maxLength: 1000,
          maxLines: 3,
          minLines: 2,
          semanticLabel: 'Report details',
        ),
        const SizedBox(height: 8),
        OptionCheck(
          label: widget.matched ? 'Also block and permanently remove this connection.' : 'Also block this profile.',
          value: _alsoBlock,
          onChanged: (v) => setState(() => _alsoBlock = v),
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'Complete report',
          trailingIcon: null,
          onPressed: _reason == null ? null : () => widget.onSubmit(_reason!, _alsoBlock),
        ),
        const FormHelp('Design preview: no real report is sent. Optional details are not saved.'),
      ],
    );
  }
}

/// After a removal the current screen may no longer be valid (conversation,
/// detail, match). Go to the safe parent.
void _leave(BuildContext context, String returnTo) {
  final here = GoRouterState.of(context).matchedLocation;
  if (here != returnTo) context.go(returnTo);
}

class _ReportOption extends StatelessWidget {
  const _ReportOption({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final border = selected ? c.accent : (c.isDark ? const Color(0xFF45404B) : c.outline);
    final bg = selected ? (c.isDark ? const Color(0xFF382822) : const Color(0xFFFFF1EB)) : (c.isDark ? const Color(0xFF24242A) : Colors.transparent);
    final fg = selected ? c.accent : (c.isDark ? const Color(0xFFC7C0CB) : const Color(0xFF6A6A78));
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11), side: BorderSide(color: border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                Expanded(child: Text(label, style: rastStyle(size: 13, weight: 500, color: fg))),
                if (selected) RastIcon('check', size: 16, color: c.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
