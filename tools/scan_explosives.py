"""
Скан гранат и мин из ванили и DLC: WEAP (тип анимации Grenade/Mine) -> PROJ -> EXPL.

Поле damage = урон взрыва + урон зачарования взрыва по Health + число дочерних
зарядов x их урон (импульсные гранаты бьют только зачарованием, MIRV — пятью
дочерними зарядами). Сортировка списков идёт по нему (tools/gen_lists.py).

Запуск:  python tools/scan_explosives.py ["D:\\Games\\Fallout 4\\Data"]
Выход:   data/explosives.json (файлы игры, в репозиторий не кладётся)
"""

import json
import os
import struct
import sys

from ba2 import BA2
from esm import Plugin, decode_zstring
import strings_file

PLUGINS = [
    'Fallout4.esm',
    'DLCRobot.esm',
    'DLCworkshop01.esm',
    'DLCCoast.esm',
    'DLCworkshop02.esm',
    'DLCworkshop03.esm',
    'DLCNukaWorld.esm',
]

STRING_ARCHIVES = {
    'Fallout4.esm': ('Fallout4 - Interface.ba2', 'fallout4'),
    'DLCRobot.esm': ('DLCRobot - Main.ba2', 'dlcrobot'),
    'DLCworkshop01.esm': ('DLCworkshop01 - Main.ba2', 'dlcworkshop01'),
    'DLCCoast.esm': ('DLCCoast - Main.ba2', 'dlccoast'),
    'DLCworkshop02.esm': ('DLCworkshop02 - Main.ba2', 'dlcworkshop02'),
    'DLCworkshop03.esm': ('DLCworkshop03 - Main.ba2', 'dlcworkshop03'),
    'DLCNukaWorld.esm': ('DLCNukaWorld - Main.ba2', 'dlcnukaworld'),
}

ANIM_GRENADE = 10
ANIM_MINE = 11
REC_NON_PLAYABLE = 0x00000004
WEAP_NOT_PLAYABLE = 0x00100000


def load_strings(data_dir, lang):
    table = {}
    for plugin_name, (archive, stem) in STRING_ARCHIVES.items():
        path = os.path.join(data_dir, archive)
        if os.path.exists(path):
            table[plugin_name] = strings_file.load_from_ba2(BA2(path), stem, lang)
    return table


def key(plugin, form_id):
    origin, local = plugin.resolve(form_id)
    return '%s|%06X' % (origin, local)


def collect(plugins, sig):
    out = {}
    for p in plugins:
        for r in p.records(sig):
            out[key(p, r.form_id)] = (p, r)
    return out


def name_of(plugin, rec, strings):
    full = rec.first(b'FULL')
    if not full:
        return None
    origin, _ = plugin.resolve(rec.form_id)
    if len(full) == 4:  # локализованный плагин: id строки
        sid = struct.unpack('<I', full)[0]
        return strings.get(origin, {}).get(sid)
    return decode_zstring(full)


def ref(plugin, raw_id):
    return key(plugin, raw_id) if raw_id else None


AV_HEALTH = 0x0002D4


def enchant_damage(key, recs):
    """Сумма EFIT-магнитуд эффектов ENCH, бьющих по Health (архетип ValueModifier)."""
    if key not in recs:
        return 0.0
    p, r = recs[key]
    subs = list(r.subrecords())
    total = 0.0
    for i, (tag, payload) in enumerate(subs):
        if tag != b'EFID' or i + 1 >= len(subs):
            continue
        mkey = ref(p, struct.unpack('<I', payload)[0])
        if mkey not in recs:
            continue
        md = recs[mkey][1].first(b'DATA')
        arch = struct.unpack_from('<I', md, 0x40)[0]
        av = struct.unpack_from('<I', md, 0x44)[0]
        if arch == 0 and av == AV_HEALTH:
            total += struct.unpack_from('<f', subs[i + 1][1], 0)[0]
    return total


def explosion_damage(key, recs, depth=0):
    """
    Урон взрыва с учётом зачарования и дочерних снарядов:
    Damage + урон ENCH по Health + Spawn.Count x урон взрыва дочернего PROJ.
    EXPL.DATA: Damage @28, Spawn Projectile @20, Spawn.Count @80.
    """
    if key not in recs or depth > 3:
        return 0.0
    p, r = recs[key]
    d = r.first(b'DATA')
    total = struct.unpack_from('<f', d, 28)[0]
    eitm = r.first(b'EITM')
    if eitm:
        total += enchant_damage(ref(p, struct.unpack('<I', eitm)[0]), recs)
    spawn = struct.unpack_from('<I', d, 20)[0]
    count = struct.unpack_from('<I', d, 80)[0] if len(d) >= 84 else 0
    if spawn and count:
        pkey = ref(p, spawn)
        if pkey in recs:
            pp, pr = recs[pkey]
            pd = pr.first(b'DNAM')
            child = ref(pp, struct.unpack_from('<I', pd, 32)[0])
            total += count * explosion_damage(child, recs, depth + 1)
    return total


