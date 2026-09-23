"""
Генератор MCM и переводов (PLAN.md §5).

Выход (в mod/, откуда их раскладывает tools/deploy.py):
    MCM/Config/ExplosivesCycler/config.json    — страница, все тексты токенами $EXC_*
    MCM/Config/ExplosivesCycler/keybinds.json  — 4 клавиши -> функции EXC:CyclerQuest
    MCM/Config/ExplosivesCycler/settings.ini   — значения по умолчанию
    Interface/Translations/ExplosivesCycler_{en,ru}.txt — UTF-16 LE с BOM, TAB, CRLF

Новый язык — ещё один словарь в STRINGS (и файл перевода появится сам).

    python tools/gen_mcm.py
"""

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'mod')
MOD = 'ExplosivesCycler'
QUEST = 'ExplosivesCycler.esp|800'
SCRIPT = 'EXC:CyclerQuest'

STRINGS = {
    'en': {
        'MOD_NAME': 'Explosives Cycler',
        'ABOUT': 'Grenade and mine lists from Data\\ExplosivesCycler\\lists-default.json (or lists-user.json). '
                 'The hotkeys or the Explosives Cycler item (Aid) switch lists; when the equipped explosive runs out, '
                 'the next one from the same list is equipped.',
        'SEC_KEYS': 'Hotkeys',
        'KEY_NEXT_LIST': 'Next list',
        'KEY_NEXT_LIST_HELP': 'Switch to the next list that has something in your inventory and equip its first item. '
                              'Same as using the Explosives Cycler item.',
        'KEY_PREV_LIST': 'Previous list',
        'KEY_PREV_LIST_HELP': 'Switch to the previous list that has something in your inventory and equip its first item.',
        'KEY_NEXT_ITEM': 'Next item in the current list',
        'KEY_NEXT_ITEM_HELP': 'Equip the next item of the current list that you have, going round in a circle.',
        'KEY_PREV_ITEM': 'Previous item in the current list',
        'KEY_PREV_ITEM_HELP': 'Equip the previous item of the current list that you have, going round in a circle.',
        'SEC_BEHAVIOR': 'Behavior',
        'AUTO_NEXT': 'Equip the next item when the current one runs out',
        'AUTO_NEXT_HELP': 'After the last grenade or mine is thrown, equip the next one from the same list. '
                          'If the list is empty, a message is shown and nothing else is equipped.',
        'EQUIP_PICKUP': 'Equip picked up items',
        'EQUIP_PICKUP_HELP': 'If nothing is equipped for throwing and you pick up a grenade or mine from the current list, equip it.',
        'SEC_DISPLAY': 'On-screen text',
        'DISPLAY': 'Show the selection',
        'DISPLAY_HELP': 'On-screen line changes instantly on every key press; notifications (top left) queue up one after another.',
        'DISPLAY_OFF': 'Nothing',
        'DISPLAY_NOTIFY': 'Notifications',
        'DISPLAY_LINE': 'On-screen line',
        'DISPLAY_BOTH': 'Line and notifications',
        'SHOW_COUNT': 'Show the count',
        'SHOW_COUNT_HELP': 'How many of the equipped explosive you carry: "Frag Grenade ×8 (–)". Updated after every throw.',
        'HIDE_AFTER': 'Hide the line after, s',
        'HIDE_AFTER_HELP': '0 - never hide: the line always shows the current item.',
        'POS_X': 'Position X, % of screen width',
        'POS_X_HELP': '0 - left edge, 100 - right edge. Close the menu to see the line in its new place.',
        'POS_Y': 'Position Y, % of screen height',
        'POS_Y_HELP': '0 - top edge, 100 - bottom edge. Close the menu to see the line in its new place.',
        'ALIGN': 'Alignment',
        'ALIGN_HELP': 'Which end of the line stays at the position point.',
        'ALIGN_LEFT': 'Left',
        'ALIGN_CENTER': 'Center',
        'ALIGN_RIGHT': 'Right',
        'FONT_SIZE': 'Font size',
        'FONT_SIZE_HELP': 'Text size of the line.',
        'COLOR': 'Color',
        'COLOR_HELP': 'HUD color - as the game HUD: the normal HUD color, and in power armor the power armor HUD color.',
        'COLOR_HUD': 'HUD color',
        'COLOR_WHITE': 'White',
        'COLOR_AMBER': 'Amber',
        'COLOR_BLUE': 'Blue',
        'COLOR_RED': 'Red',
        'SEC_LISTS': 'Lists',
        'RELOAD': 'Reload lists',
        'RELOAD_HELP': 'Read the lists file again after editing it. lists-user.json, if present, replaces lists-default.json.',
        'GIVE_ITEM': 'Give the Explosives Cycler item',
        'GIVE_ITEM_HELP': 'Adds the Explosives Cycler item to the Aid tab if you have lost it.',
        'SEC_DEBUG': 'Troubleshooting',
        'LOG_LEVEL': 'Log',
        'LOG_LEVEL_HELP': 'Data\\ExplosivesCycler\\ExplosivesCycler.log (previous session - ExplosivesCycler.1.log).',
        'LOG_OFF': 'Off',
        'LOG_NORMAL': 'Normal',
        'LOG_DEBUG': 'Detailed',
    },
    'ru': {
        'MOD_NAME': 'Explosives Cycler',
        'ABOUT': 'Списки гранат и мин — Data\\ExplosivesCycler\\lists-default.json (или lists-user.json). '
                 'Клавиши или предмет Explosives Cycler («Помощь») переключают списки; когда экипированная '
                 'взрывчатка кончается, берётся следующая из того же списка.',
        'SEC_KEYS': 'Клавиши',
        'KEY_NEXT_LIST': 'Следующий список',
        'KEY_NEXT_LIST_HELP': 'Перейти к следующему списку, в котором что-то есть в инвентаре, и экипировать его первый предмет. '
                              'То же делает предмет Explosives Cycler.',
        'KEY_PREV_LIST': 'Предыдущий список',
        'KEY_PREV_LIST_HELP': 'Перейти к предыдущему списку, в котором что-то есть в инвентаре, и экипировать его первый предмет.',
        'KEY_NEXT_ITEM': 'Следующий предмет в текущем списке',
        'KEY_NEXT_ITEM_HELP': 'Экипировать следующий имеющийся предмет текущего списка, по кругу.',
        'KEY_PREV_ITEM': 'Предыдущий предмет в текущем списке',
        'KEY_PREV_ITEM_HELP': 'Экипировать предыдущий имеющийся предмет текущего списка, по кругу.',
        'SEC_BEHAVIOR': 'Поведение',
        'AUTO_NEXT': 'Брать следующий предмет, когда кончился текущий',
        'AUTO_NEXT_HELP': 'Брошена последняя граната или мина — экипировать следующую из того же списка. '
                          'Если список пуст, выводится сообщение, и больше ничего не экипируется.',
        'EQUIP_PICKUP': 'Экипировать подобранное',
        'EQUIP_PICKUP_HELP': 'Если для броска ничего не экипировано, а подобрана граната или мина из текущего списка, экипировать её.',
        'SEC_DISPLAY': 'Строка на экране',
        'DISPLAY': 'Показывать выбор',
        'DISPLAY_HELP': 'Строка на экране меняется сразу при каждом нажатии; уведомления (слева вверху) идут очередью, одно за другим.',
        'DISPLAY_OFF': 'Никак',
        'DISPLAY_NOTIFY': 'Уведомлениями',
        'DISPLAY_LINE': 'Строкой на экране',
        'DISPLAY_BOTH': 'Строкой и уведомлениями',
        'SHOW_COUNT': 'Показывать количество',
        'SHOW_COUNT_HELP': 'Сколько экипированной взрывчатки в инвентаре: «Осколочная граната ×8 (–)». Число обновляется после каждого броска.',
        'HIDE_AFTER': 'Скрывать строку через, с',
        'HIDE_AFTER_HELP': '0 — не скрывать: строка всегда показывает текущий предмет.',
        'POS_X': 'Положение X, % ширины экрана',
        'POS_X_HELP': '0 — левый край, 100 — правый. Закройте меню, чтобы увидеть строку на новом месте.',
        'POS_Y': 'Положение Y, % высоты экрана',
        'POS_Y_HELP': '0 — верхний край, 100 — нижний. Закройте меню, чтобы увидеть строку на новом месте.',
        'ALIGN': 'Выравнивание',
        'ALIGN_HELP': 'Какой край строки стоит в точке положения.',
        'ALIGN_LEFT': 'По левому краю',
        'ALIGN_CENTER': 'По центру',
        'ALIGN_RIGHT': 'По правому краю',
        'FONT_SIZE': 'Размер шрифта',
        'FONT_SIZE_HELP': 'Размер текста строки.',
        'COLOR': 'Цвет',
        'COLOR_HELP': 'Цвет HUD — как у HUD игры: обычный цвет HUD, а в силовой броне — цвет HUD силовой брони.',
        'COLOR_HUD': 'Цвет HUD',
        'COLOR_WHITE': 'Белый',
        'COLOR_AMBER': 'Янтарный',
        'COLOR_BLUE': 'Голубой',
        'COLOR_RED': 'Красный',
        'SEC_LISTS': 'Списки',
        'RELOAD': 'Перечитать списки',
        'RELOAD_HELP': 'Прочитать файл списков заново после правки. lists-user.json, если он есть, заменяет lists-default.json.',
        'GIVE_ITEM': 'Выдать предмет Explosives Cycler',
        'GIVE_ITEM_HELP': 'Кладёт предмет Explosives Cycler во вкладку «Помощь», если он потерялся.',
        'SEC_DEBUG': 'Диагностика',
        'LOG_LEVEL': 'Лог',
        'LOG_LEVEL_HELP': 'Data\\ExplosivesCycler\\ExplosivesCycler.log (прошлая сессия — ExplosivesCycler.1.log).',
        'LOG_OFF': 'Выкл.',
        'LOG_NORMAL': 'Обычный',
        'LOG_DEBUG': 'Подробный',
    },
}

