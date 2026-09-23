import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'chatbot_api.dart';

enum AppMode { selection, user, business }

/// Top-level application state.
/// Provider is used for simplicity — swap for Riverpod/Bloc in production.
class AppState extends ChangeNotifier {
  static const _defaultOrgId = 'org_001'; // business mode org

  AppMode _mode = AppMode.selection;
  BusinessProfile? _businessProfile;
  int _agentRequestCount = 0;

  // ── Getters ───────────────────────────────────────────────────────────
  AppMode get mode => _mode;
  BusinessProfile? get businessProfile => _businessProfile;
  int get agentRequestCount => _agentRequestCount;
  bool get hasBusinessProfile => _businessProfile != null;

  // ── Mode switching ────────────────────────────────────────────────────
  void selectMode(AppMode m) {
    _mode = m;
    notifyListeners();
  }

  // ── Business profile ──────────────────────────────────────────────────
  Future<void> loadBusinessProfile() async {
    final p = await ChatbotApiService.instance.getBusinessProfile(_defaultOrgId);
    if (p != null) {
      _businessProfile = p;
      notifyListeners();
    }
  }

  Future<bool> saveBusinessProfile(BusinessProfile profile) async {
    final ok = await ChatbotApiService.instance.saveBusinessProfile(profile);
    if (ok) {
      _businessProfile = profile;
      notifyListeners();
    }
    return ok;
  }

  // ── Agent request count ───────────────────────────────────────────────
  Future<void> refreshAgentCount() async {
    final count = await ChatbotApiService.instance
        .getAgentRequestCount(_defaultOrgId);
    if (count != _agentRequestCount) {
      _agentRequestCount = count;
      notifyListeners();
    }
  }

  void resetMode() {
    _mode = AppMode.selection;
    notifyListeners();
  }
}
