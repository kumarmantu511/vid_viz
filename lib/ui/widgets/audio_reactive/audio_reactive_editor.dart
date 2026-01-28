import 'dart:core';
import 'package:flutter/material.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/audio_reactive_service.dart';
import 'package:vidviz/model/audio_reactive.dart';
import 'package:vidviz/core/params.dart';
import 'package:vidviz/ui/widgets/audio_reactive/audio_reactive_form.dart';

/// AudioReactiveEditor - Timeline üzerinde audio reactive düzenleme paneli
/// MediaOverlayEditor ve VisualizerAssetEditor pattern'ini takip eder
class AudioReactiveEditor extends StatelessWidget {
  final audioReactiveService = locator.get<AudioReactiveService>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: audioReactiveService.editingAudioReactive$,
      initialData: null,
      builder: (BuildContext context, AsyncSnapshot<AudioReactiveAsset?> editingAudioReactive) {
            if (editingAudioReactive.data == null) return Container();
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
                    color: Colors.deepPurple,
                  ), // Deep Purple border for audio reactive
                ),
              ),
              child: AudioReactiveForm(editingAudioReactive.data!),
            );
          },
    );
  }
}
