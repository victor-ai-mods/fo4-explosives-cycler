"""
Значки для строки на экране: вписывает контуры в widget/EXCWidget.as (блок между
BEGIN ICONS / END ICONS), дальше tools/gen_widget.py собирает SWF как обычно.

  grenade, mine — ванильные значки счётчика взрывчатки HUD: HUDMenu.swf из
      `Fallout4 - Interface.ba2`, клип RightMeters_mc.ExplosiveAmmoCount_mc.TypeIcon_mc
      (символ 596, класс HUDMenu_fla.ExplosiveAmmoCountIcon_21): кадр 1 — фигура 329
      (граната), кадр 2 — фигура 408 (мина). Контуры достаёт JPEXS FFDec (SVG).
  molotov — в игре такого значка нет (проверено по всем SWF в архивах Interface и
      Main): нарисован здесь в том же стиле — плоская заливка, детали вырезаны.

Контур в AS3 — плоский массив: ширина, высота, затем команды 1 x y (moveTo),
2 x y (lineTo), 3 cx cy x y (curveTo). Подконтуры в одной заливке Flash закрашивает
по правилу even-odd — так получаются вырезы. Начало координат — левый верхний угол.

    python tools/gen_icons.py          # нужны Java, FFDEC_JAR и игра (FO4_PATH)
"""

import math
import os
import re
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ba2 import BA2  # noqa: E402
from gen_widget import ffdec_jar  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AS_FILE = os.path.join(ROOT, 'widget', 'EXCWidget.as')
GAME = os.environ.get('FO4_PATH', r'D:\Games\Fallout 4')
INTERFACE_BA2 = os.path.join(GAME, 'Data', 'Fallout4 - Interface.ba2')
HUD_SHAPES = {'grenade': 329, 'mine': 408}

BEGIN = '// BEGIN ICONS'
END = '// END ICONS'

# Бутылка стоя в квадрате ~28x28 (как ванильные значки), потом наклон MOLOTOV_TILT
# градусов по часовой. Z только для читаемости: заливка закрывает подконтур сама.
MOLOTOV_TILT = 25.0
MOLOTOV = [
    # корпус с плечами и горлышком
    'M12.2 7.2 L15.8 7.2 L15.8 10.6 Q15.8 11.8 17.4 12.6 Q19.6 13.6 19.6 16.0 L19.6 26.4 '
    'Q19.6 28.0 18.0 28.0 L10.0 28.0 Q8.4 28.0 8.4 26.4 L8.4 16.0 Q8.4 13.6 10.6 12.6 '
    'Q12.2 11.8 12.2 10.6 Z',
    # этикетка (вырез)
    'M10.2 18.2 L17.8 18.2 L17.8 23.4 L10.2 23.4 Z',
    # тряпка в горлышке
    'M11.6 5.2 L16.4 5.2 L16.4 6.4 L11.6 6.4 Z',
    # пламя
    'M14.0 4.6 Q9.4 4.4 9.8 1.2 Q10.2 -1.0 11.8 -2.2 Q11.6 0.0 12.8 0.8 Q12.8 -2.6 16.0 -4.6 '
    'Q15.2 -1.6 16.8 0.0 Q18.4 1.6 17.8 3.0 Q17.0 4.7 14.0 4.6 Z',
    # язычок внутри пламени (вырез)
    'M14.0 3.5 Q12.3 3.4 12.5 2.1 Q12.7 1.2 13.6 0.6 Q13.7 1.8 14.8 2.3 Q15.7 2.8 15.5 3.1 '
    'Q15.1 3.6 14.0 3.5 Z',
]


def parse_path(d):
    """SVG path (только абсолютные M, L, Q, Z, как пишет FFDec) -> [(cmd, [x, y, ...])]."""
    toks = re.findall(r'[MLQZ]|-?\d+(?:\.\d+)?', d)
    out = []
    cmd = None
    i = 0
    while i < len(toks):
        t = toks[i]
        if t in 'MLQZ':
            cmd = t
            i += 1
            continue
        n = 4 if cmd == 'Q' else 2
        out.append((cmd, [float(v) for v in toks[i:i + n]]))
        i += n
        if cmd == 'M':
            cmd = 'L'   # дальнейшие пары после M — это L
    return out


