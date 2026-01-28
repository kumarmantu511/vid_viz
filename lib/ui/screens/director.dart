import 'dart:ui';
import 'dart:core';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/service/visualizer_service.dart';
import 'package:vidviz/service/shader_effect_service.dart';
import 'package:vidviz/service/media_overlay_service.dart';
import 'package:vidviz/model/project.dart';
import 'package:vidviz/core/params.dart';
import 'package:vidviz/ui/common/animated_dialog.dart';
import 'package:vidviz/ui/widgets/editor_main.dart';
import 'package:vidviz/l10n/generated/app_localizations.dart';

class DirectorScreen extends StatefulWidget {
  final Project project;
  const DirectorScreen(this.project, {Key? key}) : super(key: key);

  @override
  _DirectorScreen createState() => _DirectorScreen(project);
}

class _DirectorScreen extends State<DirectorScreen> with WidgetsBindingObserver {
  final directorService = locator.get<DirectorService>();
  StreamSubscription<bool>? _dialogFilesNotExistSubscription;

  _DirectorScreen(Project project) {
    // Ensure unique capture keys per route to prevent GlobalKey duplication
    directorService.regenerateCaptureKeys();
    directorService.setProject(project);

    _dialogFilesNotExistSubscription = directorService.filesNotExist$.listen((
      val,
    ) {
      if (val) {
        // Delayed because widgets are building
        Future.delayed(Duration(milliseconds: 100), () {
          final loc = AppLocalizations.of(context);
          AnimatedDialog.show(
            context,
            title: loc.directorMissingAssetsTitle,
            child: Text(
              loc.directorMissingAssetsMessage,
            ),
            button2Text: loc.commonOk,
            onPressedButton2: () {
              Navigator.of(context).pop();
            },
          );
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dialogFilesNotExistSubscription?.cancel();
    // Optional: regenerate keys on dispose to detach lingering reservations
    try {
      directorService.regenerateCaptureKeys();
    } catch (_) {}
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      Params.fixHeight = true;
    } else if (state == AppLifecycleState.resumed) {
      Params.fixHeight = false;
    }
  }

  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    // To release memory
    imageCache.clear();
  }

  @override
  Widget build(BuildContext context) {
    final visualizerService = locator.get<VisualizerService>();
    final shaderEffectService = locator.get<ShaderEffectService>();
    final mediaOverlayService = locator.get<MediaOverlayService>();

    return WillPopScope(
      onWillPop: () async {
        if (directorService.editingColor != null) {
          directorService.editingColor = null;
          return false;
        }
        if (directorService.editingTextAsset != null) {
          directorService.editingTextAsset = null;
          directorService.isAdding = false;
          return false;
        }
        if (visualizerService.editingVisualizerAsset != null) {
          visualizerService.editingVisualizerAsset = null;
          directorService.isAdding = false;
          return false;
        }
        if (shaderEffectService.editingShaderEffectAsset != null) {
          shaderEffectService.editingShaderEffectAsset = null;
          directorService.isAdding = false;
          return false;
        }
        if (mediaOverlayService.editingMediaOverlay != null) {
          mediaOverlayService.editingMediaOverlay = null;
          directorService.isAdding = false;
          return false;
        }
        bool exit = await directorService.exitAndSaveProject();
        if (exit) Navigator.pop(context);
        return false;
      },
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: GestureDetector(
            onTap: () {
              if (directorService.editingTextAsset == null) {
                directorService.select(-1, -1);
              }
              // Hide keyboard
              FocusScope.of(context).requestFocus(FocusNode());
            },
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: EditorMain(),
            ),
          ),
        ),
      ),
    );
  }
}




