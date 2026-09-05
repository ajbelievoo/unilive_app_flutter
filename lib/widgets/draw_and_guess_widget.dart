/// Draw and Guess interactive game widget for multi-guest rooms.
///
/// Provides a real-time drawing canvas (CustomPaint + GestureDetector),
/// a word display area (hidden from guessers), a color palette and brush
/// size selector for the drawer, a 60-second round timer, correct-guess
/// detection, and clear/undo controls. Drawing data is synced over socket
/// events so all guests see the strokes in real time.
library draw_and_guess_widget;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/socket_service.dart';
import '../utils/log.dart';

/// Socket event names for the Draw and Guess game.
///
/// These mirror the backend events used by the multi-guest room server.
class DrawAndGuessEvents {
  DrawAndGuessEvents._();

  /// Drawer emits a new stroke (or point on an active stroke).
  static const String stroke = 'drawStroke';

  /// Drawer clears the canvas.
  static const String clear = 'drawClear';

  /// Drawer undoes the last stroke.
  static const String undo = 'drawUndo';

  /// Host starts a new round (word + drawer assigned).
  static const String roundStart = 'drawRoundStart';

  /// Round timer expired / round ended.
  static const String roundEnd = 'drawRoundEnd';

  /// A guesser submits a guess.
  static const String guess = 'drawGuess';

  /// Backend notifies that a guess was correct.
  static const String correctGuess = 'drawCorrectGuess';
}

/// A single drawn stroke on the canvas.
///
/// A stroke is a sequence of points captured between pointer down and up,
/// rendered with a fixed color and stroke width. Normalised coordinates
/// (0.0-1.0) are used so the drawing is resolution-independent and can be
/// synced across devices with different screen sizes.
class DrawStroke {
  DrawStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  /// Normalised points (x,y in 0.0-1.0 relative to canvas size).
  final List<Offset> points;

  /// Stroke color.
  final Color color;

  /// Stroke width in logical pixels.
  final double strokeWidth;

  Map<String, dynamic> toJson() => {
    'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(growable: false),
    'color': color.toARGB32(),
    'strokeWidth': strokeWidth,
  };

  factory DrawStroke.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'];
    final points = <Offset>[];
    if (rawPoints is List) {
      for (final p in rawPoints) {
        if (p is Map) {
          points.add(
            Offset(
              (p['x'] as num?)?.toDouble() ?? 0,
              (p['y'] as num?)?.toDouble() ?? 0,
            ),
          );
        }
      }
    }
    return DrawStroke(
      points: points,
      color: Color(json['color'] as int? ?? 0xFF000000),
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 4.0,
    );
  }

  DrawStroke copyWith({List<Offset>? points}) => DrawStroke(
    points: points ?? this.points,
    color: color,
    strokeWidth: strokeWidth,
  );
}

/// Player score entry.
class DrawAndGuessScore {
  DrawAndGuessScore({
    required this.userId,
    required this.name,
    required this.score,
    required this.isDrawer,
  });

  final String userId;
  final String name;
  int score;
  bool isDrawer;
}

/// Game phase.
enum DrawAndGuessPhase { idle, drawing, guessing, roundOver }

/// Controller that manages the Draw and Guess game state.
///
/// Owns the current word, the current drawer id, the round timer, the list
/// of strokes (for local rendering + undo), and the player scores. Emits
/// socket events for stroke/clear/undo/roundStart/roundEnd and listens for
/// incoming strokes and correct-guess notifications.
class DrawAndGuessController extends ChangeNotifier {
  DrawAndGuessController({
    required this.roomId,
    required this.localUserId,
    this.roundDuration = const Duration(seconds: 60),
  }) {
    _registerSocketListeners();
  }

  static const String _tag = 'DrawAndGuessController';

  /// Room id used as the socket payload scope.
  final String roomId;

  /// The local user's id.
  final String localUserId;

  /// Per-round duration.
  final Duration roundDuration;

  /// Current game phase.
  DrawAndGuessPhase phase = DrawAndGuessPhase.idle;

