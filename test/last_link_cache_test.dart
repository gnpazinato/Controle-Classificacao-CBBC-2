import 'package:controle_classificacao_cbbc/services/cache_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('último link importado persiste e sobrevive ao clear() da sessão',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final CacheService cache = CacheService();

    expect(await cache.loadLastImportLink(), isNull);

    await cache.saveLastImportLink(
        '  https://drive.google.com/drive/folders/ABC123  ');
    expect(await cache.loadLastImportLink(),
        'https://drive.google.com/drive/folders/ABC123');

    // "Começar do zero" limpa só a sessão da partida — o link fica.
    await cache.clear();
    expect(await cache.loadLastImportLink(),
        'https://drive.google.com/drive/folders/ABC123');

    // Novo link substitui o anterior; vazio é ignorado.
    await cache.saveLastImportLink('https://1drv.ms/f/s!Xyz');
    await cache.saveLastImportLink('   ');
    expect(await cache.loadLastImportLink(), 'https://1drv.ms/f/s!Xyz');
  });
}
