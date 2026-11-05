import glob, io, os, re, sys

TIME_SENS = ('tap', 'hit', 'fire', 'shoot', 'press', 'strike', 'click', 'push', 'drop',
             'swing', 'jump', 'flip', 'roll', 'step')

def analyze(src):
    """返回 (可疑?, 说明, 顶层调用列表)"""
    m = re.search(r'private\s+autoStep\s*\([^)]*\)\s*:\s*boolean\s*\{', src)
    if not m:
        return None
    lines = src.split('\n')
    idx = src[:m.start()].count('\n')
    # 找函数体的顶层缩进（第一行 `{` 那行的缩进 + 2）
    base = len(lines[idx]) - len(lines[idx].lstrip())
    body_indent = base + 2
    # 收集函数体的行（到配对的 `}`）
    depth = 0; began = False; body = []
    for q in range(idx, min(len(lines), idx + 80)):
        depth += lines[q].count('{') - lines[q].count('}')
        if '{' in lines[q]: began = True
        body.append((q + 1, lines[q]))
        if began and depth <= 0: break

    # 逐行找「缩进 == body_indent」且形如 `this.xxx();` 的调用
    toplevel = []
    for ln, l in body:
        st = l.strip()
        if not st or st.startswith('//') or st.startswith('*'):
            continue
        ind = len(l) - len(l.lstrip())
        if ind != body_indent:
            continue
        mm = re.match(r'this\.(\w+)\s*\(\s*\)\s*;', st)
        if mm:
            toplevel.append((ln, mm.group(1)))

    ts = [(ln, c) for ln, c in toplevel if any(k in c.lower() for k in TIME_SENS)]
    if ts:
        return (True, '顶层无条件调用时序动作', ts)
    return (False, '无顶层时序调用', toplevel)

if __name__ == '__main__':
    mode = sys.argv[1] if len(sys.argv) > 1 else 'scan'
    if mode == 'known':
        # 验证：修复前版本必须命中
        src = io.open('/tmp/GFrequencyTap_BEFORE.ets', encoding='utf-8').read()
        r = analyze(src)
        print('  ── 已知案例（修复前 GFrequencyTap）──')
        if r is None:
            print('    🔴 找不到 autoStep')
        else:
            sus, why, hits = r
            print('    结论: %s（%s）' % ('**可疑** ✅' if sus else '不可疑 🔴', why))
            print('    命中: %s' % hits)
            print()
            print('  %s' % ('✅ **扫描器能报出已知案例** ⇒ 结果可信' if sus else '🔴 **扫描器漏了已知案例** ⇒ 结果不可信'))
    else:
        files = sorted(glob.glob('entry/src/main/ets/games/*.ets'))
        print('  扫 %d 款游戏的 autoStep（判据 1050：按**缩进层级**判「无条件」）' % len(files))
        print('=' * 78)
        sus_list = []
        nofun = 0
        for f in files:
            try: src = io.open(f, encoding='utf-8').read()
            except Exception: continue
            r = analyze(src)
            if r is None:
                nofun += 1; continue
            sus, why, hits = r
            if sus:
                sus_list.append((os.path.basename(f), hits))
        print('  无 autoStep 的: %d 款' % nofun)
        print('  🚨 **可疑（顶层无条件调时序动作）: %d 款**' % len(sus_list))
        print()
        for name, hits in sus_list:
            print('  📄 %-30s %s' % (name, ', '.join('L%d this.%s()' % (l, c) for l, c in hits)))
        print()
        print('=' * 78)
        if not sus_list:
            print('  ✅ 未发现同类 bug')
