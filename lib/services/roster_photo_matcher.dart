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
///    ("Giolo.jpg", "Gabriela G.jpg").
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

double _matchScore(String person, String image) {
  if (person.isEmpty || image.isEmpty) return 0;
  if (person == image) return 3;
  // Arquivo é prefixo do nome em fronteira de palavra: "gabriela" casa
  // com "gabriela_giolo" mas NÃO com "gabriel_souza".
  if (person.startsWith('${image}_')) return 2;
  // Nome completo é prefixo do arquivo: "gabriela_giolo_3x4".
  if (image.startsWith('${person}_')) return 1.5;
  // Palavras do arquivo casam (por igualdade ou prefixo) com palavras
  // distintas do nome, em qualquer ordem: "giolo", "gabriela_g".
  final List<String> imageTokens =
      image.split('_').where((String t) => t.isNotEmpty).toList();
  final List<String> personTokens =
      person.split('_').where((String t) => t.isNotEmpty).toList();
  if (imageTokens.isEmpty) return 0;
  final Set<int> used = <int>{};
  for (final String token in imageTokens) {
    bool matched = false;
    for (int i = 0; i < personTokens.length; i++) {
      if (used.contains(i)) continue;
      if (personTokens[i] == token || personTokens[i].startsWith(token)) {
        used.add(i);
        matched = true;
        break;
      }
    }
    if (!matched) return 0;
  }
  return 1;
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
