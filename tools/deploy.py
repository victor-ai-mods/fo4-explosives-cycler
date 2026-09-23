"""
Раскладка собранного мода по игре.

  python tools/deploy.py            — esp, .pex, файлы из mod/, включить плагин
  python tools/deploy.py --remove   — снять плагин и убрать файлы мода
  python tools/deploy.py --esh-off  — убрать Explosives Swap Hotkeys в _removed_mods
  python tools/deploy.py --esh-on   — вернуть Explosives Swap Hotkeys

Перед раскладкой собрать: gen_esp.py, gen_lists.py, gen_mcm.py и PapyrusCompiler
(README, раздел «Сборка»).

`Plugins.txt` в этой установке живёт в ДВУХ местах (игра читает
`%LOCALAPPDATA%\\Fallout4\\Plugins.txt`) — правятся оба. Всё, что перезаписывается,
сначала уезжает в `<игра>\\Backup`.

F4SE-версия `Form.pex` (в ней `Form.GetName()`, нужна для имени предмета в
уведомлении): в этой установке пакет скриптов F4SE стоит не целиком, в
`Data\\Scripts\\Form.pex` лежит ванильный. Если в нём нет GetName, раскладка кладёт
F4SE-версию из build/f4se (ванильный -> Data\\_backup\\vanilla_scripts).
"""

import argparse
import datetime
import os
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME = os.environ.get('FO4_PATH', r'D:\Games\Fallout 4')
DATA = os.path.join(GAME, 'Data')
PLUGIN = 'ExplosivesCycler.esp'
SCRIPTS = ['CyclerQuest.pex', 'CycleItemEffect.pex']
MOD_FILES = os.path.join(ROOT, 'mod')           # пути внутри — как от Data

PLUGIN_LISTS = [
    os.path.join(os.environ['LOCALAPPDATA'], 'Fallout4', 'Plugins.txt'),
    os.path.join(GAME, 'fallout4', 'Plugins.txt'),
]

ESH_PATHS = [
    r'F4SE\Plugins\ESH.dll',
    r'MCM\Config\ESH',
    r'MCM\Config\ESH_NukaWorld',
    r'MCM\Settings\ESH.ini',
    r'MCM\Settings\ESH_NukaWorld.ini',
    r'Scripts\ESH',
    r'Scripts\Source\User\ESH',
]
ESH_STORE = os.path.join(GAME, '_removed_mods', 'ExplosivesSwapHotkeys')


def backup(path):
    if not os.path.exists(path):
        return None
    stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
    target_dir = os.path.join(GAME, 'Backup')
    os.makedirs(target_dir, exist_ok=True)
    target = os.path.join(target_dir, '%s.%s.bak' % (os.path.basename(path), stamp))
    shutil.copy2(path, target)
    return target


def copy(src, dst):
    saved = backup(dst)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(src, dst)
    print('  %s%s' % (dst, ('  (старый -> %s)' % os.path.basename(saved)) if saved else ''))


def mod_files():
    out = []
    for base, _, names in os.walk(MOD_FILES):
        for name in names:
            out.append(os.path.relpath(os.path.join(base, name), MOD_FILES))
    return sorted(out)


def set_enabled(enabled):
    for path in PLUGIN_LISTS:
        if not os.path.exists(path):
            print('  нет %s — пропущено' % path)
            continue
        with open(path, encoding='utf-8-sig') as f:
            lines = f.read().splitlines()
        kept = [ln for ln in lines if ln.lstrip('*').strip().lower() != PLUGIN.lower()]
        if enabled:
            kept.append('*' + PLUGIN)
        if kept != lines:
            backup(path)
            with open(path, 'w', encoding='utf-8', newline='\n') as f:
                f.write('\n'.join(kept) + '\n')
        print('  %s: %s' % (path, 'включён' if enabled else 'выключен'))


def ensure_f4se_form():
    live = os.path.join(DATA, 'Scripts', 'Form.pex')
    if os.path.exists(live) and b'GetName' in open(live, 'rb').read():
        print('  Form.pex уже F4SE-версии')
        return
    src = os.path.join(ROOT, 'build', 'f4se', 'Form.pex')
    if not os.path.exists(src):
        raise SystemExit('нет %s — распакуйте Data/Scripts/Form.pex из f4se_0_06_23.7z' % src)
    if os.path.exists(live):
        keep = os.path.join(DATA, '_backup', 'vanilla_scripts')
        os.makedirs(keep, exist_ok=True)
        if not os.path.exists(os.path.join(keep, 'Form.pex')):
            shutil.copy2(live, os.path.join(keep, 'Form.pex'))
    copy(src, live)


def install():
    print('Файлы:')
    copy(os.path.join(ROOT, 'build', PLUGIN), os.path.join(DATA, PLUGIN))
    for name in SCRIPTS:
        copy(os.path.join(ROOT, 'build', 'scripts', 'EXC', name),
             os.path.join(DATA, 'Scripts', 'EXC', name))
    for rel in mod_files():
        copy(os.path.join(MOD_FILES, rel), os.path.join(DATA, rel))
    print('F4SE:')
    ensure_f4se_form()
    print('Порядок загрузки:')
    set_enabled(True)


def remove():
    print('Порядок загрузки:')
    set_enabled(False)
    print('Файлы:')
    paths = ([os.path.join(DATA, PLUGIN)] +
             [os.path.join(DATA, 'Scripts', 'EXC', n) for n in SCRIPTS] +
             [os.path.join(DATA, rel) for rel in mod_files()])
    for path in paths:
        if os.path.exists(path):
            backup(path)
            os.remove(path)
            print('  удалён %s' % path)


def esh(off):
    src_root, dst_root = (DATA, ESH_STORE) if off else (ESH_STORE, DATA)
    for rel in ESH_PATHS:
        src = os.path.join(src_root, rel)
        dst = os.path.join(dst_root, rel)
        if not os.path.exists(src):
            continue
        if os.path.exists(dst):
            raise SystemExit('уже существует: %s' % dst)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.move(src, dst)
        print('  %s -> %s' % (src, dst))


def main():
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group()
    g.add_argument('--remove', action='store_true')
    g.add_argument('--esh-off', action='store_true')
    g.add_argument('--esh-on', action='store_true')
    args = ap.parse_args()
    if args.remove:
        remove()
    elif args.esh_off or args.esh_on:
        esh(args.esh_off)
    else:
        install()
        print('\nesp и .pex подхватываются только при запуске игры.')


if __name__ == '__main__':
    main()
