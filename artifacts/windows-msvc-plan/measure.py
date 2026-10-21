"""Read bytes/PE headers only. Does not load or execute the compiled program."""
import hashlib
import json
import struct
import sys
from pathlib import Path

binary_dir, report_dir = map(Path, sys.argv[1:3])
symbols = sys.argv[3]
rows = []
for name, expected_subsystem in (
    ('godot.windows.template_release.x86_64.mono.exe', 2),
    ('godot.windows.template_release.x86_64.mono.console.exe', 3),
):
    path = binary_dir / name
    data = path.read_bytes()
    assert data[:2] == b'MZ', name
    pe = struct.unpack_from('<I', data, 0x3C)[0]
    assert data[pe:pe+4] == b'PE\0\0', name
    machine = struct.unpack_from('<H', data, pe+4)[0]
    optional = pe + 24
    magic = struct.unpack_from('<H', data, optional)[0]
    subsystem = struct.unpack_from('<H', data, optional+68)[0]
    assert (machine, magic, subsystem) == (0x8664, 0x20B, expected_subsystem), name
    rows.append(dict(file=name, bytes=len(data), MiB=len(data)/2**20,
                     sha256=hashlib.sha256(data).hexdigest(), machine=hex(machine), subsystem=subsystem))
metadata = dict(debug_symbols=symbols, outputs=rows,
                pdbs=[dict(file=p.name, bytes=p.stat().st_size) for p in binary_dir.glob('*.pdb')])
(report_dir/'sizes.json').write_text(json.dumps(metadata, indent=2)+'\n')
main = rows[0]['bytes']
lines = ['# MSVC release size (static measurement only)', '', f'Debug symbols: {symbols}. No Godot execution or tests.', '',
         '| Output | Bytes | MiB |', '|---|---:|---:|']
lines += [f"| {r['file']} | {r['bytes']:,} | {r['MiB']:.6f} |" for r in rows]
lines += ['', '| Main-only comparison | Baseline bytes | MSVC minus baseline | Change |', '|---|---:|---:|---:|']
for label, baseline in [('Same-feature MinGW GCC 14.2 stripped', 66711040), ('Official full .NET Release reference', 109513728)]:
    lines.append(f'| {label} | {baseline:,} | {main-baseline:+,} | {(main/baseline-1)*100:+.4f}% |')
lines += ['', 'PDB/map sizes are not added to EXE sizes. The console wrapper is separate.',
          'Official reference differs in enabled features and build environment; it is not a controlled compiler comparison.',
          'MSVC vs prior MinGW also differs in CRT/SDK/host; this is a practical toolchain experiment, not an official-build reproduction.']
if symbols == 'yes':
    lines += ['PDB-enabled variant: release /O2, /GL, /LTCG, /OPT:REF, /OPT:ICF retained; EXE contains debug-directory metadata. Do not treat it as the exact debug_symbols=no baseline.']
(report_dir/'SIZE.md').write_text('\n'.join(lines)+'\n')
print('\n'.join(lines))
