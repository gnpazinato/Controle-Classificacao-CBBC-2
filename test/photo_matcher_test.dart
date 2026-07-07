import 'package:controle_classificacao_cbbc/services/roster_photo_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('imageKey / isSupportedImageFile', () {
    test('remove extensão e normaliza acentos', () {
      expect(imageKey('Gabriela Giolo.jpg'), 'gabriela_giolo');
      expect(imageKey('JOÃO DA SILVA.PNG'), 'joao_da_silva');
    });

    test('ignora prefixos numéricos comuns', () {
      expect(imageKey('01 - Gabriela.png'), 'gabriela');
      expect(imageKey('12_Maria Souza.jpeg'), 'maria_souza');
    });

    test('extensões de imagem aceitas', () {
      expect(isSupportedImageFile('a.jpg'), isTrue);
      expect(isSupportedImageFile('a.JPEG'), isTrue);
      expect(isSupportedImageFile('a.png'), isTrue);
      expect(isSupportedImageFile('a.webp'), isTrue);
      expect(isSupportedImageFile('planilha.xlsx'), isFalse);
      expect(isSupportedImageFile('leia-me.txt'), isFalse);
      expect(isSupportedImageFile('sem_extensao'), isFalse);
    });
  });

  group('matchImagesToNames', () {
    const FolderImage gabriela =
        FolderImage(fileName: 'Gabriela.jpg', url: 'u-gabriela');
    const FolderImage gabrielaFull =
        FolderImage(fileName: 'Gabriela Giolo.png', url: 'u-gabriela-full');

    test('nome de arquivo igual ao nome completo', () {
      final Map<int, FolderImage> match = matchImagesToNames(
        <String>['Gabriela Giolo'],
        <FolderImage>[gabrielaFull],
      );
      expect(match[0]?.url, 'u-gabriela-full');
    });

    test('primeiro nome casa com o nome completo ("Gabriela" → Gabriela Giolo)',
        () {
      final Map<int, FolderImage> match = matchImagesToNames(
        <String>['Gabriela Giolo'],
        <FolderImage>[gabriela],
      );
      expect(match[0]?.url, 'u-gabriela');
    });

    test('"Gabriel.jpg" não vaza para "Gabriela Giolo"', () {
      final Map<int, FolderImage> match = matchImagesToNames(
        <String>['Gabriela Giolo', 'Gabriel Souza'],
        <FolderImage>[
          const FolderImage(fileName: 'Gabriel.jpg', url: 'u-gabriel'),
        ],
      );
      expect(match[0], isNull);
      expect(match[1]?.url, 'u-gabriel');
    });

    test('sobrenome sozinho também casa ("Giolo.jpg")', () {
      final Map<int, FolderImage> match = matchImagesToNames(
        <String>['Gabriela Giolo'],
        <FolderImage>[
          const FolderImage(fileName: 'Giolo.jpg', url: 'u-giolo'),
        ],
      );
      expect(match[0]?.url, 'u-giolo');
    });

    test('arquivo com sufixo extra ("Gabriela Giolo 3x4.jpg")', () {
      final Map<int, FolderImage> match = matchImagesToNames(
        <String>['Gabriela Giolo'],
        <FolderImage>[
          const FolderImage(
              fileName: 'Gabriela Giolo 3x4.jpg', url: 'u-3x4'),
        ],
      );
      expect(match[0]?.url, 'u-3x4');
    });

    test('acentos não atrapalham ("João.png" → João da Silva)', () {
      final Map<int, FolderImage> match = matchImagesToNames(
        <String>['João da Silva'],
        <FolderImage>[
          const FolderImage(fileName: 'Joao.png', url: 'u-joao'),
        ],
      );
      expect(match[0]?.url, 'u-joao');
    });

    test('duas Marias e um "Maria.jpg" → ambígua, ninguém leva', () {
      final Map<int, FolderImage> match = matchImagesToNames(
        <String>['Maria Silva', 'Maria Souza'],
        <FolderImage>[
          const FolderImage(fileName: 'Maria.jpg', url: 'u-maria'),
        ],
      );
      expect(match, isEmpty);
    });

    test('nome exato vence o parcial quando os dois existem', () {
      final Map<int, FolderImage> match = matchImagesToNames(
        <String>['Gabriela Giolo', 'Gabriela Santos'],
        <FolderImage>[
          gabrielaFull,
          const FolderImage(
              fileName: 'Gabriela Santos.jpg', url: 'u-santos'),
        ],
      );
      expect(match[0]?.url, 'u-gabriela-full');
      expect(match[1]?.url, 'u-santos');
    });
  });

  group('matchFolderToClub', () {
    test('nome exato (com diferenças de caixa/acentos)', () {
      expect(
        matchFolderToClub('Equipe A', <String>['EQUIPE A', 'Equipe B']),
        'EQUIPE A',
      );
    });

    test('pasta com sufixo ("EQUIPE A - FOTOS")', () {
      expect(
        matchFolderToClub('Equipe A', <String>['EQUIPE A - FOTOS', 'Equipe B']),
        'EQUIPE A - FOTOS',
      );
    });

    test('sem correspondência → null', () {
      expect(
        matchFolderToClub('Magic Rodas', <String>['Equipe A', 'Equipe B']),
        isNull,
      );
    });
  });
}
