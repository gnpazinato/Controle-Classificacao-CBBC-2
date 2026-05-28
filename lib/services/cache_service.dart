import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/match_state.dart';

/// Persiste o estado da partida em `shared_preferences` para sobreviver
/// a bloqueio de tela, alternancia entre apps e encerramento do
/// processo pelo Android.
class CacheService {
  CacheService({SharedPreferences? prefs}) : _injected = prefs;

  static const String _matchStateKey = 'cbbc.match_state.v1';

  final SharedPreferences? _injected;

  Future<SharedPreferences> _prefs() async {
    final SharedPreferences? injected = _injected;
    if (injected != null) return injected;
    return SharedPreferences.getInstance();
  }

  Future<void> saveMatchState(MatchState state) async {
    final SharedPreferences prefs = await _prefs();
    final String encoded = jsonEncode(state.toJson());
    await prefs.setString(_matchStateKey, encoded);
  }

  Future<MatchState?> loadMatchState() async {
    final SharedPreferences prefs = await _prefs();
    final String? raw = prefs.getString(_matchStateKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return MatchState.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasMatchState() async {
    final SharedPreferences prefs = await _prefs();
    return prefs.containsKey(_matchStateKey);
  }

  Future<void> clear() async {
    final SharedPreferences prefs = await _prefs();
    await prefs.remove(_matchStateKey);
  }
}
