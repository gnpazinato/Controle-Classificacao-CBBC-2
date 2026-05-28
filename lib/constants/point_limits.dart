/// Limites de pontuação selecionáveis no dropdown da tela de setup.
const List<double> kAcceptedPointLimits = <double>[
  7.0, 7.5, 8.0, 8.5, 9.0, 9.5,
  10.0, 10.5, 11.0, 11.5, 12.0, 12.5,
  13.0, 13.5, 14.0, 14.5, 15.0, 15.5, 16.0,
];

const double kDefaultPointLimit = 14.0;

/// Quando alguma bonificação está ativa e há atleta bonificado em quadra,
/// o limite efetivo da equipe sobe até este teto.
const double kBonusPointCeiling = 15.0;

const int kMaxPlayersPerTeam = 5;

bool isAcceptedPointLimit(double value) {
  for (final double accepted in kAcceptedPointLimits) {
    if ((accepted - value).abs() < 0.0001) return true;
  }
  return false;
}
