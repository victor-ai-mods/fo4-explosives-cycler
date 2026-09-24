"""
Собирает стандартный файл списков `Data/ExplosivesCycler/lists-default.json`
из `data/explosives.json` (его делает tools/scan_explosives.py).

Правила (PLAN.md §2, решения пользователя в §7):
  - только играбельные предметы с уроном > 0 (служебные гранаты, маяки,
    «Кроличья лапка» отпадают сами);
  - коктейль Молотова — отдельный список, в гранатах его нет;
  - капканы и шипы Far Harbor (DLC03_Throwing*) в мины не входят;
  - порядок: урон, при равном уроне — цена.

Формат файла жёсткий (его читает построчный парсер в EXC:CyclerQuest):
одна пара ключ-значение на строке, один предмет на строке.

    python tools/gen_lists.py
"""

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'data', 'explosives.json')
DST = os.path.join(ROOT, 'mod', 'ExplosivesCycler', 'lists-default.json')

MOLOTOV = 'Fallout4.esm|10C3C6'


def usable(e):
    return e['playable'] and e['damage'] > 0 and not e['edid'].startswith('DLC03_Throwing')


def by_damage(items, reverse=False):
    return sorted(items, key=lambda e: (e['damage'], e['value']), reverse=reverse)


def q(text):
    return json.dumps(text, ensure_ascii=False)


def main():
    with open(SRC, encoding='utf-8') as f:
        data = [e for e in json.load(f) if usable(e)]
    grenades = [e for e in data if e['type'] == 'grenade' and e['id'] != MOLOTOV]
    mines = [e for e in data if e['type'] == 'mine']
    molotov = [e for e in data if e['id'] == MOLOTOV]

    # Название списка стоит перед именем предмета: «[grenade] Осколочная граната ×8».
    # Метки [grenade] / [mine] / [molotov] строка на экране рисует значками (из
    # уведомлений они убираются). Решение пользователя 2026-09-23: слабые — один
    # значок, мощные — два, у Молотова — значок молотова.
    # Порядок списков (пользователь, 2026-09-24): сначала все гранаты, потом мины.
    G, M = '[grenade]', '[mine]'
    lists = [
        ('Weak grenades: ascending damage, no Molotov cocktail', G, G, by_damage(grenades)),
        ('Strong grenades: descending damage, no Molotov cocktail', G + G, G + G, by_damage(grenades, reverse=True)),
        ('Weak mines: ascending damage', M, M, by_damage(mines)),
        ('Strong mines: descending damage', M + M, M + M, by_damage(mines, reverse=True)),
        ('Molotov cocktail', '[molotov]', '[molotov]', molotov),
    ]

    out = ['{',
           '    "_comment": "Explosives Cycler: up to 10 lists, cycled in this order. Lists after the 10th are ignored.",',
           '    "_comment": "This file is overwritten by mod updates. To change the lists, copy it to lists-user.json in this folder and edit the copy: if lists-user.json exists, this file is not read at all.",',
           '    "_comment": "Format: one key per line, one item per line, item = Plugin.esm|LocalHexID (as in LootMan). Items from plugins you do not have (DLC) are skipped.",',
           '    "_comment": "List name: name_<language> by sLanguage from Fallout4.ini (name_en, name_ru, name_de ...), falls back to name_en.",',
           '    "_comment": "The line is: List name Item x5. An empty list name shows the item alone.",',
           '    "_comment": "Icons in a list name: [grenade], [mine], [molotov] (lowercase), e.g. [grenade][grenade]. Game notifications cannot show icons and drop them.",',
           '    "_comment": "Reload in MCM: Explosives Cycler - Reload lists.",',
           '']
    seen = set()
    for e in by_damage(grenades + mines + molotov):
        if e['id'] not in seen:
            seen.add(e['id'])
            out.append('    "_comment": %s,' % q('%s = %s / %s (damage %g)' % (
                e['id'], e['name_en'], e['name_ru'], e['damage'])))
    out.append('')
    out.append('    "lists": [')
    for li, (about, name_en, name_ru, items) in enumerate(lists):
        out.append('        {')
        out.append('            "_comment": %s,' % q(about))
        out.append('            "name_en": %s,' % q(name_en))
        out.append('            "name_ru": %s,' % q(name_ru))
        out.append('            "items": [')
        for ii, e in enumerate(items):
            out.append('                %s%s' % (q(e['id']), ',' if ii + 1 < len(items) else ''))
        out.append('            ]')
        out.append('        }%s' % (',' if li + 1 < len(lists) else ''))
    out.append('    ]')
    out.append('}')
    text = '\n'.join(out) + '\n'

    json.loads(text.replace('"_comment"', '"_c"'))  # проверка, что это валидный JSON
    os.makedirs(os.path.dirname(DST), exist_ok=True)
    with open(DST, 'w', encoding='utf-8', newline='\r\n') as f:
        f.write(text)
    for about, name_en, name_ru, items in lists:
        print('%-18s %s' % (name_ru,', '.join('%s(%g)' % (e['name_ru'], e['damage']) for e in items)))
    print('->', os.path.relpath(DST, ROOT))


if __name__ == '__main__':
    main()