HOTKEYS = [
    ('NextListHotkey', 'KEY_NEXT_LIST', 'NextList'),
    ('PrevListHotkey', 'KEY_PREV_LIST', 'PrevList'),
    ('NextItemHotkey', 'KEY_NEXT_ITEM', 'NextItem'),
    ('PrevItemHotkey', 'KEY_PREV_ITEM', 'PrevItem'),
]

SETTINGS = [
    ('bAutoNext', 1),
    ('bEquipPickup', 1),
    ('bShowCount', 1),
    ('iLogLevel', 1),
    ('iDisplay', 2),
    ('iAlign', 2),
    ('iFontSize', 22),
    ('iColor', 0),
]
SETTINGS_FLOAT = [
    ('fHideAfter', 0.0),
    ('fPosX', 98.0),
    ('fPosY', 64.5),
]


def t(key):
    return '$EXC_' + key


def call(function):
    return {'type': 'CallFunction', 'form': QUEST, 'scriptName': SCRIPT,
            'function': function, 'params': []}


def switcher(setting, key):
    return {'id': setting + ':Main', 'type': 'switcher', 'text': t(key), 'help': t(key + '_HELP'),
            'valueOptions': {'sourceType': 'ModSettingBool'}}


def dropdown(setting, key, options):
    return {'id': setting + ':Main', 'type': 'dropdown', 'text': t(key), 'help': t(key + '_HELP'),
            'valueOptions': {'sourceType': 'ModSettingInt', 'options': [t(o) for o in options]}}


