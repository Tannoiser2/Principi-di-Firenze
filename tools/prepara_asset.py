#!/usr/bin/env python3
"""Prepara gli asset del gioco a partire dal modulo Tabletop Simulator (estratto in TTS_DIR).

Uso:  python3 tools/prepara_asset.py /percorso/Mods
Crea assets/board, assets/cards, assets/tiles, assets/tokens nel progetto.
Le immagini vengono ridimensionate per la versione web (peso contenuto).
"""
import glob, json, os, re, sys
from PIL import Image

TTS = sys.argv[1] if len(sys.argv) > 1 else '/home/claude/pof_tts/Mods'
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets')
FILES = glob.glob(TTS + '/Images/*')


def find(key):
    """File del modulo il cui nome termina con l'hash indicato."""
    for f in FILES:
        if os.path.splitext(os.path.basename(f))[0].endswith(key):
            return f
    raise SystemExit('manca ' + key)


def save(im, rel, max_w=None, max_h=None, q=86):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if max_w or max_h:
        im = im.copy()
        im.thumbnail((max_w or 99999, max_h or 99999), Image.LANCZOS)
    if rel.endswith('.jpg'):
        im.convert('RGB').save(path, quality=q, optimize=True)
    else:
        im.save(path, optimize=True)
    return path


