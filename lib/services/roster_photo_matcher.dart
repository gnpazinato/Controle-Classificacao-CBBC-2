import 'column_mapping.dart';

/// Casamento entre arquivos de imagem de uma pasta (Drive/OneDrive) e os
/// nomes de atletas/comissão técnica vindos da planilha.
///
/// A comparação é feita com nomes normalizados (minúsculas, sem acento,
/// espaços viram `_`). Regras, da mais forte pra mais fraca:
/// 1. arquivo == nome completo ("Gabriela Giolo.jpg" → Gabriela Giolo);
/// 2. arquivo é o começo do nome ("Gabriela.jpg" → Gabriela Giolo);
/// 3. nome completo é o começo do arquivo ("Gabriela Giolo 3x4.jpg");
/// 4. cada palavra do arquivo casa com uma palavra distinta do nome
///    ("Giolo.jpg", "Gabriela G.jpg") — ou o inverso: cada palavra do
///    nome casa com uma palavra distinta do arquivo, cobrindo planilha
///    com nome abreviado ("GUSTAVO LASMAR" ↔ "Gustavo Freitas
///    Lasmar.png"). Conectores ("de", "da", "dos"...) são ignorados
///    dos dois lados, e palavras com 5+ letras toleram uma única
///    diferença de grafia ("Vitor" ↔ "Victor") com pontuação menor;
/// 5. só o primeiro nome bate ("Wandemberg Nejaim.png" ↔ "WANDEMBERG
///    DO NASCIMENTO") — vale apenas quando UMA pessoa do elenco tem
///    aquele primeiro nome; com duas, a foto fica sem dono e vira aviso.
///
/// Empates exatos entre pessoas diferentes pela mesma imagem não são
/// atribuídos a ninguém (ex.: "Maria.jpg" com duas Marias no elenco).
class FolderImage {
  const FolderImage({required this.fileName, required this.url});

  /// Nome do arquivo com extensão, como aparece na pasta.
  final String fileName;

  /// URL pública direta da imagem.
  final String url;
}

/// Extensões aceitas como foto.
const Set<String> kSupportedImageExtensions = <String>{
  'jpg',
  'jpeg',
  'png',
  'webp',
  'gif',
  'bmp',
  'heic',
  'heif',
};

bool isSupportedImageFile(String fileName) {
  final int dot = fileName.lastIndexOf('.');
  if (dot <= 0 || dot == fileName.length - 1) return false;
  final String ext = fileName.substring(dot + 1).toLowerCase().trim();
  return kSupportedImageExtensions.contains(ext);
}

/// Chave normalizada do nome de uma pessoa.
String personKey(String fullName) => normalizeHeaderToken(fullName);

/// Chave normalizada do nome de arquivo: remove a extensão e prefixos
/// numéricos comuns ("01 - Gabriela.jpg" → `gabriela`).
String imageKey(String fileName) {
  String base = fileName;
  final int dot = base.lastIndexOf('.');
  if (dot > 0) base = base.substring(0, dot);
  base = base.replaceFirst(RegExp(r'^[\s\d\-_.()\[\]]+'), '');
  return normalizeHeaderToken(base);
}

/// Conectores comuns em nomes pt-BR, ignorados na comparação palavra a
/// palavra ("RONALDO SANTOS" ↔ "Ronaldo da Silva Santos.png").
const Set<String> _kNameConnectors = <String>{
  'de', 'da', 'do', 'das', 'dos', 'du', 'di', 'e',
};

/// Palavras "quase iguais": distância Damerau-Levenshtein 1 (uma letra
/// trocada, inserida, removida ou duas adjacentes transpostas), só em
/// palavras com 5+ letras ("vitor" ↔ "victor", "henirque" ↔ "henrique").
bool _isNearToken(String a, String b) {
  if (a.length < 5 || b.length < 5) return false;
  final int diff = a.length - b.length;
  if (diff.abs() > 1) return false;
  if (diff != 0) {
    // Uma letra inserida/removida.
    final String shorter = diff < 0 ? a : b;
    final String longer = diff < 0 ? b : a;
    for (int i = 0; i < longer.length; i++) {
      if (shorter == longer.substring(0, i) + longer.substring(i + 1)) {
        return true;
      }
    }
    return false;
  }
  // Mesmo tamanho: uma substituição ou uma transposição adjacente.
  int first = -1;
  int second = -1;
  int mismatches = 0;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      mismatches++;
      if (mismatches > 2) return false;
      if (first < 0) {
        first = i;
      } else {
        second = i;
      }
    }
  }
  if (mismatches == 1) return true;
  return mismatches == 2 &&
      second == first + 1 &&
      a[first] == b[second] &&
      a[second] == b[first];
}

/// Casa duas palavras: `1` por igualdade/prefixo, `0` por aproximação
/// ([_isNearToken]), `-1` quando não casam.
int _tokenMatch(String a, String b) {
  if (a == b || a.startsWith(b) || b.startsWith(a)) return 1;
  if (_isNearToken(a, b)) return 0;
  return -1;
}

/// Tenta casar cada palavra de [need] com uma palavra distinta de
/// [pool], em qualquer ordem. Retorna `null` se alguma palavra sobra;
/// senão, se alguma precisou de aproximação.
bool? _coverTokens(List<String> need, List<String> pool) {
  final Set<int> used = <int>{};
  bool fuzzy = false;
  for (final String token in need) {
    bool matched = false;
    for (int i = 0; i < pool.length; i++) {
      if (used.contains(i)) continue;
      final int m = _tokenMatch(token, pool[i]);
      if (m >= 0) {
        used.add(i);
        matched = true;
        if (m == 0) fuzzy = true;
        break;
      }
    }
    if (!matched) return null;
  }
  return fuzzy;
}