  /// The word the drawer is drawing. Null when no round is active.
  String? currentWord;

  /// The user id of the current drawer.
  String? currentDrawerId;

  /// Whether the local user is the drawer.
  bool get isLocalDrawer => currentDrawerId == localUserId;

  /// Strokes rendered on the local canvas.
  final List<DrawStroke> _strokes = <DrawStroke>[];
  List<DrawStroke> get strokes => List.unmodifiable(_strokes);

  /// Currently active stroke (being drawn by the local user).
  DrawStroke? _activeStroke;
  DrawStroke? get activeStroke => _activeStroke;

  /// Selected brush color.
  Color brushColor = const Color(0xFF000000);

  /// Selected brush width.
  double brushWidth = 4.0;

  /// Remaining seconds in the round.
  int remainingSeconds = 0;

  /// Player scores for the current game session.
  final List<DrawAndGuessScore> _scores = <DrawAndGuessScore>[];
  List<DrawAndGuessScore> get scores => List.unmodifiable(_scores);

  /// Most recent correct-guess winner (userId), if any.
  String? lastWinnerId;

  Timer? _timer;
  final List<VoidCallback> _socketCancellations = [];

  /// Canvas size captured from the last layout, used to normalise points.
  Size _canvasSize = Size.zero;
  Size get canvasSize => _canvasSize;

  set canvasSize(Size size) {
    if (size != _canvasSize) {
      _canvasSize = size;
    }
  }

  /// Normalise a local point to 0.0-1.0 relative to the canvas size.
  Offset normalise(Offset point) {
    if (_canvasSize.isEmpty) return Offset.zero;
    return Offset(
      (point.dx / _canvasSize.width).clamp(0.0, 1.0),
      (point.dy / _canvasSize.height).clamp(0.0, 1.0),
    );
  }

  /// Convert a normalised point back to local canvas coordinates.
  Offset denormalise(Offset point) {
    if (_canvasSize.isEmpty) return Offset.zero;
    return Offset(point.dx * _canvasSize.width, point.dy * _canvasSize.height);
  }

  void _registerSocketListeners() {
    _socketCancellations
      ..add(
        SocketService.instance.on(DrawAndGuessEvents.stroke, _onRemoteStroke),
      )
      ..add(SocketService.instance.on(DrawAndGuessEvents.clear, _onRemoteClear))
      ..add(SocketService.instance.on(DrawAndGuessEvents.undo, _onRemoteUndo))
      ..add(
        SocketService.instance.on(
          DrawAndGuessEvents.roundStart,
          _onRemoteRoundStart,
        ),
      )
      ..add(
        SocketService.instance.on(
          DrawAndGuessEvents.roundEnd,
          _onRemoteRoundEnd,
        ),
      )
      ..add(
        SocketService.instance.on(
          DrawAndGuessEvents.correctGuess,
          _onRemoteCorrectGuess,
        ),
      );
  }

