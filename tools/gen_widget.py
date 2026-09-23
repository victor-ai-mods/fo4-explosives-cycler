"""
Сборка виджета строки на экране: mod/Interface/ExplosivesCycler.swf.

Flash-редактора нет, поэтому в два шага:
  1. Здесь собирается SWF-заготовка (AS3, одна пустая кадровая сцена 1280x720, как у
     HUDMenu.swf, SWF 15) с пустым классом EXCWidget extends MovieClip — ABC-байткод
     написан руками, он нужен только как место, куда FFDec вставит настоящий класс.
  2. JPEXS FFDec (-importScript) компилирует widget/EXCWidget.as своим компилятором
     AS3 (playerglobal.swc идёт в комплекте FFDec) и заменяет класс в заготовке.

FFDec: https://github.com/jindrapetrik/jpexs-decompiler/releases (zip, нужна Java).
Путь к ffdec-cli.jar — переменная окружения FFDEC_JAR.

    python tools/gen_widget.py
"""

import os
import shutil
import struct
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'widget', 'EXCWidget.as')
BASE = os.path.join(ROOT, 'build', 'widget_base.swf')
OUT = os.path.join(ROOT, 'mod', 'Interface', 'ExplosivesCycler.swf')
CLASS = 'EXCWidget'


# --- ABC (AVM2 bytecode) ---------------------------------------------------

def u30(v):
    out = bytearray()
    while True:
        b = v & 0x7F
        v >>= 7
        if v:
            out.append(b | 0x80)
        else:
            out.append(b)
            return bytes(out)


def abc_string(s):
    raw = s.encode('utf-8')
    return u30(len(raw)) + raw


def build_abc():
    strings = ['', CLASS, 'flash.display', 'MovieClip', 'Object', 'flash.events',
               'EventDispatcher', 'DisplayObject', 'InteractiveObject',
               'DisplayObjectContainer', 'Sprite']
    s = {v: i for i, v in enumerate(strings)}
    # Пространства имён: 1 = пакет "", 2 = flash.display, 3 = flash.events (0x16 PackageNamespace)
    namespaces = [(0x16, s['']), (0x16, s['flash.display']), (0x16, s['flash.events'])]
    NS_ROOT, NS_DISPLAY, NS_EVENTS = 1, 2, 3
    # Мультиимена (0x07 QName)
    mn = [(NS_ROOT, CLASS), (NS_DISPLAY, 'MovieClip'), (NS_ROOT, 'Object'),
          (NS_EVENTS, 'EventDispatcher'), (NS_DISPLAY, 'DisplayObject'),
          (NS_DISPLAY, 'InteractiveObject'), (NS_DISPLAY, 'DisplayObjectContainer'),
          (NS_DISPLAY, 'Sprite')]
    m = {name: i + 1 for i, (_, name) in enumerate(mn)}

    out = bytearray(struct.pack('<HH', 16, 46))
    out += u30(0) + u30(0) + u30(0)                     # int, uint, double
    out += u30(len(strings)) + b''.join(abc_string(x) for x in strings[1:])
    out += u30(len(namespaces) + 1) + b''.join(bytes([k]) + u30(n) for k, n in namespaces)
    out += u30(0)                                       # ns_set
    out += u30(len(mn) + 1) + b''.join(b'\x07' + u30(ns) + u30(s[name]) for ns, name in mn)

    # Методы: 0 — конструктор экземпляра, 1 — инициализатор класса, 2 — скрипта.
    out += u30(3) + (u30(0) + u30(0) + u30(0) + b'\x00') * 3
    out += u30(0)                                       # metadata
    out += u30(1)                                       # classes
    out += u30(m[CLASS]) + u30(m['MovieClip']) + b'\x01' + u30(0) + u30(0) + u30(0)
    out += u30(1) + u30(0)                              # class_info: cinit, traits
    out += u30(1)                                       # scripts
    out += u30(2) + u30(1) + u30(m[CLASS]) + b'\x04' + u30(1) + u30(0)   # trait Class

    GETLOCAL0, PUSHSCOPE, POPSCOPE, RETURNVOID = 0xD0, 0x30, 0x1D, 0x47
    iinit = bytes([GETLOCAL0, PUSHSCOPE, GETLOCAL0, 0x49]) + u30(0) + bytes([RETURNVOID])
    cinit = bytes([GETLOCAL0, PUSHSCOPE, RETURNVOID])
    chain = ['Object', 'EventDispatcher', 'DisplayObject', 'InteractiveObject',
             'DisplayObjectContainer', 'Sprite', 'MovieClip']
    sinit = bytearray([GETLOCAL0, PUSHSCOPE, 0x65, 0])  # getscopeobject 0
    for name in chain:
        sinit += b'\x60' + u30(m[name]) + bytes([PUSHSCOPE])   # getlex + pushscope
    sinit += b'\x60' + u30(m['MovieClip'])              # базовый класс для newclass
    sinit += b'\x58' + u30(0)                           # newclass 0
    sinit += bytes([POPSCOPE] * len(chain))
    sinit += b'\x68' + u30(m[CLASS])                    # initproperty EXCWidget
    sinit += bytes([RETURNVOID])

    def body(method, max_stack, locals_, init_scope, max_scope, code):
        return (u30(method) + u30(max_stack) + u30(locals_) + u30(init_scope) +
                u30(max_scope) + u30(len(code)) + bytes(code) + u30(0) + u30(0))

    out += u30(3)
    out += body(0, 1, 1, 9, 10, iinit)
    out += body(1, 1, 1, 8, 9, cinit)
    out += body(2, 2, 1, 1, 9, sinit)
    return bytes(out)


