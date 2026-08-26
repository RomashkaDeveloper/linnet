import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AudioMessagePlayer extends StatefulWidget {
  final String audioUrl;
  final Color foreground;

  const AudioMessagePlayer({super.key, required this.audioUrl, required this.foreground});

  @override
  State<AudioMessagePlayer> createState() => _AudioMessagePlayerState();
}

class _AudioMessagePlayerState extends State<AudioMessagePlayer> {
  late final AudioPlayer _player;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.setUrl(widget.audioUrl).then((_) {
      if (mounted) setState(() => _loading = false);
    }).catchError((e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString();
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration? d) {
    if (d == null) return '0:00';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.inMinutes}:${two(d.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: widget.foreground, size: 18),
          const SizedBox(width: 6),
          Text('Не удалось загрузить аудио', style: TextStyle(color: widget.foreground)),
        ],
      );
    }
    if (_loading) {
      return SizedBox(
        width: 180,
        height: 36,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: widget.foreground),
          ),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 240),
      child: StreamBuilder<PlayerState>(
        stream: _player.playerStateStream,
        builder: (context, snapshot) {
          final playing = snapshot.data?.playing ?? false;
          final processingState = snapshot.data?.processingState;
          final completed = processingState == ProcessingState.completed;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkResponse(
                onTap: () {
                  if (completed) {
                    _player.seek(Duration.zero);
                    _player.play();
                  } else if (playing) {
                    _player.pause();
                  } else {
                    _player.play();
                  }
                },
                child: Icon(
                  completed
                      ? Icons.replay
                      : playing
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                  color: widget.foreground,
                  size: 34,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  builder: (context, posSnapshot) {
                    final position = posSnapshot.data ?? Duration.zero;
                    final duration = _player.duration ?? Duration.zero;
                    final total = duration.inMilliseconds == 0 ? 1 : duration.inMilliseconds;
                    final progress = (position.inMilliseconds / total).clamp(0.0, 1.0);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                            overlayShape: SliderComponentShape.noOverlay,
                            activeTrackColor: widget.foreground,
                            inactiveTrackColor: widget.foreground.withOpacity(0.3),
                            thumbColor: widget.foreground,
                          ),
                          child: Slider(
                            value: progress,
                            onChanged: (v) {
                              final target = Duration(milliseconds: (v * total).round());
                              _player.seek(target);
                            },
                          ),
                        ),
                        Text(
                          '${_fmt(position)} / ${_fmt(duration)}',
                          style: TextStyle(color: widget.foreground.withOpacity(0.85), fontSize: 11),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
