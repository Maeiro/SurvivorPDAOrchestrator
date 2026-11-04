"""Run behavioral simulations in Lua 5.1 and validate the package assets."""
import json
import re
import subprocess
from pathlib import Path

from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
NATIVE = Path('D:/SteamLibrary/steamapps/workshop/content/108600/3826426915/mods/ProjectRPGExpanded/42/media/lua')
MOD = ROOT / 'Contents/mods/SurvivorPDAOrchestrator'
LUA = MOD / '42/media/lua'
total = 0
for test in sorted((ROOT / 'tests').glob('test_*.lua')):
    runtime = LuaRuntime(unpack_returned_tuples=True)
    runtime.globals().MOD_ROOT = MOD.as_posix()
    runtime.globals().NATIVE_LUA = NATIVE.as_posix() if NATIVE.is_dir() else None
    runtime.globals().JSON_DECODE = lambda text: runtime.table_from(json.loads(text))
    paths = ';'.join((LUA / d / '?.lua').as_posix() for d in ('shared', 'server', 'client'))
    paths += ';' + (ROOT / 'tests/?.lua').as_posix()
    runtime.execute('package.path = ... .. ";" .. package.path; TEST_COUNT = 0', paths)
    runtime.execute('print = function() end')
    runtime.execute(test.read_text(encoding='utf-8'))
    count = runtime.globals().TEST_COUNT
    total += count
    print(f'{test.name}: {count} assertions passed')
for source in LUA.rglob('*.lua'):
    subprocess.run(['luac', '-p', str(source)], check=True)
en = json.loads((LUA / 'shared/Translate/EN/UI.json').read_text(encoding='utf-8'))
pt = json.loads((LUA / 'shared/Translate/PTBR/UI.json').read_text(encoding='utf-8'))
assert en.keys() == pt.keys(), 'UI translation coverage differs'
options = (MOD / '42/media/sandbox-options.txt').read_text(encoding='utf-8')
keys = re.findall(r'option ProjectRPGExpanded\.(\w+)', options)
assert len(keys) == len(set(keys)), 'Duplicate sandbox options'
for language in ('EN', 'PTBR'):
    sandbox = json.loads((LUA / f'shared/Translate/{language}/Sandbox.json').read_text(encoding='utf-8'))
    assert all('Sandbox_' + key in sandbox for key in keys)
root_info = dict(line.split('=', 1) for line in (MOD / 'mod.info').read_text().splitlines() if '=' in line)
b42_info = dict(line.split('=', 1) for line in (MOD / '42/mod.info').read_text().splitlines() if '=' in line)
assert all(b42_info.get(key) == value for key, value in root_info.items()), 'Shared metadata must match'
assert b42_info['javaJarFile'] == 'media/java/client/SurvivorPDAOrchestrator.jar'
assert b42_info['javaPkgName'] == 'maeiro.survivorpdaorchestrator'
print(f'{total} behavioral assertions; Lua 5.1 syntax, translations and {len(keys)} sandbox declarations passed.')
