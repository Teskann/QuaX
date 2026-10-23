# Math font

`assets/fonts/NotoSansMath-Accents.ttf` is generated from Noto Sans Math and committed: the build does
not run this script. Run it again only to change the font:

```bash
python -mvenv .venv-fonts
bash -c '
  source ./.venv-fonts/bin/activate
  pip install -r tool/fonts/requirements.txt
  python tool/fonts/generate_math_font.py
'
```

It keeps the mathematical letters and the combining accents, and gives each letter the accent anchors of its
plain letter, so that the accents sit on it.
