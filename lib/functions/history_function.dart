part of 'package:vidviz/service/director_service.dart';

extension HistoryFunction on DirectorService {



  /// Undo last action
  Future<void> undo() async {
    if (!canUndo) {
      logger.w('⚠️ Cannot undo: at beginning of history');
      return;
    }

    if (isOperating) {
      logger.w('⚠️ Cannot undo: operation in progress');
      return;
    }

    _historyIndex--;
    await _restoreFromHistory();
    logger.i('↩️ Undo: restored to index $_historyIndex');
  }

  /// Redo last undone action
  Future<void> redo() async {
    if (!canRedo) {
      logger.w('⚠️ Cannot redo: at end of history');
      return;
    }

    if (isOperating) {
      logger.w('⚠️ Cannot redo: operation in progress');
      return;
    }

    _historyIndex++;
    await _restoreFromHistory();
    logger.i('↪️ Redo: restored to index $_historyIndex');
  }

  /// Save current layers state to history stack
  void _saveToHistory() {
    if (layers == null) return;

    try {
      final snapshot = json.encode(layers);

      // Duplicate check: don't save if identical to current snapshot
      if (_historyStack.isNotEmpty &&
          _historyIndex >= 0 &&
          _historyIndex < _historyStack.length) {
        if (_historyStack[_historyIndex] == snapshot) {
          logger.i('⏭️ Skipping duplicate snapshot');
          return;
        }
      }

      // Remove any future history if we're not at the end
      if (_historyIndex < _historyStack.length - 1) {
        _historyStack.removeRange(_historyIndex + 1, _historyStack.length);
      }

      // Add new snapshot
      _historyStack.add(snapshot);
      _historyIndex = _historyStack.length - 1;

      // Limit stack size
      if (_historyStack.length > DirectorService.MAX_HISTORY_SIZE) {
        _historyStack.removeAt(0);
        _historyIndex--;
      }

      _historyChanged.add(true);
      logger.i(
        '📸 History saved: index=$_historyIndex, stack size=${_historyStack.length}',
      );
    } catch (e) {
      logger.e('❌ Failed to save history: $e');
    }
  }


  /// Restore layers from history snapshot
  Future<void> _restoreFromHistory() async {
    if (_historyIndex < 0 || _historyIndex >= _historyStack.length) return;

    try {
      _isUndoRedoOperation = true; // Prevent recursive save

      final snapshot = _historyStack[_historyIndex];
      final List<dynamic> layersJson = json.decode(snapshot);

      // Dispose old players
      for (var player in layerPlayers) {
        player?.dispose();
      }
      layerPlayers.clear();

      // Restore layers
      layers = layersJson.map((l) => Layer.fromJson(l)).toList();

      // Recreate players for raster/audio layers
      for (int i = 0; i < layers!.length; i++) {
        if (layers![i].type == 'raster' || layers![i].type == 'audio') {
          final player = LayerPlayer(layers![i]);
          layerPlayers.add(player);
          await player.initialize();
        } else {
          layerPlayers.add(null); // Overlay layers don't need players
        }
      }

      // Reset selection and refresh UI
      _selected.add(Selected(-1, -1));
      _historyChanged.add(true);
      _appBar.add(true);

      // Trigger UI refresh AFTER resetting flag to prevent save
      _isUndoRedoOperation = false;
      _layersChanged.add(true);

      // Preview at current position (await to ensure isPreviewing is reset)
      await Future.delayed(Duration(milliseconds: 100));
      await _previewOnPosition();
    } catch (e) {
      logger.e('❌ Failed to restore from history: $e');
      _isUndoRedoOperation = false;
    }
  }


}