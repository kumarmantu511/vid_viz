import 'dart:core';
import 'package:flutter/material.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/media_overlay_service.dart';
import 'package:vidviz/model/media_overlay.dart';
import 'package:vidviz/core/params.dart';
import 'package:vidviz/ui/widgets/media_overlay/media_overlay_form.dart';

/// MediaOverlayEditor - Timeline üzerinde media overlay düzenleme paneli
/// VisualizerAssetEditor ve ShaderEffectEditor pattern'ini takip eder
class MediaOverlayEditor extends StatelessWidget {
  final mediaOverlayService = locator.get<MediaOverlayService>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: mediaOverlayService.editingMediaOverlay$,
      initialData: null,
      builder: (BuildContext context, AsyncSnapshot<MediaOverlayAsset?> editingMediaOverlay,) {
            if (editingMediaOverlay.data == null) return Container();
            final theme = Theme.of(context);
            return Container(
              // bu sınırı kilitliyordu biz bunu özgür bıoraktık artık boşluk bununca yereleşecek kendisi sorna daha iyi bakarız
              // height: Params.getTimelineHeight(context),
              width: MediaQuery.of(context).size.width,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: const Border(
                  top: BorderSide(
                    width: 2,
                    color: Colors.teal,
                  ), // Teal border for media overlay
                ),
              ),
              child: MediaOverlayForm(editingMediaOverlay.data!),
            );
          },
    );
  }
}