  /// Start a new round as the host/drawer.
  void startRound({required String word, required String drawerId}) {
    currentWord = word;
    currentDrawerId = drawerId;
    lastWinnerId = null;
    _strokes.clear();
    _activeStroke = null;
    remainingSeconds = roundDuration.inSeconds;
    phase = DrawAndGuessPhase.drawing;
    notifyListeners();
    _emitRoundStart();
    _startTimer();
    Log.d(_tag, 'round started: word="$word", drawer=$drawerId');
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remainingSeconds > 0) {
        remainingSeconds--;
        notifyListeners();
      } else {
        endRound(reason: 'timeout');
      }
    });
  }

  /// End the current round.
  void endRound({String reason = 'manual'}) {
    _timer?.cancel();
    _timer = null;
    phase = DrawAndGuessPhase.roundOver;
    notifyListeners();
    _emitRoundEnd(reason);
    Log.d(_tag, 'round ended: $reason');
  }

  /// Begin a new stroke at [point] (local user is drawing).
  void beginStroke(Offset point) {
    if (!isLocalDrawer || phase != DrawAndGuessPhase.drawing) return;
    final normalised = normalise(point);
    _activeStroke = DrawStroke(
      points: [normalised],
      color: brushColor,
      strokeWidth: brushWidth,
    );
    notifyListeners();
    _emitStrokePoint(normalised, isNew: true);
  }

  /// Continue the active stroke at [point].
  void extendStroke(Offset point) {
    if (!isLocalDrawer || _activeStroke == null) return;
    final normalised = normalise(point);
    final last = _activeStroke!.points.last;
    // Skip near-duplicate points to reduce payload size.
    if ((normalised - last).distance < 0.005) return;
    _activeStroke = _activeStroke!.copyWith(
      points: [..._activeStroke!.points, normalised],
    );
    notifyListeners();
    _emitStrokePoint(normalised, isNew: false);
  }

  /// Finalise the active stroke and commit it.
  void endStroke() {
    if (!isLocalDrawer || _activeStroke == null) return;
    if (_activeStroke!.points.length > 1) {
      _strokes.add(_activeStroke!);
    }
    _activeStroke = null;
    notifyListeners();
  }

  /// Undo the last committed stroke (drawer only).
  void undo() {
    if (!isLocalDrawer || _strokes.isEmpty) return;
    _strokes.removeLast();
    notifyListeners();
    SocketService.instance.emit(DrawAndGuessEvents.undo, {
      'roomId': roomId,
      'userId': localUserId,
    });
    Log.d(_tag, 'undo emitted');
  }

  /// Clear the whole canvas (drawer only).
  void clear() {
    if (!isLocalDrawer) return;
    _strokes.clear();
    _activeStroke = null;
    notifyListeners();
    SocketService.instance.emit(DrawAndGuessEvents.clear, {
      'roomId': roomId,
      'userId': localUserId,
    });
    Log.d(_tag, 'clear emitted');
  }

  /// Submit a guess (guesser only).
  void submitGuess(String text) {
    if (isLocalDrawer || phase != DrawAndGuessPhase.drawing) return;
    SocketService.instance.emit(DrawAndGuessEvents.guess, {
      'roomId': roomId,
      'userId': localUserId,
      'text': text,
    });
    Log.d(_tag, 'guess submitted: "$text"');
  }

  /// Mark a guess as correct (host/drawer confirms). Typically the backend
  /// validates the guess and emits [DrawAndGuessEvents.correctGuess].
  void markCorrectGuess({
    required String winnerId,
    required String winnerName,
  }) {
    final entry = _scoreEntry(winnerId);
    if (entry != null) {
      entry.score += 100;
    } else {
      _scores.add(
        DrawAndGuessScore(
          userId: winnerId,
          name: winnerName,
          score: 100,
          isDrawer: false,
        ),
      );
    }
    // The drawer also gets a smaller reward.
    if (currentDrawerId != null) {
      final drawer = _scoreEntry(currentDrawerId!);
      if (drawer != null) {
        drawer.score += 50;
      }
    }
    lastWinnerId = winnerId;
    notifyListeners();
    endRound(reason: 'correct');
  }

  DrawAndGuessScore? _scoreEntry(String userId) {
    for (final s in _scores) {
      if (s.userId == userId) return s;
    }
    return null;
  }

  // ---- Socket emit helpers ----

  void _emitRoundStart() {
    SocketService.instance.emit(DrawAndGuessEvents.roundStart, {
      'roomId': roomId,
      'drawerId': currentDrawerId,
      'word': isLocalDrawer ? currentWord : null,
      'duration': roundDuration.inSeconds,
    });
  }

  void _emitRoundEnd(String reason) {
    SocketService.instance.emit(DrawAndGuessEvents.roundEnd, {
      'roomId': roomId,
      'reason': reason,
    });
  }

  void _emitStrokePoint(Offset normalised, {required bool isNew}) {
    SocketService.instance.emit(DrawAndGuessEvents.stroke, {
      'roomId': roomId,
      'userId': localUserId,
      'x': normalised.dx,
      'y': normalised.dy,
      'color': brushColor.toARGB32(),
      'strokeWidth': brushWidth,
      'isNew': isNew,
    });
  }

  // ---- Socket receive handlers ----

  void _onRemoteStroke(dynamic data) {
    final map = data is Map<String, dynamic> ? data : <String, dynamic>{};
    if (map['roomId'] != roomId) return;
    final drawerId = map['userId']?.toString() ?? '';
    if (drawerId != currentDrawerId) return;
    final x = (map['x'] as num?)?.toDouble() ?? 0;
    final y = (map['y'] as num?)?.toDouble() ?? 0;
    final point = Offset(x, y);
    final color = Color(map['color'] as int? ?? 0xFF000000);
    final width = (map['strokeWidth'] as num?)?.toDouble() ?? 4.0;
    final isNew = map['isNew'] == true;
    if (isNew) {
      _activeStroke = DrawStroke(
        points: [point],
        color: color,
        strokeWidth: width,
      );
    } else if (_activeStroke != null) {
      _activeStroke = _activeStroke!.copyWith(
        points: [..._activeStroke!.points, point],
      );
    }
    notifyListeners();
  }

  void _onRemoteClear(dynamic data) {
    final map = data is Map<String, dynamic> ? data : <String, dynamic>{};
    if (map['roomId'] != roomId) return;
    _strokes.clear();
    _activeStroke = null;
    notifyListeners();
  }

  void _onRemoteUndo(dynamic data) {
    final map = data is Map<String, dynamic> ? data : <String, dynamic>{};
    if (map['roomId'] != roomId) return;
    if (_strokes.isNotEmpty) _strokes.removeLast();
    notifyListeners();
  }

  void _onRemoteRoundStart(dynamic data) {
    final map = data is Map<String, dynamic> ? data : <String, dynamic>{};
    if (map['roomId'] != roomId) return;
    currentDrawerId = map['drawerId']?.toString();
    // The word is only sent to the drawer; guessers receive null.
    final word = map['word']?.toString();
    if (word != null && word.isNotEmpty) {
      currentWord = word;
    } else if (!isLocalDrawer) {
      // Guessers do not see the word.
      currentWord = null;
    }
    final duration =
        (map['duration'] as num?)?.toInt() ?? roundDuration.inSeconds;
    _strokes.clear();
    _activeStroke = null;
    remainingSeconds = duration;
    phase = DrawAndGuessPhase.drawing;
    notifyListeners();
    _startTimer();
    Log.d(_tag, 'remote round start: drawer=$currentDrawerId');
  }

  void _onRemoteRoundEnd(dynamic data) {
    final map = data is Map<String, dynamic> ? data : <String, dynamic>{};
    if (map['roomId'] != roomId) return;
    _timer?.cancel();
    _timer = null;
    phase = DrawAndGuessPhase.roundOver;
    notifyListeners();
    Log.d(_tag, 'remote round end: ${map['reason']}');
  }

  void _onRemoteCorrectGuess(dynamic data) {
    final map = data is Map<String, dynamic> ? data : <String, dynamic>{};
    if (map['roomId'] != roomId) return;
    final winnerId = map['winnerId']?.toString() ?? '';
    final winnerName = map['winnerName']?.toString() ?? '';
    final word = map['word']?.toString();
    if (word != null) currentWord = word;
    markCorrectGuess(winnerId: winnerId, winnerName: winnerName);
  }

  @override
  void dispose() {
    for (final cancel in _socketCancellations) {
      cancel();
    }
    _socketCancellations.clear();
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}

