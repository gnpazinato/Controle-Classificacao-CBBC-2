import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/match_state.dart';

/// Persiste o estado da partida em `shared_preferences` para sobreviver
/// a bloqueio de tela, alternancia entre apps e encerramento do
/// processo pelo Android.
class CacheService {
  CacheService({SharedPreferences? prefs}) : _injected = prefs;

  static const String _matchStateKey = 'cbbc.match_state.v1';
  static const String _lastImportLinkKey = 'cbbc.last_import_link.v1';
  static const String _broadcastSessionKey = 'cbbc.broadcast_session.v1';

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

  /// Último link importado (Drive/OneDrive). Persistido fora da sessão
  /// da partida: sobrevive a "Começar do zero", fechamento do app e
  /// reinício do tablet.
  Future<void> saveLastImportLink(String link) async {
    final SharedPreferences prefs = await _prefs();
    final String trimmed = link.trim();
    if (trimmed.isEmpty) return;
    await prefs.setString(_lastImportLinkKey, trimmed);
  }

  Future<String?> loadLastImportLink() async {
    final SharedPreferences prefs = await _prefs();
    final String? raw = prefs.getString(_lastImportLinkKey);
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.trim();
  }

  /// Sessão de transmissão **do tablet** (link fixo). Vive fora do estado
  /// da partida: sobrevive a troca de equipes, "Começar do zero",
  /// fechamento do app e reinício do tablet. Só some quando o usuário
  /// encerra a transmissão ou quando o servidor expira a sessão (24h sem
  /// uso) e o app descarta as credenciais.
  Future<void> saveBroadcastSession({
    required String id,
    required String writeToken,
  }) async {
    final SharedPreferences prefs = await _prefs();
    await prefs.setString(
      _broadcastSessionKey,
      jsonEncode(<String, String>{'id': id, 'writeToken': writeToken}),
    );
  }

  Future<({String id, String writeToken})?> loadBroadcastSession() async {
    final SharedPreferences prefs = await _prefs();
    final String? raw = prefs.getString(_broadcastSessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final String? id = decoded['id'] as String?;
      final String? token = decoded['writeToken'] as String?;
      if (id == null || id.isEmpty || token == null || token.isEmpty) {
        return null;
      }
      return (id: id, writeToken: token);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearBroadcastSession() async {
    final SharedPreferences prefs = await _prefs();
    await prefs.remove(_broadcastSessionKey);
  }
}
