const Set<String> kAllowedVisualizerShaderIds = {
  'bar',
  'bar_normal',
  'bar_colors',
  'bar_circle',
  'circle',
  'claude',
  'wave',
  'wav',
  'smooth',
  'line',
  'sinus',
  'curves',
  'particle',
  'nation',
};

const List<String> kAllowedVisualShaderUiIds = [
  'pro_nation',
  'starfield',
  'acid',
  'acidic',
  'penrose',
  'procedural',
  'amv',
  'chromatic',
  'heart',
  'plasma_wave',
  'sinusoid',
  'signal',
  'fluid',
  'sun_water',
];

const Set<String> kAllowedVisualShaderIds = {
  'pro_nation',
  'starfield',
  'acid',
  'acidic',
  'penrose',
  'procedural',
  'amv',
  'chromatic',
  'heart',
  'plasma_wave',
  'sinusoid',
  'signal',
  'fluid',
  'sun_water',
};

String normalizeVisualizerShaderId(String shaderId) {
  var id = shaderId.trim();
  if (id.isEmpty) return 'bar';

  if (id == 'claude') id = 'claude';
  if (id == 'radial_bar') id = 'bar_circle';
  if (id == 'bars') id = 'bar';
  if (id == 'twinbow') id = 'bar';
  if (id == 'fractal') id = 'bar';
  if (id == 'funcy') id = 'bar';
  if (id == 'lab') id = 'bar';

  if (kAllowedVisualizerShaderIds.contains(id)) return id;
  return 'bar';
}

String normalizeVisualShaderId(String shaderId) {
  var id = shaderId.trim();
  if (id.isEmpty) return 'pro_nation';
  if (id == 'new_nation') id = 'pro_nation';
  if (id == 'now_nation') id = 'now_nation';
  if (id == 'penrose') id = 'penrose';
  if (id == 'acid') id = 'acid';
  if (kAllowedVisualShaderIds.contains(id)) return id;
  return 'pro_nation';
}

String normalizeVisualShaderIdForUi(String shaderId) {
  var id = shaderId.trim();
  if (id.isEmpty) return 'pro_nation';
  if (id == 'pro_nation') id = 'pro_nation';
  if (id == 'now_nation') id = 'now_nation';
  if (id == 'penrose') id = 'penrose';
  if (id == 'acid') id = 'acid';
  if (kAllowedVisualShaderUiIds.contains(id)) return id;
  return 'pro_nation';
}