/// Painter that renders all committed strokes plus the active stroke.
class _DrawCanvasPainter extends CustomPainter {
  _DrawCanvasPainter({
    required this.strokes,
    required this.activeStroke,
    required this.canvasSize,
  });

  final List<DrawStroke> strokes;
  final DrawStroke? activeStroke;
  final Size canvasSize;

  @override
  void paint(Canvas canvas, Size size) {
    // Fill background.
    final bgPaint = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRect(Offset.zero & size, bgPaint);

    void renderStroke(DrawStroke stroke) {
      if (stroke.points.length < 2) return;
      final paint =
          Paint()
            ..color = stroke.color
            ..strokeWidth = stroke.strokeWidth
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..style = PaintingStyle.stroke;
      final path = Path();
      final first = _denorm(stroke.points.first, size);
      path.moveTo(first.dx, first.dy);
      for (var i = 1; i < stroke.points.length; i++) {
        final p = _denorm(stroke.points[i], size);
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }

    for (final s in strokes) {
      renderStroke(s);
    }
    if (activeStroke != null) {
      renderStroke(activeStroke!);
    }
  }

  Offset _denorm(Offset p, Size size) =>
      Offset(p.dx * size.width, p.dy * size.height);

  @override
  bool shouldRepaint(covariant _DrawCanvasPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.activeStroke != activeStroke ||
        oldDelegate.canvasSize != canvasSize;
  }
}

/// The Draw and Guess game widget.
///
/// Embed this inside a multi-guest room. Pass a [DrawAndGuessController]
/// whose [DrawAndGuessController.roomId] matches the live room id and
/// [DrawAndGuessController.localUserId] is the current user.
class DrawAndGuessWidget extends StatefulWidget {
  const DrawAndGuessWidget({super.key, required this.controller});

