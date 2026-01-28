import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidviz/core/config.dart';
import 'package:vidviz/service/export/native_generator.dart';

class ProService {
  static const String _proActiveKey = 'pro_is_active';
  static const String _proPlanIdKey = 'pro_plan_id';

  final SharedPreferences _prefs;

  ProService(this._prefs);

  bool get proEnabled => enableProFeatures;

  bool get isProUser {
    if (!proEnabled) return false;
    if (proUser) return true; // config override
    return _prefs.getBool(_proActiveKey) ?? false;
  }

  String? get currentPlanId {
    return _prefs.getString(_proPlanIdKey);
  }

  Future<void> activatePlan(String planId) async {
    await _prefs.setBool(_proActiveKey, true);
    await _prefs.setString(_proPlanIdKey, planId);
  }

  Future<void> deactivatePro() async {
    await _prefs.setBool(_proActiveKey, false);
    await _prefs.remove(_proPlanIdKey);
  }

  bool isResolutionProOnly(VideoResolution resolution) {
    if (!proEnabled) return false;
    switch (resolution) {
      case VideoResolution.uhd8k:
      case VideoResolution.uhd6k:
      case VideoResolution.uhd4k:
      case VideoResolution.qhd:
        return true;
      default:
        return false;
    }
  }

  bool canUseResolution(VideoResolution resolution) {
    if (!proEnabled) return true;
    if (!isResolutionProOnly(resolution)) return true;
    return isProUser;
  }
}
