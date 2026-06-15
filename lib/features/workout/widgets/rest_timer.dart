import 'package:flutter/material.dart';

class RestTimer extends StatefulWidget {
  final bool expanded;
  final VoidCallback onToggle;
  const RestTimer({super.key, required this.expanded, required this.onToggle});

  @override
  State<RestTimer> createState() => _RestTimerState();
}

class _RestTimerState extends State<RestTimer> with TickerProviderStateMixin {
  int _seconds = 90;
  int _remaining = 0;
  bool _running = false;
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 1));
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

  void _pause() { _running = false; _anim.stop(); setState(() {}); }
  void _reset() { _running = false; _remaining = 0; _anim.reset(); setState(() {}); }

  void _showTimePicker() {
    int mins = _seconds ~/ 60;
    int secs = _seconds % 60;
    final minCtrl = FixedExtentScrollController(initialItem: mins.clamp(0, 59));
    final secCtrl = FixedExtentScrollController(initialItem: secs.clamp(0, 59));

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return SizedBox(
            height: 260,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  const Spacer(),
                  Text('Rest Timer', style: Theme.of(ctx).textTheme.titleMedium),
                  const Spacer(),
                  TextButton(onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _seconds = mins * 60 + secs;
                      _reset();
                    });
                  }, child: const Text('Set', style: TextStyle(fontWeight: FontWeight.bold))),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: Row(children: [
                  Expanded(child: Column(children: [
                    const SizedBox(height: 8),
                    Text('min', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                    Expanded(
                  child: ListWheelScrollView.useDelegate(
                    controller: minCtrl,
                    itemExtent: 42,
                    diameterRatio: 1.2,
                    perspective: 0.005,
                        onSelectedItemChanged: (i) => setSheetState(() => mins = i),
                    childDelegate: ListWheelChildBuilderDelegate(
                      builder: (ctx, i) => Center(child: Text('$i', style: TextStyle(fontSize: 26, fontWeight: i == mins ? FontWeight.bold : FontWeight.normal, color: i == mins ? Theme.of(ctx).colorScheme.primary : Colors.grey))),
                      childCount: 60,
                    ),
                  ),
                ),
              ])),
              const SizedBox(width: 4),
              const Text(':', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
                  Expanded(child: Column(children: [
                    const SizedBox(height: 8),
                    Text('sec', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                    Expanded(
                    child: ListWheelScrollView.useDelegate(
                      controller: secCtrl,
                      itemExtent: 42,
                      diameterRatio: 1.2,
                      perspective: 0.005,
                        onSelectedItemChanged: (i) => setSheetState(() => secs = i),
                        childDelegate: ListWheelChildBuilderDelegate(
                          builder: (ctx, i) => Center(child: Text('${i.toString().padLeft(2, '0')}', style: TextStyle(fontSize: 26, fontWeight: i == secs ? FontWeight.bold : FontWeight.normal, color: i == secs ? Theme.of(ctx).colorScheme.primary : Colors.grey))),
                          childCount: 60,
                        ),
                      ),
                    ),
                  ])),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mins = _seconds ~/ 60;
    final secs = _seconds % 60;
    final timeLabel = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    if (!widget.expanded) {
      return GestureDetector(
        onTap: widget.onToggle,
        child: Container(
          padding: const EdgeInsets.all(8),
          color: theme.colorScheme.surfaceContainerHighest,
          child: Center(child: Text('Rest: $timeLabel  ▴', style: theme.textTheme.bodySmall)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        GestureDetector(
          onTap: _showTimePicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(width: 2, color: theme.colorScheme.primary),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(timeLabel, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
          ),
        ),
        const SizedBox(width: 16),
        Text(_running ? '${_remaining}s' : 'Ready', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: _remaining <= 10 && _running ? Colors.red : null)),
        const SizedBox(width: 16),
        if (!_running)
          IconButton(icon: const Icon(Icons.play_arrow, color: Colors.green, size: 32), onPressed: _start)
        else
          IconButton(icon: const Icon(Icons.pause, color: Colors.orange, size: 32), onPressed: _pause),
        IconButton(icon: const Icon(Icons.stop, size: 28), onPressed: _reset),
        IconButton(icon: const Icon(Icons.keyboard_arrow_down), onPressed: widget.onToggle),
      ]),
    );
  }
}
