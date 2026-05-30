# Manual de Uso — gerador (PDF e Word)

Scripts que geram o **Manual de Uso para a CBBC** do aplicativo Controle de
Classificação CBBC, em dois formatos:

- `docs/Manual-Uso-Controle-Classificacao-CBBC.pdf` — versão final para leitura.
- `docs/Manual-Uso-Controle-Classificacao-CBBC.docx` — versão **editável** (Word).

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
- `generate_manual.py` — diagrama o **PDF** final com ReportLab.
- `generate_manual_docx.py` — gera a versão **Word (.docx)** editável.

## Como regenerar

```bash
pip install pillow reportlab qrcode python-docx pypdfium2
cd docs/manual
python3 app_screens.py            # renderiza as capturas em build/
python3 generate_manual.py        # monta o PDF em docs/
python3 generate_manual_docx.py   # monta o Word (.docx) em docs/
```

Saídas em `docs/`: `Manual-Uso-Controle-Classificacao-CBBC.pdf` e
`Manual-Uso-Controle-Classificacao-CBBC.docx`.
