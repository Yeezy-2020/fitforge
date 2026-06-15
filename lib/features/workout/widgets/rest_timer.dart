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
  void _adjust(int delta) { _seconds = (_seconds + delta).clamp(5, 600); _reset(); }

  @override
  Widget build(BuildContext context) {
    if (!widget.expanded) {
      return GestureDetector(
        onTap: widget.onToggle,
        child: Container(
          padding: const EdgeInsets.all(8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(child: Text('Rest Timer: ${_seconds}s  ▸', style: Theme.of(context).textTheme.bodySmall)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(icon: const Icon(Icons.remove), onPressed: () => _adjust(-15)),
        Text('${_seconds}s', style: Theme.of(context).textTheme.titleMedium),
        IconButton(icon: const Icon(Icons.add), onPressed: () => _adjust(15)),
        const SizedBox(width: 12),
            Text(_running || _remaining > 0 ? '${_remaining}s' : 'Ready', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: _remaining <= 10 && _running ? Colors.red : null)),
        const SizedBox(width: 12),
        if (!_running)
          IconButton(icon: const Icon(Icons.play_arrow, color: Colors.green), onPressed: _start)
        else
          IconButton(icon: const Icon(Icons.pause, color: Colors.orange), onPressed: _pause),
        IconButton(icon: const Icon(Icons.stop), onPressed: _reset),
        IconButton(icon: const Icon(Icons.keyboard_arrow_up), onPressed: widget.onToggle),
      ]),
    );
  }
}
