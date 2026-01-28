import 'package:flutter/material.dart';
import 'package:vidviz/model/visualizer.dart';
import 'package:vidviz/ui/widgets/visualizer/counter/counter_mode_selectors.dart';
import 'package:vidviz/ui/widgets/visualizer/counter/counter_style_selectors.dart';
import 'package:vidviz/ui/widgets/visualizer/counter/counter_toggles.dart';
import 'package:vidviz/ui/widgets/visualizer/counter/counter_selected_selector.dart';
import 'package:vidviz/ui/widgets/visualizer/counter/counter_align_controls.dart';
import 'package:vidviz/ui/widgets/visualizer/counter/counter_label_color_field.dart';
import 'package:vidviz/ui/widgets/visualizer/counter/counter_param_utils.dart';
import 'package:vidviz/ui/widgets/visualizer/counter/counter_presets.dart';
import 'package:vidviz/ui/widgets/visualizer/counter/counter_pos_sliders.dart';
import 'package:vidviz/ui/widgets/visualizer/counter/counter_weight_selector.dart';
import 'package:vidviz/ui/widgets/visualizer/counter/counter_shadow_sliders.dart';
import 'package:vidviz/ui/widgets/visualizer/counter/counter_glow_sliders.dart';

class CounterForm extends StatelessWidget {
  final VisualizerAsset asset;

  CounterForm(this.asset, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final startEnabled = readCounterBool(asset, 'counterStartEnabled', true);
    final endEnabled = readCounterBool(asset, 'counterEndEnabled', true);

    String selected = readCounterSelected(asset);
    if (selected == 'start' && !startEnabled && endEnabled) selected = 'end';
    if (selected == 'end' && !endEnabled && startEnabled) selected = 'start';

    final children = <Widget>[
      CounterStartEnabledToggle(asset),
      CounterEndEnabledToggle(asset),
      if (startEnabled && endEnabled) CounterSelectedSelector(asset),
      CounterPresetSelector(asset),
      CounterAlignControls(asset, selected: selected),
      CounterPosSliders(asset, selected: selected),
      CounterLabelColorField(asset, selected: selected),
      CounterWeightSelector(asset, selected: selected),
      CounterShadowSliders(asset, selected: selected),
      CounterGlowSliders(asset, selected: selected),
      selected == 'start' ? CounterStartModeSelector(asset) : CounterEndModeSelector(asset),
      CounterLabelSizeSelector(asset),
      CounterAnimSelector(asset),
      const SizedBox(height: 16),
    ];

    return SingleChildScrollView(
      child: Wrap(spacing: 0, runSpacing: 0, children: children),
    );
  }
}