  final DrawAndGuessController controller;

  @override
  State<DrawAndGuessWidget> createState() => _DrawAndGuessWidgetState();
}

class _DrawAndGuessWidgetState extends State<DrawAndGuessWidget> {
  static const String _tag = 'DrawAndGuessWidget';

  /// Available palette colors.
  static const List<Color> _palette = [
    Color(0xFF000000),
    Color(0xFFFFFFFF),
    Color(0xFFE53935),
    Color(0xFFFB8C00),
    Color(0xFFFDD835),
    Color(0xFF43A047),
    Color(0xFF1E88E5),
    Color(0xFF8E24AA),
    Color(0xFF6D4C41),
    Color(0xFF9E9E9E),
  ];

  /// Available brush widths.
  static const List<double> _brushSizes = [2, 4, 8, 14, 22];

  final TextEditingController _guessController = TextEditingController();
  final GlobalKey _canvasKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    Log.d(_tag, 'init');
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _guessController.dispose();
    Log.d(_tag, 'dispose');
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Offset _localPoint(Offset globalPoint) {
    final renderBox =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return Offset.zero;
    return renderBox.globalToLocal(globalPoint);
  }

  void _onPanStart(DragStartDetails details) {
    final point = _localPoint(details.globalPosition);
    widget.controller.beginStroke(point);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final point = _localPoint(details.globalPosition);
    widget.controller.extendStroke(point);
  }

  void _onPanEnd(DragEndDetails _) {
    widget.controller.endStroke();
  }

