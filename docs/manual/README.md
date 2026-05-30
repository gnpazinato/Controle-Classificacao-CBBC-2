# Manual de Uso (PDF) — gerador

Scripts que geram o **Manual de Uso do Aplicativo Controle de Classificação
CBBC** (`docs/Manual-Uso-Controle-Classificacao-CBBC.pdf`).

O manual documenta a versão **2.3.4** do app — incluindo a transmissão ao vivo
da quadra com QR code / link público — e usa **registros de tela** que
reproduzem fielmente a interface (mesma paleta, tipografia e layout do código
Flutter), numa simulação de uso real da Supercopa com as equipes **IREFES** e
**ADESUL** (a partir da planilha em `assets/images/`).

> As fotos das atletas aparecem com a silhueta-fallback do app porque o
> ambiente de build não tem acesso à internet (os links são do Google Drive).
> Em um dispositivo conectado, os mesmos chips exibem as fotos reais.

## Arquivos

- `screens.py` — primitivos de desenho e componentes (paleta `CbbcColors`,
  camisa, chip de retrato, tabuleiro da quadra, molduras de dispositivo).
- `app_screens.py` — monta cada tela do app como imagem (`build/*.png`).
- `generate_manual.py` — diagrama o PDF final com ReportLab.

## Como regenerar

```bash
pip install pillow reportlab qrcode pypdfium2
cd docs/manual
python3 app_screens.py      # renderiza as capturas em build/
python3 generate_manual.py  # monta o PDF em docs/
```

Saída: `docs/Manual-Uso-Controle-Classificacao-CBBC.pdf`.
