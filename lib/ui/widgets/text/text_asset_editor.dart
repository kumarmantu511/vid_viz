import 'dart:core';
import 'package:flutter/material.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/model/text_asset.dart';
import 'package:vidviz/core/params.dart';
import 'package:vidviz/ui/widgets/text/text_form.dart';

class TextAssetEditor extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: directorService.editingTextAsset$,
      initialData: null,
      builder: (BuildContext context, AsyncSnapshot<TextAsset?> editingTextAsset) {
            if (editingTextAsset.data == null) return Container();
            final theme = Theme.of(context);
            return Container(
              // bu sınırı kilitliyordu biz bunu özgür bıoraktık artık boşluk bununca yereleşecek kendisi sorna daha iyi bakarız
              // height: Params.getTimelineHeight(context),
              width: MediaQuery.of(context).size.width,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: const Border(
                  top: BorderSide(width: 2, color: Colors.blue),
                ),
              ),
              child: TextForm(editingTextAsset.data!),
            );
          },
    );
  }
}