def slider(setting, key, lo, hi, step, is_float):
    return {'id': setting + ':Main', 'type': 'slider', 'text': t(key), 'help': t(key + '_HELP'),
            'valueOptions': {'min': lo, 'max': hi, 'step': step,
                             'sourceType': 'ModSettingFloat' if is_float else 'ModSettingInt'}}


def config():
    content = [
        {'type': 'text', 'text': t('ABOUT')},
        {'type': 'spacer'},
        {'type': 'section', 'text': t('SEC_KEYS')},
    ]
    for hid, key, _ in HOTKEYS:
        content.append({'id': hid, 'type': 'hotkey', 'text': t(key), 'help': t(key + '_HELP')})
    content += [
        {'type': 'spacer'},
        {'type': 'section', 'text': t('SEC_BEHAVIOR')},
        switcher('bAutoNext', 'AUTO_NEXT'),
        switcher('bEquipPickup', 'EQUIP_PICKUP'),
        {'type': 'spacer'},
        {'type': 'section', 'text': t('SEC_DISPLAY')},
        dropdown('iDisplay', 'DISPLAY', ['DISPLAY_OFF', 'DISPLAY_NOTIFY', 'DISPLAY_LINE', 'DISPLAY_BOTH']),
        switcher('bShowCount', 'SHOW_COUNT'),
        slider('fHideAfter', 'HIDE_AFTER', 0, 30, 0.5, True),
        slider('fPosX', 'POS_X', 0, 100, 0.5, True),
        slider('fPosY', 'POS_Y', 0, 100, 0.5, True),
        dropdown('iAlign', 'ALIGN', ['ALIGN_LEFT', 'ALIGN_CENTER', 'ALIGN_RIGHT']),
        slider('iFontSize', 'FONT_SIZE', 12, 48, 1, False),
        dropdown('iColor', 'COLOR', ['COLOR_HUD', 'COLOR_WHITE', 'COLOR_AMBER', 'COLOR_BLUE', 'COLOR_RED']),
        {'type': 'spacer'},
        {'type': 'section', 'text': t('SEC_LISTS')},
        {'type': 'button', 'text': t('RELOAD'), 'help': t('RELOAD_HELP'), 'action': call('McmReloadLists')},
        {'type': 'button', 'text': t('GIVE_ITEM'), 'help': t('GIVE_ITEM_HELP'), 'action': call('McmGiveItem')},
        {'type': 'spacer'},
        {'type': 'section', 'text': t('SEC_DEBUG')},
        {'id': 'iLogLevel:Main', 'type': 'dropdown', 'text': t('LOG_LEVEL'), 'help': t('LOG_LEVEL_HELP'),
         'valueOptions': {'sourceType': 'ModSettingInt',
                          'options': [t('LOG_OFF'), t('LOG_NORMAL'), t('LOG_DEBUG')]}},
    ]
    return {
        'modName': MOD,
        'displayName': t('MOD_NAME'),
        'minMcmVersion': 2,
        'pluginRequirements': ['ExplosivesCycler.esp'],
        # Без pages: настройки видны сразу по клику на имя мода, без подраздела
        # с тем же названием (просьба пользователя, 2026-09-23).
        'content': content,
    }