# --- SWF -------------------------------------------------------------------

def tag(code, payload):
    if len(payload) < 0x3F:
        return struct.pack('<H', (code << 6) | len(payload)) + payload
    return struct.pack('<HI', (code << 6) | 0x3F, len(payload)) + payload


def rect(xmin, xmax, ymin, ymax):
    vals = [xmin, xmax, ymin, ymax]
    nbits = max(v.bit_length() for v in vals) + 1
    bits = format(nbits, '05b') + ''.join(format(v, '0%db' % nbits) for v in vals)
    bits += '0' * (-len(bits) % 8)
    return bytes(int(bits[i:i + 8], 2) for i in range(0, len(bits), 8))


def build_base_swf():
    body = rect(0, 1280 * 20, 0, 720 * 20) + struct.pack('<HH', 30 << 8, 1)
    body += tag(69, struct.pack('<I', 0x08))            # FileAttributes: ActionScript 3
    body += tag(9, b'\x00\x00\x00')                     # SetBackgroundColor
    body += tag(82, struct.pack('<I', 1) + b'\x00' + build_abc())   # DoABC
    body += tag(76, struct.pack('<HH', 1, 0) + CLASS.encode() + b'\x00')   # SymbolClass
    body += tag(1, b'')                                 # ShowFrame
    body += tag(0, b'')                                 # End
    return b'FWS' + bytes([15]) + struct.pack('<I', len(body) + 8) + body


def ffdec_jar():
    jar = os.environ.get('FFDEC_JAR')
    if not jar or not os.path.exists(jar):
        raise SystemExit('задайте FFDEC_JAR — путь к ffdec-cli.jar из архива JPEXS FFDec')
    return jar


def main():
    os.makedirs(os.path.dirname(BASE), exist_ok=True)
    with open(BASE, 'wb') as f:
        f.write(build_base_swf())
    print('заготовка:', os.path.relpath(BASE, ROOT))

    work = tempfile.mkdtemp(prefix='exc_widget_')
    try:
        scripts = os.path.join(work, 'scripts')
        os.makedirs(scripts)
        shutil.copy2(SRC, os.path.join(scripts, CLASS + '.as'))
        os.makedirs(os.path.dirname(OUT), exist_ok=True)
        cmd = ['java', '-jar', ffdec_jar(), '-importScript', BASE, OUT, work]
        res = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8', errors='replace')
        sys.stdout.write(res.stdout[-3000:])
        sys.stderr.write(res.stderr[-3000:])
        if res.returncode != 0 or not os.path.exists(OUT):
            raise SystemExit('FFDec: ошибка (код %d)' % res.returncode)
    finally:
        shutil.rmtree(work, ignore_errors=True)
    print('виджет:', os.path.relpath(OUT, ROOT), os.path.getsize(OUT), 'байт')


if __name__ == '__main__':
    main()
