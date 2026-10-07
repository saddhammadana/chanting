import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/completion_signal.dart';
import '../../l10n/app_localizations.dart';
import '../settings/settings_controller.dart';
import 'mala_controller.dart';

/// Floating mala counter panel on the reader.
///
/// Tapping the card increments by one, with light haptics each time and stronger
/// haptics on target completion. Menu actions set target/reset, and close hides
/// the panel while keeping persisted count for later.
class MalaCounterOverlay extends ConsumerWidget {
  const MalaCounterOverlay({super.key, required this.onClose});

  final VoidCallback onClose;

  Future<void> _handleTarget(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final notifier = ref.read(malaControllerProvider.notifier);
    if (action == 'reset') {
      notifier.reset();
      return;
    }
    if (action == 'custom') {
      final current = ref.read(malaControllerProvider).target;
      final target = await showDialog<int>(
        context: context,
        builder: (context) => _MalaTargetDialog(initial: current),
      );
      if (target != null) notifier.setTarget(target);
      return;
    }
    notifier.setTarget(int.parse(action));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = ref.watch(malaControllerProvider);
    final complete = state.isComplete;

    return Semantics(
      container: true,
      label: l10n.malaTitle,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(20),
        shadowColor: Colors.black38,
        color: complete ? scheme.secondaryContainer : scheme.surface,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // Tapping the card increments; top menu/close buttons consume their own taps.
          onTap: () {
            final justCompleted = ref
                .read(malaControllerProvider.notifier)
                .increment();
            if (justCompleted) {
              // Reaching the target is the same kind of event as a sitting
              // ending, so it obeys the same setting instead of hard-coding
              // vibration — someone who chose the bell or chose silence meant
              // it for both.
              unawaited(
                ref
                    .read(completionSignalPlayerProvider)
                    .play(
                      ref.read(settingsControllerProvider).completionSignal,
                      volume: ref
                          .read(settingsControllerProvider)
                          .completionVolume,
                    ),
              );
            } else {
              // Every other bead is a light tick, not a completion, so it stays
              // a plain haptic and is deliberately never a sound.
              HapticFeedback.selectionClick();
            }
          },
          child: Container(
            width: 120,
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: complete ? scheme.secondary : scheme.outlineVariant,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    PopupMenuButton<String>(
                      tooltip: l10n.malaSetTarget,
                      icon: Icon(
                        Icons.more_horiz,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                      padding: EdgeInsets.zero,
                      onSelected: (v) => _handleTarget(context, ref, v),
                      itemBuilder: (context) => [
                        for (final t in kMalaPresetTargets)
                          PopupMenuItem(
                            value: '$t',
                            child: Text(l10n.malaRounds(t)),
                          ),
                        PopupMenuItem(
                          value: 'custom',
                          child: Text(l10n.malaCustomTarget),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'reset',
                          child: Text(l10n.malaReset),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: l10n.malaHide,
                      color: scheme.onSurfaceVariant,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(),
                      onPressed: onClose,
                    ),
                  ],
                ),
                Text(
                  '${state.count}',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: complete ? scheme.onSecondaryContainer : null,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.malaProgress(state.count, state.target),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: complete
                        ? scheme.onSecondaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom target dialog with stepper buttons and direct numeric input.
///
/// Same structure as meditation custom duration. Returns the clamped target or
/// null when cancelled.
class _MalaTargetDialog extends StatefulWidget {
  const _MalaTargetDialog({required this.initial});

  final int initial;

  @override
  State<_MalaTargetDialog> createState() => _MalaTargetDialogState();
}

class _MalaTargetDialogState extends State<_MalaTargetDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.initial}',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? get _current => int.tryParse(_controller.text.trim());

  void _step(int delta) {
    final next = ((_current ?? 0) + delta).clamp(1, kMalaMaxTarget);
    _controller.text = '$next';
    setState(() {});
  }

  void _submit() {
    final parsed = _current;
    if (parsed == null || parsed < 1) return;
    Navigator.of(context).pop(parsed.clamp(1, kMalaMaxTarget));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final materialL10n = MaterialLocalizations.of(context);
    final theme = Theme.of(context);
    final value = _current ?? 0;
    return AlertDialog(
      title: Text(l10n.malaCustomTarget),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton.filledTonal(
                onPressed: value > 1 ? () => _step(-1) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              IconButton.filledTonal(
                onPressed: value < kMalaMaxTarget ? () => _step(1) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.malaTargetHint(kMalaMaxTarget),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(materialL10n.cancelButtonLabel),
        ),
        TextButton(
          onPressed: value >= 1 ? _submit : null,
          child: Text(materialL10n.okButtonLabel),
        ),
      ],
    );
  }
}