double _matchScore(String person, String image) {
  if (person.isEmpty || image.isEmpty) return 0;
  if (person == image) return 3;
  // Arquivo é prefixo do nome em fronteira de palavra: "gabriela" casa
  // com "gabriela_giolo" mas NÃO com "gabriel_souza".
  if (person.startsWith('${image}_')) return 2;
  // Nome completo é prefixo do arquivo: "gabriela_giolo_3x4".
  if (image.startsWith('${person}_')) return 1.5;
  // Palavras do arquivo casam com palavras distintas do nome, em
  // qualquer ordem ("giolo", "gabriela_g") — ou o inverso, quando a
  // planilha abrevia o nome ("gustavo_lasmar" ↔
  // "gustavo_freitas_lasmar"). Conectores ficam de fora dos dois lados.
  final List<String> imageTokens = image
      .split('_')
      .where((String t) => t.isNotEmpty && !_kNameConnectors.contains(t))
      .toList();
  final List<String> personTokens = person
      .split('_')
      .where((String t) => t.isNotEmpty && !_kNameConnectors.contains(t))
      .toList();
  if (imageTokens.isEmpty || personTokens.isEmpty) return 0;
  final bool? fuzzy = _coverTokens(imageTokens, personTokens) ??
      _coverTokens(personTokens, imageTokens);
  if (fuzzy != null) {
    // Cobertura com aproximação de grafia vale menos que a exata, pra
    // perder disputas quando existe um candidato escrito igual.
    return fuzzy ? 0.75 : 1;
  }
  // Regra mais fraca: só o primeiro nome bate. Cobre foto e planilha
  // com sobrenomes divergentes do mesmo atleta ("Wandemberg Nejaim.png"
  // ↔ "WANDEMBERG DO NASCIMENTO"). Se duas pessoas do elenco disputam a
  // mesma foto por essa regra, o algoritmo guloso descarta a atribuição
  // como ambígua e a foto segue sem dono (vira aviso na importação).
  if (_tokenMatch(imageTokens.first, personTokens.first) >= 0) return 0.5;
  return 0;
}

class _Candidate {
  const _Candidate(this.nameIndex, this.imageIndex, this.score);
  final int nameIndex;
  final int imageIndex;
  final double score;
}

/// Associa imagens a nomes. Retorna um mapa índice-do-nome → imagem.
///
/// Atribuição gulosa da pontuação mais alta pra mais baixa. Quando duas
/// pessoas diferentes disputam a mesma imagem com a mesma pontuação, a
/// imagem é descartada (ambígua).
Map<int, FolderImage> matchImagesToNames(
  List<String> names,
  List<FolderImage> images,
) {
  final List<String> nameKeys = names.map(personKey).toList(growable: false);
  final List<String> imageKeys = images
      .map((FolderImage i) => imageKey(i.fileName))
      .toList(growable: false);

  final List<_Candidate> candidates = <_Candidate>[];
  for (int n = 0; n < nameKeys.length; n++) {
    for (int i = 0; i < imageKeys.length; i++) {
      final double score = _matchScore(nameKeys[n], imageKeys[i]);
      if (score > 0) candidates.add(_Candidate(n, i, score));
    }
  }
  candidates.sort((_Candidate a, _Candidate b) {
    if (a.score != b.score) return b.score.compareTo(a.score);
    if (a.nameIndex != b.nameIndex) return a.nameIndex.compareTo(b.nameIndex);
    return a.imageIndex.compareTo(b.imageIndex);
  });

  final Set<int> usedNames = <int>{};
  final Set<int> usedImages = <int>{};
  final Map<int, FolderImage> result = <int, FolderImage>{};

  for (int c = 0; c < candidates.length; c++) {
    final _Candidate cand = candidates[c];
    if (usedNames.contains(cand.nameIndex)) continue;
    if (usedImages.contains(cand.imageIndex)) continue;

    bool contested = false;
    for (int o = 0; o < candidates.length; o++) {
      if (o == c) continue;
      final _Candidate other = candidates[o];
      if (other.score != cand.score) continue;
      if (other.imageIndex != cand.imageIndex) continue;
      if (other.nameIndex == cand.nameIndex) continue;
      if (usedNames.contains(other.nameIndex)) continue;
      contested = true;
      break;
    }
    if (contested) {
      // Ninguém leva a imagem ambígua.
      usedImages.add(cand.imageIndex);
      continue;
    }

    result[cand.nameIndex] = images[cand.imageIndex];
    usedNames.add(cand.nameIndex);
    usedImages.add(cand.imageIndex);
  }
  return result;
}

/// Encontra a pasta que corresponde ao clube ("Equipe A" ↔ pasta
/// "Equipe A", "EQUIPE A - FOTOS", ...). Retorna `null` se nenhuma
/// pasta casar ou se houver empate ambíguo.
String? matchFolderToClub(String clubName, Iterable<String> folderNames) {
  final String club = normalizeHeaderToken(clubName);
  if (club.isEmpty) return null;

  String? best;
  int bestRank = 0;
  bool tie = false;

  for (final String folder in folderNames) {
    final String key = normalizeHeaderToken(folder);
    if (key.isEmpty) continue;
    int rank = 0;
    if (key == club) {
      rank = 4;
    } else if (key.startsWith('${club}_') || club.startsWith('${key}_')) {
      rank = 3;
    } else if (key.contains(club)) {
      rank = 2;
    } else if (club.contains(key)) {
      rank = 1;
    }
    if (rank == 0) continue;
    if (rank > bestRank) {
      bestRank = rank;
      best = folder;
      tie = false;
    } else if (rank == bestRank) {
      tie = true;
    }
  }
  if (tie && bestRank < 4) return null;
  return best;
}