def sheet(key, w, h, n, prefix, max_w, start=0, names=None):
    im = Image.open(find(key)).convert('RGB')
    cw, ch = im.width // w, im.height // h
    for i in range(n):
        c = im.crop(((i % w) * cw, (i // w) * ch, (i % w + 1) * cw, (i // w + 1) * ch))
        nm = names[i] if names else '%s%02d' % (prefix, i + start)
        save(c, 'cards/%s.jpg' % nm, max_w)


def main():
    # tabellone, plance dei principati, schede riassuntive
    save(Image.open(find('95007C02764BD6B4B7E9168308F7DCC1D8CA66010D9D')), 'board/tabellone.jpg', 4096)
    save(Image.open(find('102404A161269878172BED2CFF8A464BB740912F50CD')), 'board/principato_a.jpg', 2048)
    save(Image.open(find('1207EDB210E540C6F0D69D5053A6E90581A6EC9774CF')), 'board/principato_b.jpg', 2048)
    save(Image.open(find('0850E93E99ACB388E2CA7200AC85C9B6B02BDA9974F6')), 'board/riepilogo_carte.jpg', 2000)
    save(Image.open(find('0938922C08BC87A2A48192E8667E22048EA98278DFC8')), 'board/riepilogo_regole.jpg', 2000)
    # plance dei giocatori (colore, lato donna/uomo)
    plance = {
        'nero_d': '2AFEB97FBBD9', 'nero_u': '1B3F1C603A35',
        'blu_u': 'DDD983D14872', 'blu_d': '64707B1EE71D',
        'giallo_d': '94AB276684A6', 'giallo_u': '7611827D8CDF',
        'verde_u': '35E8BB8CB487', 'verde_d': '7867D4F46A30',
        'rosso_d': '0A0731A8FCE8', 'rosso_u': 'CBAC9C423A8C',
    }
    for nm, k in plance.items():
        im = Image.open(find(k))
        save(im, 'board/plancia_%s.jpg' % nm, 1400)
        w, h = im.size
        save(im.crop((int(w * 0.035), int(h * 0.07), int(w * 0.385), int(h * 0.93))), 'tokens/ritratto_%s.jpg' % nm, 240, 300)

    # carte: professioni (indice del foglio -> numero stampato), bonus, prestigio
    prof_num = [1, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2]
    sheet('F32F276923265F39ADDF2CBEA4AFC4EE4FDE0F2F', 8, 3, 21, '', 500, names=['prof%02d' % n for n in prof_num])
    sheet('CAACAB9293BA00237894F54B5461CE35E709713D', 8, 3, 20, '', 500, names=['bonus%02d' % (20 - i) for i in range(20)])
    sheet('6583F5F6B33CCBD690AA21737BD0EE1B973C5D10', 8, 3, 14, '', 500, names=['prest%02d' % ([1] + list(range(14, 1, -1)))[i] for i in range(14)])
    rec = Image.open(find('1CF8D139A4275DE2089ACFF7C178172ADB244B80')).convert('RGB')
    save(rec.crop((0, 0, rec.width // 2, rec.height // 2)), 'cards/reclutamento.jpg', 500)
    # automa: 1-2 = A1-A6, 3-4 = A7-A12, 5-7 = A13-A21
    sheet('C35AEC6DC95BBBF3253312E06E06422DA28634B1', 4, 2, 6, '', 520, names=['automa%02d' % (i + 1) for i in range(6)])
    sheet('62DDD2F15AEF292AF56579C735362F6FE7072DFC', 4, 2, 6, '', 520, names=['automa%02d' % (i + 7) for i in range(6)])
    sheet('7CE0F7775D3C0B5456C01EF16F2904019DEDCEA3', 5, 2, 9, '', 520, names=['automa%02d' % (i + 13) for i in range(9)])
    sheet('7A674351785EFB5F7F88AE1F3CA25A6FEB085CCF', 3, 2, 6, '', 520,
          names=['pers_banchiere', 'pers_cardinale', 'pers_mercante', 'pers_musa', 'pers_professore', 'pers_principessa'])
    backs = {'dorso_professioni': '24547A4E939B7E40AB36B9212025A700B9F7EA85', 'dorso_prestigio': '5279F43D16B72C6ED0F039D3252039815D878750',
             'dorso_bonus': 'E5A18260DE91C172F5589788B3A8311FE6C7B474', 'dorso_reclutamento': '847C9795A36A9B3FEEC998CFE9FD7B3653C8BE02',
             'dorso_automa12': 'CF99473854BBBB3E4C9954F235F6633FBDE64256', 'dorso_automa34': '9826C06D4CF4360293FFC6B14A46A1877C06134C',
             'dorso_automa57': '9446CABF8BA1D64CE2306F48E232EDBD1539A1E9'}
    for nm, k in backs.items():
        save(Image.open(find(k)), 'cards/%s.jpg' % nm, 400)

    # tessere: edifici e paesaggi (ritagliate al contorno), libertà
    tiles = {'studio': '25816A6A0D8C', 'universita': '34D47A7FA4AC', 'biblioteca': '97DA8D39BC80', 'lago': '5DE26D58B0F8',
             'ospedale': '82E8299CA041', 'teatro': 'E8FBAB5D4803', 'bosco': '5D5EEC805087', 'opera': '1992EAEC7743',
             'parco': '00023CA1FE35', 'cappella': 'A69A0F404D0A', 'torre': '85657B467D3F', 'laboratorio': 'CC7A4A4020F4',
             'bottega': '129726C2BD33'}
    for nm, k in tiles.items():
        im = Image.open(find(k)).convert('RGBA')
        im = im.crop(im.getbbox())
        # 231 px per casella nell'originale: si portano a 128 px per casella
        f = 128.0 / 231.0
        im = im.resize((round(im.width * f), round(im.height * f)), Image.LANCZOS)
        save(im, 'tiles/%s.png' % nm)
    for nm, k in {'viaggio': '96649DFEC9F4C12F4F38DFB50E77F3F6925A44E000F1', 'opinione': '97838B26E7BA150220E4AD8E4B96192135616C887C32',
                  'religione': '9722FCF7664A5A58B1A7E0DFA5CBC2E50F805D116EC4'}.items():
        save(Image.open(find(k)), 'tiles/liberta_%s.jpg' % nm)

    # gettoni
    tok = {'costruttore': '1403F47D0F571FB0801C9EA0AE6392349EA518A26878', 'giullare': '9226371FFCFCD75B1405644A56B7E2CDEDA9FB8631C3',
           'giglio': '15494000F7F17043CFAD3D796412A6CFBA3B0960D7C8', 'fiorino100': '935651740E340503C5D9EF4DCF01B681C165671BFF25',
           'fiorino500': '9415FD622ACE5DCFF57155CD7BCFAC5117A62CE71884', 'fiorino1000': '92927075E503B7F0A4349225BEA51040F3DFE5FB08A7'}
    for nm, k in tok.items():
        im = Image.open(find(k))
        save(im.convert('RGBA') if im.mode == 'RGBA' else im.convert('RGB'), 'tokens/%s.%s' % (nm, 'png' if im.mode == 'RGBA' else 'jpg'), 256)
    # dischi 50/100 per colore (fronte 50, retro 100)
    for nm, (k50, k100) in {'verde': ('9D45A532AF9E', '6DDE858BF3'), 'rosso': ('724517EF56F6', '6F25690C2D'),
                           'blu': ('AC8854C0733E', '0B8DBEBE7C'), 'nero': ('88429F1F1789', '9753F06E52'),
                           'giallo': ('DFB4ECBCA311', '67F0C806AE')}.items():
        save(Image.open(find(k50)), 'tokens/disco50_%s.jpg' % nm, 200)
        save(Image.open(find(k100)), 'tokens/disco100_%s.jpg' % nm, 200)


if __name__ == '__main__':
    main()