def main():
    data_dir = sys.argv[1] if len(sys.argv) > 1 else r'D:\Games\Fallout 4\Data'
    plugins = [Plugin(os.path.join(data_dir, n)) for n in PLUGINS
               if os.path.exists(os.path.join(data_dir, n))]
    names = {lang: load_strings(data_dir, lang) for lang in ('en', 'ru')}

    projs = collect(plugins, b'PROJ')
    expls = collect(plugins, b'EXPL')
    recs = {}
    for sig in (b'PROJ', b'EXPL', b'ENCH', b'MGEF'):
        recs.update(collect(plugins, sig))

    out = []
    for k, (p, r) in collect(plugins, b'WEAP').items():
        dnam = r.first(b'DNAM')
        if not dnam or len(dnam) < 69:
            continue
        anim = dnam[54]
        if anim not in (ANIM_GRENADE, ANIM_MINE):
            continue
        wflags = struct.unpack_from('<I', dnam, 48)[0]
        value = struct.unpack_from('<I', dnam, 63)[0]
        weight = struct.unpack_from('<f', dnam, 59)[0]
        base_dmg = struct.unpack_from('<H', dnam, 67)[0]
        dama = r.first(b'DAMA') or b''
        dmg_types = [(ref(p, struct.unpack_from('<I', dama, i)[0]),
                      struct.unpack_from('<I', dama, i + 4)[0])
                     for i in range(0, len(dama) - 7, 8)]

        fnam = r.first(b'FNAM')
        proj_key = ref(p, struct.unpack_from('<I', fnam, 29)[0]) if fnam and len(fnam) >= 33 else None
        expl_key = expl_dmg = expl_ench = spawn_proj = placed = None
        expl_name = None
        if proj_key in projs:
            pp, pr = projs[proj_key]
            pd = pr.first(b'DNAM')
            if pd and len(pd) >= 36:
                expl_key = ref(pp, struct.unpack_from('<I', pd, 32)[0])
        if expl_key in expls:
            ep, er = expls[expl_key]
            ed = er.first(b'DATA')
            expl_name = er.editor_id()
            if ed and len(ed) >= 32:
                placed = ref(ep, struct.unpack_from('<I', ed, 16)[0])
                spawn_proj = ref(ep, struct.unpack_from('<I', ed, 20)[0])
                expl_dmg = struct.unpack_from('<f', ed, 28)[0]
            eitm = er.first(b'EITM')
            expl_ench = ref(ep, struct.unpack('<I', eitm)[0]) if eitm else None

        out.append({
            'id': k,
            'edid': r.editor_id(),
            'type': 'mine' if anim == ANIM_MINE else 'grenade',
            'name_en': name_of(p, r, names['en']),
            'name_ru': name_of(p, r, names['ru']),
            'playable': not (r.flags & REC_NON_PLAYABLE) and not (wflags & WEAP_NOT_PLAYABLE),
            'template': ref(p, struct.unpack('<I', r.first(b'CNAM'))[0]) if r.first(b'CNAM') else None,
            'value': value,
            'weight': round(weight, 2),
            'weap_base_damage': base_dmg,
            'weap_damage_types': dmg_types,
            'projectile': proj_key,
            'explosion': expl_key,
            'explosion_edid': expl_name,
            'explosion_damage': expl_dmg,
            'damage': round(explosion_damage(expl_key, recs), 1) if expl_key else 0.0,
            'explosion_enchantment': expl_ench,
            'explosion_spawn_projectile': spawn_proj,
            'explosion_placed_object': placed,
        })

    out.sort(key=lambda e: (e['type'], -e['damage'], e['value']))
    dst = os.path.join(os.path.dirname(__file__), '..', 'data', 'explosives.json')
    with open(dst, 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    for e in out:
        print('%-7s %-24s %-2s dmg=%-6s expl=%-6s value=%-4s %-38s %s' % (
            e['type'], e['id'], 'P' if e['playable'] else '-', e['damage'],
            e['explosion_damage'], e['value'], e['edid'], e['name_ru']))
    print('%d записей -> %s' % (len(out), os.path.normpath(dst)))


if __name__ == '__main__':
    main()