def transform(path, fn):
    return [(c, [v for p in zip(pts[0::2], pts[1::2]) for v in fn(*p)]) for c, pts in path]


def normalize(path):
    xs = [v for _, pts in path for v in pts[0::2]]
    ys = [v for _, pts in path for v in pts[1::2]]
    x0, y0 = min(xs), min(ys)
    return transform(path, lambda x, y: (x - x0, y - y0)), max(xs) - x0, max(ys) - y0


def molotov_path():
    a = math.radians(MOLOTOV_TILT)
    c, s = math.cos(a), math.sin(a)
    path = parse_path(' '.join(MOLOTOV))
    return transform(path, lambda x, y: ((x - 14) * c - (y - 13) * s, (x - 14) * s + (y - 13) * c))


def hud_paths():
    """Контуры ванильных значков из HUDMenu.swf через FFDec (SVG)."""
    work = tempfile.mkdtemp(prefix='exc_icons_')
    try:
        swf = os.path.join(work, 'HUDMenu.swf')
        with open(swf, 'wb') as f:
            f.write(BA2(INTERFACE_BA2).read('interface/hudmenu.swf'))
        out = os.path.join(work, 'svg')
        ids = ','.join(str(v) for v in HUD_SHAPES.values())
        cmd = ['java', '-jar', ffdec_jar(), '-selectid', ids, '-format', 'shape:svg',
               '-export', 'shape', out, swf]
        res = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8', errors='replace')
        if res.returncode != 0:
            sys.stderr.write(res.stdout[-2000:] + res.stderr[-2000:])
            raise SystemExit('FFDec: ошибка (код %d)' % res.returncode)
        paths = {}
        for name, sid in HUD_SHAPES.items():
            with open(os.path.join(out, '%d.svg' % sid), encoding='utf-8') as f:
                svg = f.read()
            ds = re.findall(r' d="([^"]+)"', svg)
            if len(ds) != 1 or 'fill="#ffffff"' not in svg:
                raise SystemExit('фигура %d (%s): ожидался один белый контур' % (sid, name))
            paths[name] = parse_path(ds[0])
        return paths
    finally:
        shutil.rmtree(work, ignore_errors=True)


def fmt(v):
    s = '%.2f' % v
    s = s.rstrip('0').rstrip('.')
    return '0' if s == '-0' else s


def as3_array(path, w, h):
    code = {'M': 1, 'L': 2, 'Q': 3}
    vals = [fmt(w), fmt(h)]
    for c, pts in path:
        vals.append(str(code[c]))
        vals.extend(fmt(v) for v in pts)
    lines = []
    for i in range(0, len(vals), 24):
        lines.append('\t\t\t' + ', '.join(vals[i:i + 24]))
    return ',\n'.join(lines)


def main():
    icons = hud_paths()
    icons['molotov'] = molotov_path()
    block = [BEGIN + ' (tools/gen_icons.py, не править руками)',
             '\t\t// Контур: ширина, высота, затем 1 x y — moveTo, 2 x y — lineTo, 3 cx cy x y — curveTo.',
             '\t\tprivate static const ICONS:Object = {']
    names = list(icons)
    for n in names:
        path, w, h = normalize(icons[n])
        block.append('\t\t\t%s: [' % n)
        block.append(as3_array(path, w, h))
        block.append('\t\t\t]%s' % (',' if n != names[-1] else ''))
        print('%-8s %5.2f x %5.2f, команд %d' % (n, w, h, len(path)))
    block.append('\t\t};')
    block.append('\t\t' + END)

    with open(AS_FILE, encoding='utf-8', newline='') as f:
        src = f.read()
    m = re.search(r'//[ ]BEGIN ICONS.*?//[ ]END ICONS', src, re.S)
    if not m:
        raise SystemExit('в %s нет блока %s ... %s' % (AS_FILE, BEGIN, END))
    eol = '\r\n' if '\r\n' in src else '\n'
    src = src[:m.start()] + eol.join(block) + src[m.end():]
    with open(AS_FILE, 'w', encoding='utf-8', newline='') as f:
        f.write(src)
    print('->', os.path.relpath(AS_FILE, ROOT))


if __name__ == '__main__':
    main()
