import 'dart:core';
import 'package:flutter/material.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/visualizer_service.dart';
import 'package:vidviz/model/visualizer.dart';
import 'package:vidviz/core/params.dart';
import 'package:vidviz/ui/widgets/visualizer/visualizer_form.dart';

/// VisualizerAssetEditor - TextAssetEditor'ün tam kopyası
/// Timeline üzerinde visualizer düzenleme paneli
class VisualizerAssetEditor extends StatelessWidget {
  final visualizerService = locator.get<VisualizerService>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: visualizerService.editingVisualizerAsset$,
      initialData: null,
      builder: (BuildContext context, AsyncSnapshot<VisualizerAsset?> editingVisualizerAsset) {
            if (editingVisualizerAsset.data == null) return Container();
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
                    color: Colors.purple,
                  ), // Mor renk visualizer için
                ),
              ),
              child: VisualizerForm(editingVisualizerAsset.data!),
            );
          },
    );
  }
}
