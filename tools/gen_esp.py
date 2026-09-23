"""
Генератор `ExplosivesCycler.esp` (PLAN.md §4).

Единственный мастер — `Fallout4.esm`. Предметы списков в esp не попадают: они
разрешаются в рантайме из JSON (`Game.GetFormFromFile`), поэтому DLC не нужны.

Состав:
    QUST  EXC_Quest          — Start Game Enabled, скрипт EXC:CyclerQuest (вся логика)
    FLST  EXC_List01..10     — рабочие списки, наполняются из JSON
    FLST  EXC_AllExplosives  — объединение списков, фильтр событий инвентаря
    MGEF  EXC_CycleEffect    — архетип Script, скрипт EXC:CycleItemEffect
    ALCH  EXC_CycleItem      — предмет «Explosives Cycler» на вкладке «Помощь»

Шаблоны MGEF.DATA / ALCH / QUST.DNAM — те же, что в Survival AutoMedic (сняты с
рабочего QuickAid.esp), см. fo4-survival-automedic/tools/gen_esp.py.

    python tools/gen_esp.py [--out build/ExplosivesCycler.esp]
"""

import argparse
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from esp_writer import (PROP_ARRAY_OBJECT, PROP_OBJECT, Record, Script, build_plugin,
                        vmad, zstring)

PLUGIN_NAME = 'ExplosivesCycler.esp'

# --- FormID собственных записей (индекс файла 0x01, первые 0x800 зарезервированы) ---
# 0x800 зашит в MCM (config.json / keybinds.json: "ExplosivesCycler.esp|800").
FID_QUEST = 0x01000800
FID_LISTS = [0x01000801 + i for i in range(10)]      # 801..80A
FID_ALL = 0x0100080B
FID_MGEF = 0x0100080C
FID_ALCH = 0x0100080D
NEXT_OBJECT_ID = 0x0000080E

# --- ванильные FormID (Fallout4.esm), те же, что в AutoMedic ---
KYWD_OBJECT_TYPE_STIMPAK = 0x000F4AEB   # вкладка «Помощь»
KYWD_HC_IGNORE_AS_FOOD = 0x00249F52     # иначе Survival (SCM) считает предмет едой/стимпаком

SCRIPT_QUEST = 'EXC:CyclerQuest'
SCRIPT_EFFECT = 'EXC:CycleItemEffect'

ITEM_NAME = 'Explosives Cycler'
ITEM_DESC = ('Switches to the next explosives list (grenades / mines). '
             'Reusable - returns to your inventory after every use.')


def mgef_data():
    """MGEF.DATA 152 байта: Archetype Script (+0x40 = 1), остальное — как в QuickAid."""
    data = bytearray(152)
    struct.pack_into('<I', data, 0x40, 1)
    struct.pack_into('<I', data, 0x50, 1)
    struct.pack_into('<f', data, 0x70, 1.0)
    struct.pack_into('<I', data, 0x8C, 1)
    return bytes(data)


def build_qust():
    r = Record(b'QUST', FID_QUEST, 'EXC_Quest')
    s = Script(SCRIPT_QUEST)
    s.prop('EXC_Lists', PROP_ARRAY_OBJECT, FID_LISTS)
    s.prop('EXC_AllExplosives', PROP_OBJECT, FID_ALL)
    s.prop('EXC_CycleItem', PROP_OBJECT, FID_ALCH)
    r.add(b'VMAD', vmad([s]))
    r.add(b'FULL', zstring('Explosives Cycler'))
    # 0x0111 = Start Game Enabled | 0x10 | Run Once — как у AM_Quest / QuickAid.
    r.add(b'DNAM', struct.pack('<HBBII', 0x0111, 0, 0x5E, 0, 0))
    r.add(b'NEXT', b'')
    r.add(b'ANAM', struct.pack('<I', 0))            # алиасов нет
    return r


def build_flst():
    out = [Record(b'FLST', fid, 'EXC_List%02d' % (i + 1)) for i, fid in enumerate(FID_LISTS)]
    out.append(Record(b'FLST', FID_ALL, 'EXC_AllExplosives'))
    return out


def build_mgef():
    r = Record(b'MGEF', FID_MGEF, 'EXC_CycleEffect')
    s = Script(SCRIPT_EFFECT)
    s.prop('Cycler', PROP_OBJECT, FID_QUEST)
    s.prop('SelfItem', PROP_OBJECT, FID_ALCH)
    r.add(b'VMAD', vmad([s]))
    r.add(b'FULL', zstring(ITEM_NAME))
    r.add(b'DATA', mgef_data())
    r.add(b'SNDD', b'')
    r.add(b'DNAM', b'\x00')
    return r


def build_alch():
    r = Record(b'ALCH', FID_ALCH, 'EXC_CycleItem')
    r.add(b'OBND', struct.pack('<6h', -4, -4, -6, 4, 4, 6))
    r.add(b'FULL', zstring(ITEM_NAME))
    r.add(b'KSIZ', struct.pack('<I', 2))
    r.add(b'KWDA', struct.pack('<II', KYWD_OBJECT_TYPE_STIMPAK, KYWD_HC_IGNORE_AS_FOOD))
    r.add(b'MODL', zstring('Weapons\\Grenade\\GrenadeFrag.nif'))
    r.add(b'MODT', struct.pack('<I', 4) + bytes(16))
    r.add(b'DESC', zstring(ITEM_DESC))
    r.add(b'DATA', struct.pack('<f', 0.0))          # вес
    # ENIT: цена, флаги (NoAutoCalc | Medicine -> вкладка «Помощь»), зависимость,
    # шанс, звук употребления (0 = без звука).
    r.add(b'ENIT', struct.pack('<iIIfI', 0, 0x00010001, 0, 0.0, 0))
    r.add(b'DNAM', struct.pack('<I', 0))
    r.add(b'EFID', struct.pack('<I', FID_MGEF))
    r.add(b'EFIT', struct.pack('<fII', 0.0, 0, 0))
    return r


def check(path):
    from esm import Plugin
    plugin = Plugin(path)
    assert plugin.masters == ['Fallout4.esm'], 'мастера: %r' % (plugin.masters,)
    counts = {}
    for sig in (b'QUST', b'FLST', b'MGEF', b'ALCH'):
        counts[sig.decode()] = sum(1 for _ in plugin.records(sig))
    assert counts == {'QUST': 1, 'FLST': 11, 'MGEF': 1, 'ALCH': 1}, counts
    print('  проверка: мастер один, записи %s' % counts)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default=None)
    args = ap.parse_args()
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_path = args.out or os.path.join(root, 'build', PLUGIN_NAME)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    groups = [
        (b'MGEF', [build_mgef()]),
        (b'ALCH', [build_alch()]),
        (b'QUST', [build_qust()]),
        (b'FLST', build_flst()),
    ]
    blob = build_plugin(['Fallout4.esm'], groups, NEXT_OBJECT_ID)
    with open(out_path, 'wb') as f:
        f.write(blob)
    print('%s: %d байт' % (out_path, len(blob)))
    check(out_path)


if __name__ == '__main__':
    main()
