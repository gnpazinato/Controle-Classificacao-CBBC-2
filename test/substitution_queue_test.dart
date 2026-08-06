// Fila de entrada (pré-seleção de substituição) do MatchState.tapPlayer:
// com a quadra cheia, tocar no banco pré-seleciona; tocar em quem está em
// quadra efetiva a troca com o primeiro da fila. Lógica pura — sem
// MaterialApp (que estoura a pilha no ambiente musl local).

import 'package:controle_classificacao_cbbc/models/match_state.dart';
import 'package:controle_classificacao_cbbc/models/player.dart';
import 'package:controle_classificacao_cbbc/models/team.dart';
import 'package:flutter_test/flutter_test.dart';

Team _team(String id, {int players = 10}) {
  return Team(
    id: id,
    clubName: 'Clube $id',
    players: <Player>[
      for (int i = 1; i <= players; i++)
        Player(
          id: '$id$i',
          clubName: 'Clube $id',
          shirtNumber: i,
          fullName: 'Atleta $i',
          playerClass: 1.0,
        ),
    ],
  );
}

void main() {
  late Team teamA;
  late Team teamB;
  late MatchState state;

  Player pA(int shirt) => teamA.players[shirt - 1];
  Player pB(int shirt) => teamB.players[shirt - 1];

  setUp(() {
    teamA = _team('a');
    teamB = _team('b');
    state = MatchState(teamA: teamA, teamB: teamB);
    // Quadra cheia da Equipe A: atletas 1..5.
    for (int i = 1; i <= 5; i++) {
      expect(state.tapPlayer(pA(i)).outcome, PlayerTapOutcome.enteredCourt);
    }
  });

  test('quadra com vaga: banco entra direto, sem passar pela fila', () {
    expect(state.selectedTeamAIds, hasLength(5));
    expect(state.entryQueueTeamAIds, isEmpty);
    // Na Equipe B (quadra vazia) o toque no banco continua clássico.
    expect(state.tapPlayer(pB(1)).outcome, PlayerTapOutcome.enteredCourt);
  });

  test('quadra cheia: banco vira pré-seleção com ordem de chegada', () {
    final PlayerTapResult r6 = state.tapPlayer(pA(6));
    final PlayerTapResult r7 = state.tapPlayer(pA(7));
    expect(r6.outcome, PlayerTapOutcome.queued);
    expect(r6.queuePosition, 1);
    expect(r7.outcome, PlayerTapOutcome.queued);
    expect(r7.queuePosition, 2);
    expect(state.entryQueueTeamAIds, <String>['a6', 'a7']);
    // Nada mudou em quadra ainda.
    expect(state.selectedTeamAIds, <String>{'a1', 'a2', 'a3', 'a4', 'a5'});
  });

  test('tocar em quem está em quadra troca com o PRIMEIRO da fila', () {
    state.tapPlayer(pA(6));
    state.tapPlayer(pA(7));

    // Exemplo do usuário: 6 e 7 na fila, toque na nº 2 → troca 6 ↔ 2,
    // a 7 continua aguardando (agora em 1º).
    final PlayerTapResult r = state.tapPlayer(pA(2));
    expect(r.outcome, PlayerTapOutcome.substituted);
    expect(r.playerIn!.id, 'a6');
    expect(r.playerOut!.id, 'a2');
    expect(state.selectedTeamAIds, <String>{'a1', 'a6', 'a3', 'a4', 'a5'});
    expect(state.entryQueueTeamAIds, <String>['a7']);

    // A entrada ocupa a MESMA posição (slot) de quem saiu.
    expect(state.teamASlotPlayers[1]!.id, 'a6');

    // Segunda troca: 7 entra no lugar da 5.
    final PlayerTapResult r2 = state.tapPlayer(pA(5));
    expect(r2.outcome, PlayerTapOutcome.substituted);
    expect(r2.playerIn!.id, 'a7');
    expect(state.entryQueueTeamAIds, isEmpty);
  });

  test('tocar de novo numa pré-selecionada cancela e reordena a fila', () {
    state.tapPlayer(pA(6));
    state.tapPlayer(pA(7));
    state.tapPlayer(pA(8));

    expect(state.tapPlayer(pA(7)).outcome, PlayerTapOutcome.unqueued);
    expect(state.entryQueueTeamAIds, <String>['a6', 'a8']);
  });

  test('sem fila, tocar em quem está em quadra remove (clássico)', () {
    expect(state.tapPlayer(pA(3)).outcome, PlayerTapOutcome.leftCourt);
    expect(state.selectedTeamAIds, hasLength(4));
  });

  test('filas são independentes por equipe', () {
    for (int i = 1; i <= 5; i++) {
      state.tapPlayer(pB(i));
    }
    state.tapPlayer(pA(6));
    state.tapPlayer(pB(6));

    // A fila da B não interfere na troca da A.
    final PlayerTapResult r = state.tapPlayer(pA(1));
    expect(r.playerIn!.id, 'a6');
    expect(state.entryQueueTeamAIds, isEmpty);
    expect(state.entryQueueTeamBIds, <String>['b6']);
  });

  test('limpar equipe esvazia quadra E fila; limpar tudo idem', () {
    state.tapPlayer(pA(6));
    state.clearTeamA();
    expect(state.selectedTeamAIds, isEmpty);
    expect(state.entryQueueTeamAIds, isEmpty);

    for (int i = 1; i <= 5; i++) {
      state.tapPlayer(pB(i));
    }
    state.tapPlayer(pB(6));
    state.clearAll();
    expect(state.selectedTeamBIds, isEmpty);
    expect(state.entryQueueTeamBIds, isEmpty);
  });

  test('fila sobrevive ao round-trip de JSON (restauração de sessão)', () {
    state.tapPlayer(pA(6));
    state.tapPlayer(pA(7));

    final MatchState restored = MatchState.fromJson(state.toJson());
    expect(restored.entryQueueTeamAIds, <String>['a6', 'a7']);
    expect(restored.selectedTeamAIds, state.selectedTeamAIds);

    // JSON antigo (sem o campo) carrega com fila vazia.
    final Map<String, dynamic> old = state.toJson()
      ..remove('teamAEntryQueue')
      ..remove('teamBEntryQueue');
    expect(MatchState.fromJson(old).entryQueueTeamAIds, isEmpty);
  });
}
