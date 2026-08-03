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

    test('planilha abreviada casa com arquivo de nome completo', () {
      // Caso real da importação: planilha "GUSTAVO LASMAR", foto
      // "Gustavo Freitas Lasmar.png".
      final Map<int, FolderImage> match = matchImagesToNames(
        <String>['GUSTAVO LASMAR', 'ERICK GABRIEL NASCIMENTO'],
        <FolderImage>[
          const FolderImage(
              fileName: 'Gustavo Freitas Lasmar.png', url: 'u-gustavo'),
          const FolderImage(
              fileName: 'Erick Gabriel de Moura Nascimento.png',
              url: 'u-erick'),
        ],
      );
      expect(match[0]?.url, 'u-gustavo');
      expect(match[1]?.url, 'u-erick');
    });

    test('conectores ("da", "de", "dos") não impedem o casamento', () {
      final Map<int, FolderImage> match = matchImagesToNames(
        <String>['RONALDO SANTOS', 'RYAN DOS SANTOS'],
        <FolderImage>[
          const FolderImage(
              fileName: 'Ronaldo da Silva Santos.png', url: 'u-ronaldo'),
          const FolderImage(
              fileName: 'Ryan Gomes dos Santos.png', url: 'u-ryan'),
        ],
      );
      expect(match[0]?.url, 'u-ronaldo');
      expect(match[1]?.url, 'u-ryan');
    });

    test('grafia levemente diferente casa ("Vitor" ↔ "Victor")', () {
      final Map<int, FolderImage> match = matchImagesToNames(
        <String>['JOÃO VITOR NASCIMENTO'],
        <FolderImage>[
          const FolderImage(
              fileName: 'João Victor Nascimento.png', url: 'u-joao'),
        ],
      );
      expect(match[0]?.url, 'u-joao');
    });

    test('letras transpostas casam ("Henirque" ↔ "Henrique")', () {
      final Map<int, FolderImage> match = matchImagesToNames(
        <String>['JHON HENRIQUE OLIVEIRA'],
        <FolderImage>[
          const FolderImage(
              fileName: 'Jhon Henirque Oliveira.png', url: 'u-jhon'),
        ],
      );
      expect(match[0]?.url, 'u-jhon');
    });

    test('sobrenome divergente casa quando o primeiro nome é único', () {
      // Mesmo atleta com sobrenomes diferentes na foto e na planilha:
      // só existe um Wandemberg no elenco, então a foto é dele.
      final Map<int, FolderImage> match = matchImagesToNames(
        <String>['WANDEMBERG DO NASCIMENTO', 'RONALDO SANTOS'],
        <FolderImage>[
          const FolderImage(
              fileName: 'Wandemberg Nejaim.png', url: 'u-wandemberg'),
        ],
      );
      expect(match[0]?.url, 'u-wandemberg');
      expect(match[1], isNull);
    });

    test('primeiro nome repetido no elenco não casa por sobrenome divergente',
        () {
      // Dois Joãos disputariam "João Pereira.png": ambígua, ninguém leva
      // (a foto vira aviso, sem impedir a importação).
      final Map<int, FolderImage> match = matchImagesToNames(
        <String>['João da Silva Sauro', 'João do Nascimento'],
        <FolderImage>[
          const FolderImage(fileName: 'João Pereira.png', url: 'u-joao'),
        ],
      );
      expect(match, isEmpty);
    });

    test('regra do primeiro nome não rouba foto de quem casa por inteiro',
        () {
      final Map<int, FolderImage> match = matchImagesToNames(
        <String>['Wandemberg Nejaim', 'Wandemberg do Nascimento'],
        <FolderImage>[
          const FolderImage(
              fileName: 'Wandemberg Nejaim.png', url: 'u-nejaim'),
        ],
      );
      expect(match[0]?.url, 'u-nejaim');
      expect(match[1], isNull);
    });

    test('grafia exata vence a aproximada quando os dois nomes existem', () {
      final Map<int, FolderImage> match = matchImagesToNames(
        <String>['Marcos Muniz', 'Marcus Muniz'],
        <FolderImage>[
          const FolderImage(fileName: 'Marcus Muniz.png', url: 'u-marcus'),
          const FolderImage(fileName: 'Marcos Muniz.png', url: 'u-marcos'),
        ],
      );
      expect(match[0]?.url, 'u-marcos');
      expect(match[1]?.url, 'u-marcus');
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
