import 'dart:core';
import 'package:flutter/material.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/shader_effect_service.dart';
import 'package:vidviz/model/shader_effect.dart';
import 'package:vidviz/core/params.dart';
import 'package:vidviz/ui/widgets/shader/shader_effect_form.dart';

/// ShaderEffectEditor - Timeline üzerinde shader effect düzenleme paneli
class ShaderEffectEditor extends StatelessWidget {
  final shaderEffectService = locator.get<ShaderEffectService>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: shaderEffectService.editingShaderEffectAsset$,
      initialData: null,
      builder: (BuildContext context, AsyncSnapshot<ShaderEffectAsset?> editingShaderEffectAsset) {
            if (editingShaderEffectAsset.data == null) return Container();
            final theme = Theme.of(context);
            return Container(
              // bu sınırı kilitliyordu biz bunu özgür bıoraktık artık boşluk bununca yereleşecek kendisi
              // height: Params.getTimelineHeight(context),
              width: MediaQuery.of(context).size.width,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: const Border(
                  top: BorderSide(
                    width: 2,
                    color: Colors.cyan,
                  ), // Cyan border like text editor
                ),
              ),
              child: ShaderEffectForm(editingShaderEffectAsset.data!),
            );
          },
    );
  }
}
