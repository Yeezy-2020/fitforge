import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/settings_providers.dart';

class RestTimer extends ConsumerStatefulWidget {
  final bool expanded;
  final VoidCallback onToggle;
  const RestTimer({super.key, required this.expanded, required this.onToggle});

  @override
  ConsumerState<RestTimer> createState() => _RestTimerState();
}

class _RestTimerState extends ConsumerState<RestTimer>
    with TickerProviderStateMixin {
  int _seconds = 90;
  int _remaining = 0;
  bool _running = false;
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _anim.addListener(() {
      if (_anim.isCompleted && _running) {
        setState(() {
          if (_remaining > 0) _remaining--;
          if (_remaining == 0) _running = false;
        });
        if (_remaining > 0) _anim.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _start() {
    if (_remaining == 0) _remaining = _seconds;
    _running = true;
    _anim.forward(from: 0);
    setState(() {});
  }

  void _pause() {
    _running = false;
    _anim.stop();
    setState(() {});
  }

  void _reset() {
    _running = false;
    _remaining = 0;
    _anim.reset();
    setState(() {});
  }

  void _showTimePicker() {
    final l10n = ref.read(l10nProvider);
    int mins = _seconds ~/ 60;
    int secs = _seconds % 60;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SizedBox(
        height: 280,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(l10n.get('cancel')),
                  ),
                  const Spacer(),
                  Text(
                    l10n.get('restTimerTitle'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _seconds = mins * 60 + secs;
                        _reset();
                      });
                    },
                    child: Text(
                      l10n.get('setLabel'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: CupertinoTimerPicker(
                mode: CupertinoTimerPickerMode.ms,
                initialTimerDuration: Duration(minutes: mins, seconds: secs),
                onTimerDurationChanged: (d) {
                  mins = d.inMinutes;
                  secs = d.inSeconds % 60;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(l10nProvider);
    final mins = _seconds ~/ 60;
    final secs = _seconds % 60;
    final timeLabel =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    if (!widget.expanded) {
      return GestureDetector(
        onTap: widget.onToggle,
        onVerticalDragUpdate: (details) {
          if (details.delta.dy < -8) widget.onToggle();
        },
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: 64,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.colorScheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              Icons.keyboard_arrow_up_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: widget.onToggle,
            onVerticalDragUpdate: (details) {
              if (details.delta.dy > 8) widget.onToggle();
            },
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: GestureDetector(
              onTap: _showTimePicker,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    width: 2,
                    color: theme.colorScheme.primary,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  timeLabel,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            flex: 2,
            child: Text(
              _running ? '${_remaining}s' : l10n.get('readyLabel'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: _remaining <= 10 && _running ? Colors.red : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (!_running)
            IconButton(
              constraints: const BoxConstraints.tightFor(width: 38, height: 38),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.play_arrow, color: Colors.green, size: 30),
              onPressed: _start,
            )
          else
            IconButton(
              constraints: const BoxConstraints.tightFor(width: 38, height: 38),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.pause, color: Colors.orange, size: 30),
              onPressed: _pause,
            ),
          IconButton(
            constraints: const BoxConstraints.tightFor(width: 36, height: 38),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.stop, size: 26),
            onPressed: _reset,
          ),
        ],
      ),
    );
  }
}