def keybinds():
    return {'modName': MOD, 'keybinds': [
        {'id': hid, 'desc': t(key), 'action': call(function)} for hid, key, function in HOTKEYS]}


def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8', newline='\r\n') as f:
        json.dump(data, f, ensure_ascii=False, indent=4)
        f.write('\n')


def main():
    cfg_dir = os.path.join(OUT, 'MCM', 'Config', MOD)
    write_json(os.path.join(cfg_dir, 'config.json'), config())
    write_json(os.path.join(cfg_dir, 'keybinds.json'), keybinds())
    with open(os.path.join(cfg_dir, 'settings.ini'), 'w', encoding='ascii', newline='\r\n') as f:
        f.write('[Main]\n' + ''.join('%s=%d\n' % kv for kv in SETTINGS) +
                ''.join('%s=%.1f\n' % kv for kv in SETTINGS_FLOAT))

    keys = set(STRINGS['en'])
    tr_dir = os.path.join(OUT, 'Interface', 'Translations')
    os.makedirs(tr_dir, exist_ok=True)
    for lang, table in STRINGS.items():
        assert set(table) == keys, '%s: ключи не совпадают с en: %s' % (lang, keys ^ set(table))
        for k, v in table.items():
            assert '\t' not in v and '\n' not in v, (lang, k)
            if k.endswith('_HELP') and len(v) > 165:
                print('  ! %s %s: подсказка %d символов (> 165 — мелкий шрифт)' % (lang, k, len(v)))
        text = ''.join('%s\t%s\r\n' % (t(k), v) for k, v in table.items())
        with open(os.path.join(tr_dir, '%s_%s.txt' % (MOD, lang)), 'wb') as f:
            f.write(b'\xff\xfe' + text.encode('utf-16-le'))
    print('MCM: %s, переводы: %s' % (os.path.relpath(cfg_dir, ROOT), ', '.join(STRINGS)))


if __name__ == '__main__':
    main()