  void _submitGuess() {
    final text = _guessController.text.trim();
    if (text.isEmpty) return;
    widget.controller.submitGuess(text);
    _guessController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(controller),
              const SizedBox(height: 8),
              _buildWordArea(controller),
              const SizedBox(height: 8),
              _buildCanvas(controller),
              const SizedBox(height: 8),
              if (controller.isLocalDrawer) _buildToolPalette(controller),
              if (!controller.isLocalDrawer &&
                  controller.phase == DrawAndGuessPhase.drawing)
                _buildGuessInput(),
              const SizedBox(height: 8),
              _buildScoreBoard(controller),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(DrawAndGuessController controller) {
    final total = controller.roundDuration.inSeconds;
    final progress = total == 0 ? 0.0 : controller.remainingSeconds / total;
    final color =
        controller.remainingSeconds <= 10
            ? const Color(0xFFFF5252)
            : const Color(0xFF4CAF50);
    return Row(
      children: [
        const Text(
          'Draw and Guess',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            strokeWidth: 3,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${controller.remainingSeconds}s',
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildWordArea(DrawAndGuessController controller) {
    final String display;
    if (controller.phase == DrawAndGuessPhase.idle) {
      display = 'Waiting to start...';
    } else if (controller.phase == DrawAndGuessPhase.roundOver) {
      display = 'Word was: ${controller.currentWord ?? '-'}';
    } else if (controller.isLocalDrawer) {
      display = 'Draw: ${controller.currentWord ?? '-'}';
    } else {
      // Guessers see underscores for each letter.
      final word = controller.currentWord ?? '';
      display =
          word.isEmpty
              ? 'Guess the drawing!'
              : List.generate(word.length, (_) => '_ ').join().trim();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        display,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildCanvas(DrawAndGuessController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = math.min(width * 0.62, 260.0);
        final size = Size(width, height);
        // Capture canvas size for coordinate normalisation.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          controller.canvasSize = size;
        });
        return Container(
          key: _canvasKey,
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              onPanStart: controller.isLocalDrawer ? _onPanStart : null,
              onPanUpdate: controller.isLocalDrawer ? _onPanUpdate : null,
              onPanEnd: controller.isLocalDrawer ? _onPanEnd : null,
              child: CustomPaint(
                size: size,
                painter: _DrawCanvasPainter(
                  strokes: controller.strokes,
                  activeStroke: controller.activeStroke,
                  canvasSize: size,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildToolPalette(DrawAndGuessController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Color palette.
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _palette.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final color = _palette[index];
              final selected = controller.brushColor == color;
              return GestureDetector(
                onTap: () {
                  controller.brushColor = color;
                  setState(() {});
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          selected ? const Color(0xFFFFD600) : Colors.white24,
                      width: selected ? 3 : 1,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Brush size selector.
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _brushSizes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final size = _brushSizes[index];
              final selected = (controller.brushWidth - size).abs() < 0.5;
              return GestureDetector(
                onTap: () {
                  controller.brushWidth = size;
                  setState(() {});
                },
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF16213E),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          selected ? const Color(0xFFFFD600) : Colors.white24,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Container(
                    width: size,
                    height: size,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Action buttons.
        Row(
          children: [
            _actionButton(
              icon: Icons.undo,
              label: 'Undo',
              onTap: controller.undo,
            ),
            const SizedBox(width: 8),
            _actionButton(
              icon: Icons.delete_outline,
              label: 'Clear',
              onTap: controller.clear,
            ),
            const Spacer(),
            if (controller.phase == DrawAndGuessPhase.idle ||
                controller.phase == DrawAndGuessPhase.roundOver)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E3FF2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: () => _showStartDialog(controller),
                child: const Text('Start Round'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuessInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _guessController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Type your guess...',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF16213E),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => _submitGuess(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _submitGuess,
          icon: const Icon(Icons.send, color: Color(0xFF7E3FF2)),
        ),
      ],
    );
  }

  Widget _buildScoreBoard(DrawAndGuessController controller) {
    if (controller.scores.isEmpty) {
      return const SizedBox(
        height: 24,
        child: Center(
          child: Text(
            'No scores yet',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
      );
    }
    final sorted = [...controller.scores]
      ..sort((a, b) => b.score.compareTo(a.score));
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sorted.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final s = sorted[index];
          final isWinner = s.userId == controller.lastWinnerId;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isWinner ? const Color(0xFFFFD600) : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  s.isDrawer ? Icons.brush : Icons.person,
                  color: Colors.white70,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  s.name,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const SizedBox(width: 4),
                Text(
                  '${s.score}',
                  style: const TextStyle(
                    color: Color(0xFFFFD600),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showStartDialog(DrawAndGuessController controller) {
    final wordController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Start Draw and Guess'),
          content: TextField(
            controller: wordController,
            decoration: const InputDecoration(
              labelText: 'Word to draw',
              hintText: 'e.g. apple',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E3FF2),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final word = wordController.text.trim();
                if (word.isEmpty) return;
                controller.startRound(
                  word: word,
                  drawerId: controller.localUserId,
                );
                Navigator.of(ctx).pop();
              },
              child: const Text('Start'),
            ),
          ],
        );
      },
    );
  }
}
