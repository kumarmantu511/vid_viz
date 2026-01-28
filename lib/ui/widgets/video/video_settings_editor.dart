import 'package:flutter/material.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/director_service.dart';
import 'package:vidviz/model/video_settings.dart';
import 'package:vidviz/core/params.dart';
import 'package:vidviz/ui/widgets/video/video_settings_form.dart';

class VideoSettingsEditor extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: directorService.editingVideoSettings$,
      initialData: null,
      builder: (BuildContext context, AsyncSnapshot<VideoSettings?> editingVideoSettings) {
            if (editingVideoSettings.data == null) return Container();
            final theme = Theme.of(context);
            return Container(
              // bu sınırı kilitliyordu biz bunu özgür bıoraktık artık boşluk bununca yereleşecek kendisi sorna daha iyi bakarız
              // height: Params.getTimelineHeight(context),
              width: MediaQuery.of(context).size.width,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: const Border(
                  top: BorderSide(width: 2, color: Colors.amber),
                ),
              ),
              child: VideoSettingsForm(editingVideoSettings.data!),
            );
          },
    );
  }
}
