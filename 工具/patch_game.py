"""给 One More 的游戏文件打补丁的公共工具。

★ 2026-10-27 建立，起因：我写过的临时补丁脚本把 HintBar 插在"第一个 Button 前"
  （= 页面底部），页面一长按钮就看不见 —— 这个默认值是错的，
  第 293 轮批量修了 81 款，第 297 轮我自己又犯一遍。
  ⇒ 所以把这些动作固化成函数，默认值一次写对。

用法：
    from patch_game import ensure_imports, add_auto_id, insert_hintbar_top, add_block_before
"""
import io
import re


def read(path):
    return io.open(path, encoding='utf-8').read()


def write(path, s):
    io.open(path, 'w', encoding='utf-8').write(s)


# ───────────────────────── 导入 ─────────────────────────
def ensure_imports(path):
    """补 Hint / HintResult / HintBar / TG2 的 import（缺哪个补哪个）。"""
    s = read(path)
    # Hint + HintResult
    if 'ai/Hint' not in s:
        lines = s.split('\n')
        for i, l in enumerate(lines):
            if 'core/GameI18n' in l:
                lines.insert(i + 1, "import { Hint, HintResult } from '../ai/Hint';")
                break
        s = '\n'.join(lines)
    elif 'HintResult' not in s.split('\n\n')[0] and "import { Hint, HintResult }" not in s:
        s = s.replace("import { Hint } from '../ai/Hint';",
                      "import { Hint, HintResult } from '../ai/Hint';", 1)
    # HintBar
    if 'components/HintBar' not in s:
        lines = s.split('\n')
        for i, l in enumerate(lines):
            if 'ai/Hint' in l:
                lines.insert(i + 1, "import { HintBar } from '../components/HintBar';")
                break
        s = '\n'.join(lines)
    # TG2 —— ★ 判据必须是「有没有被 import」，不是「有没有出现过」
    #   （只出现过但没 import ⇒ 编译报 Cannot find name 'TG2'）
    m = re.search(r"import \{([^}]*)\} from '\.\./core/GameI18n';", s)
    if m:
        names = [x.strip() for x in m.group(1).split(',') if x.strip()]
        need = []
        if 'TG2' in s and 'TG2' not in names:
            need.append('TG2')
        if need:
            names.extend(need)
            s = s.replace(m.group(0),
                          "import { %s } from '../core/GameI18n';" % ', '.join(names), 1)
    write(path, s)


# ───────────────────── “有没有 / 结束标记” ─────────────────────
def has(path, needle):
    return needle in read(path)


# ───────────────────────── 代打计时器字段 ─────────────────────────
def add_auto_id(path):
    """在第一个 @State 前插 autoId（必须 @State，否则按钮态不刷新）。"""
    s = read(path)
    if 'private autoId' in s:
        return
    lines = s.split('\n')
    for i, l in enumerate(lines):
        if l.strip().startswith('@State'):
            ind = l[:len(l) - len(l.lstrip())]
            lines.insert(i, ind + "/** 代打计时器（-1 = 未运行）。必须 @State */")
            lines.insert(i + 1, ind + "@State private autoId: number = -1;")
            break
    write(path, '\n'.join(lines))


# ───────────────────── ★ HintBar 永远插在根 Column 顶部 ─────────────────────
def _find_block(lines, start, maxlen=24):
    """从 start 行开始找花括号配平的块，返回结束行号。"""
    depth = 0
    for j in range(start, min(start + maxlen, len(lines))):
        depth += lines[j].count('{') - lines[j].count('}')
        if depth <= 0 and j > start:
            return j
    return None


def move_hintbar_to_top(path):
    """把已有的 HintBar 块移到根 Column 的第一个子元素（幂等）。"""
    lines = read(path).split('\n')
    start = None
    for i, l in enumerate(lines):
        if 'HintBar({' in l:
            start = i
            break
    if start is None:
        return False
    end = _find_block(lines, start)
    if end is None:
        return False
    indent = len(lines[start]) - len(lines[start].lstrip())
    root = None
    for i, l in enumerate(lines):
        m = re.match(r'^(\s*)Column\(', l)
        if m and len(m.group(1)) < indent:
            root = i
            break
    if root is None or root > start:
        return False
    block = lines[start:end + 1]
    want = ' ' * (len(lines[root]) - len(lines[root].lstrip()) + 2)
    cur = ' ' * indent
    block = [(want + ln[len(cur):]) if ln.startswith(cur) else ln for ln in block]
    del lines[start:end + 1]
    lines[root + 1:root + 1] = block
    write(path, '\n'.join(lines))
    return True


def insert_hintbar_top(path, show_hint=True, hint_handler='askHint', auto_handler='askAuto'):
    """插入 HintBar 到根 Column 的第一个子元素。

    �� 默认值就是对的：**根 Column 第一子元素**，不是"第一个 Button 前"。
    """
    lines = read(path).split('\n')
    root = None
    for i, l in enumerate(lines):
        m = re.match(r'^(\s*)Column\(', l)
        if m:
            root = i
            break
    if root is None:
        return False
    ind = ' ' * (len(lines[root]) - len(lines[root].lstrip()) + 2)
    block = [ind + 'HintBar({']
    if show_hint:
        block.append(ind + '  showHint: true,')
        block.append(ind + '  onHintTap: () => { this.' + hint_handler + '(); },')
    else:
        block.append(ind + '  showHint: false,')
    block.append(ind + '  onAutoTap: () => { this.' + auto_handler + '(); },')
    block.append(ind + '  autoOn: this.autoId >= 0')
    block.append(ind + '})')
    lines[root + 1:root + 1] = block
    write(path, '\n'.join(lines))
    return True


# ───────────────────────── 插入方法块 ─────────────────────────
def add_block_before(path, anchor_regex, block_lines):
    """在匹配 anchor_regex 的那一行之前插入 block（按行插，不按字符位置拼）。"""
    lines = read(path).split('\n')
    for i, l in enumerate(lines):
        if re.search(anchor_regex, l):
            lines[i:i] = block_lines
            write(path, '\n'.join(lines))
            return True
    return False


ASK_AUTO_BLOCK = [
    '  private askAuto(): void {',
    '    Haptics.tap();',
    '    if (this.autoId >= 0) {',
    '      this.stopAuto();',
    "      Hint.toast(TG('已停止代打'));",
    '      return;',
    '    }',
    "    Hint.toast(TG('AI 开始代打…'));",
    '    this.autoId = Hint.autoRun(() => this.autoStep());',
    '  }',
    '',
    '  private stopAuto(): void {',
    '    if (this.autoId >= 0) {',
    '      Hint.autoStop(this.autoId);',
    '      this.autoId = -1;',
    '    }',
    '  }',
    '',
]

ASK_HINT_BLOCK = [
    '  private askHint(): void {',
    '    Haptics.tap();',
    '    const r: HintResult = this.computeHint();',
    "    Hint.toastResult(r, TG('这一步看不出答案'));",
    '  }',
    '',
]

# ───────────── ★ 按"块边界"操作（2026-10-27 建立）─────────────
# 起因：我两次批量补丁失败，都是因为按"两个关键字之间"截取代码，
#      结果把夹在中间的 autoStep / askAuto 一起删了。
# ⇒ 正确做法：先用花括号配平找到块的起止行，只动那几行。

def find_block(lines, header_re, maxlen=200):
    """找到函数/组的起止行号（按花括号配平）。返回 (start, end) 或 None。"""
    start = None
    for i, l in enumerate(lines):
        if re.search(header_re, l) and '{' in l:
            start = i
            break
    if start is None:
        return None
    depth = 0
    for j in range(start, min(start + maxlen, len(lines))):
        depth += lines[j].count('{') - lines[j].count('}')
        if depth <= 0 and j > start:
            return (start, j)
    return None


def replace_block(path, header_re, new_lines):
    """替换一个函数块（按块边界，不碰块外的东西）。"""
    lines = read(path).split('\n')
    rng = find_block(lines, header_re)
    if not rng:
        return False
    st, en = rng
    lines[st:en + 1] = new_lines
    write(path, '\n'.join(lines))
    return True


def delete_block(path, header_re):
    """删除一个函数块（按块边界）。"""
    lines = read(path).split('\n')
    rng = find_block(lines, header_re)
    if not rng:
        return False
    st, en = rng
    del lines[st:en + 1]
    write(path, '\n'.join(lines))
    return True


def has_fn(path, header_re):
    """文件里有没有这个函数（按块边界确认，不误判注释）。"""
    return find_block(read(path).split('\n'), header_re) is not None


# ───────────── ★ 整款接入（2026-10-28 建立）─────────────
# 起因：写斯特鲁普时发现"每个游戏都手写一遍 insert_hintbar_top + 三个方法"太慢。
# ⇒ 做成一个函数：给"落子函数名 + 答案表达式 + 守卫 + 提示代码"，一次接完。

def add_ai_features(base, answer_fn, answer_expr, guard_expr, hint_lines,
                    also_import=True):
    """给一款游戏加代打 + 提示 + HintBar。

    base         文件名（不含 .ets），如 'GStroopTest'
    answer_fn    落子函数名，如 'answer'
    answer_expr  答案表达式，如 'this.ink'
    guard_expr   守卫（真了就等），如 'this.pick >= 0'
    hint_lines   提示函数体的行列表（不含 wrap，函数头尾自动加）
    """
    import re as _re
    path = base if base.endswith('.ets') else base + '.ets'
    if not path.startswith(('entry/', '/')):
        path = 'entry/src/main/ets/games/' + path
    s = read(path)
    if 'private autoStep' in s:
        return False, 'already has autoStep'
    # imports
    lines = s.split('\n')
    # ★ 判据必须是「有没有 HintResult」，不是「有没有 ai/Hint」
    #   （有的文件已 import { Hint } 但缺 HintResult ⇒ 编译报 Cannot find name）
    if "import { Hint, HintResult }" not in s:
        for i, l in enumerate(lines):
            if l.startswith('import '):
                lines.insert(i, "import { Hint, HintResult } from '../ai/Hint';")
                break
    if 'components/HintBar' not in s:
        for i, l in enumerate(lines):
            if "from '../ai/Hint'" in l:
                lines.insert(i + 1, "import { HintBar } from '../components/HintBar';")
                break
    s = '\n'.join(lines)
    m = _re.search(r"import \{([^}]*)\} from '\.\./core/GameI18n';", s)
    if m:
        names = [x.strip() for x in m.group(1).split(',') if x.strip()]
        if 'TG2' not in names:
            names.append('TG2')
            s = s.replace(m.group(0), "import { %s } from '../core/GameI18n';" % ', '.join(names), 1)
    # autoId
    lines = s.split('\n')
    if 'private autoId' not in s:
        for i, l in enumerate(lines):
            if l.strip().startswith('@State'):
                ind = l[:len(l) - len(l.lstrip())]
                lines.insert(i, ind + "/** 代打计时器（-1 = 未运行）。必须 @State */")
                lines.insert(i + 1, ind + "@State private autoId: number = -1;")
                break
    s = '\n'.join(lines)
    # 方法块
    block = ['  // ═══════════ AI 代打（2026-10-24 第三期）═══════════',
             '  private autoStep(): boolean {',
             '    if (this.over) {', '      return false;', '    }',
             '    if (' + guard_expr + ') {', '      return true;', '    }',
             '    this.' + answer_fn + '(' + answer_expr + ');',
             '    return !this.over;', '  }', '']
    block += list(hint_lines)
    block += ASK_AUTO_BLOCK + ASK_HINT_BLOCK
    lines = s.split('\n')
    ins = None
    for i, l in enumerate(lines):
        if _re.search(r'  private ' + answer_fn + r'\(', l):
            ins = i
            break
    if ins is None:
        return False, 'no answer fn found'
    lines[ins:ins] = block
    s = '\n'.join(lines)
    # HintBar 到根 Column 顶部
    lines = s.split('\n')
    root = None
    for i, l in enumerate(lines):
        if _re.match(r'^(\s*)Column\(', l):
            root = i
            break
    if root is None:
        return False, 'no root Column'
    ind = ' ' * (len(lines[root]) - len(lines[root].lstrip()) + 2)
    lines[root + 1:root + 1] = [ind + 'HintBar({', ind + '  showHint: true,',
        ind + '  onHintTap: () => { this.askHint(); },',
        ind + '  onAutoTap: () => { this.askAuto(); },',
        ind + '  autoOn: this.autoId >= 0', ind + '})']
    s = '\n'.join(lines)
    write(path, s)
    return True, 'ok'


# ───────────── ★ 演示动画（项目 C，2026-10-28）─────────────
# 核心：演示 = 代打跑一遍。演完立即 reset()，成绩天然不会被污染。
# 前提（实测 169/169 都满足）：有 autoStep + reset() + aboutToAppear()

DEMO_METHODS = [
    '  // ═══════════ 演示动画（项目 C）═══════════',
    '  // 沙盒规则：跑 Hint.DEMO_STEPS 步或一旦 over 就立刻停，然后 reset()',
    '  //   ⇒ 演完就是干净开局，成绩/记录不可能被污染',
    '  private demoStep(): boolean {',
    '    if (this.demoId < 0) { return false; }',
    '    if (this.demoLeft <= 0) { this.demoStop(); return false; }',
    '    this.demoLeft = this.demoLeft - 1;',
    '    this.autoStep();',
    '    return true;',
    '  }', '',
    '  private demoStop(): void {',
    '    if (this.demoId >= 0) {',
    '      Hint.autoStop(this.demoId);',
    '      this.demoId = -1;',
    '    }',
    '    const wasOn: boolean = this.demoLeft > 0;',
    '    this.demoLeft = 0;',
    '    if (wasOn) { this.RESETNAME(); }',
    '  }', '',
    '  private demoStart(): void {',
    '    if (this.demoId >= 0) { return; }',
    '    this.demoLeft = Hint.DEMO_STEPS;',
    '    this.demoId = Hint.demoRun(() => this.demoStep());',
    '  }', '',
]

DEMO_STATE = [
    '  /** 演示动画（项目 C）：-1 = 未运行 */',
    '  @State private demoId: number = -1;',
    '  @State private demoLeft: number = 0;',
]


def add_demo(base):
    """给一款已有 autoStep 的游戏接演示动画。返回 (ok, msg)。"""
    import re as _re
    path = base if base.endswith('.ets') else base + '.ets'
    if not path.startswith(('entry/', '/')):
        path = 'entry/src/main/ets/games/' + path
    s = read(path)
    if 'demoId' in s:
        return False, 'already has demo'
    if 'private autoStep' not in s:
        return False, 'no autoStep'
    # ★ 2026-10-29：reset() 不是唯一的名字 —— 有的用 newGame()
    _reset_name = None
    for _cand in ('reset', 'newGame', 'restart', 'newGameRound'):
        if _re.search(r'private ' + _cand + r'\(', s):
            _reset_name = _cand
            break
    if _reset_name is None:
        return False, 'no reset/newGame()'
    if not _re.search(r'aboutToAppear\(\)', s):
        return False, 'no aboutToAppear()'

    # ① 状态字段（跟在 autoId 后面）
    if 'private autoId' in s:
        lines = s.split('\n')
        for i, l in enumerate(lines):
            if 'private autoId' in l:
                ind = l[:len(l) - len(l.lstrip())]
                lines[i + 1:i + 1] = [ind + x.strip() for x in DEMO_STATE]
                break
        s = '\n'.join(lines)
    else:
        return False, 'no autoId'

    # ② 演示方法（插在 autoStep 前）
    _m_as = _re.search(r'\n([ \t]*)private autoStep', s)
    if not _m_as:
        return False, 'autoStep not found'
    i = _m_as.start() + 1
    _dm = [x.replace('RESETNAME', _reset_name) for x in DEMO_METHODS]
    s = s[:i] + '\n'.join(_dm) + '\n' + s[i:]

    # ③ aboutToAppear 里挂 3 秒后开始
    m = _re.search(r'aboutToAppear\(\)\s*:\s*void\s*\{', s)
    if not m:
        return False, 'aboutToAppear body not found'
    # 找到它的花括号范围，在结束前插入
    lines = s.split('\n')
    start = None
    for i2, l in enumerate(lines):
        if _re.search(r'aboutToAppear\(\)\s*:\s*void\s*\{', l):
            start = i2
            break
    depth = 0
    end = None
    for j in range(start, min(start + 30, len(lines))):
        depth += lines[j].count('{') - lines[j].count('}')
        if depth <= 0:
            end = j
            break
    if end is None:
        return False, 'aboutToAppear body unclosed'
    # ★★★ 关键修（2026-10-28）：aboutToAppear 可能是**单行**函数
    #   `aboutToAppear(): void { ... this.reset(); }`
    #   此时 start == end，直接插在 end 前会**插到函数外面去** ⇒ 语法错
    #   ⇒ 单行就改写成多行，再插
    if end == start:
        one = lines[start]
        body = one[one.index('{') + 1: one.rindex('}')].strip()
        ind = one[:len(one) - len(one.lstrip())]
        lines[start:start + 1] = [
            ind + 'aboutToAppear(): void {',
            ind + '  ' + body,
        ] + [
            ind + '  // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）',
            ind + '  setTimeout(() => { this.demoStart(); }, 3000);',
            ind + '}',
        ]
    else:
        ind = lines[start][:len(lines[start]) - len(lines[start].lstrip())]
        lines[end:end] = [
            ind + '  // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）',
            ind + '  setTimeout(() => { this.demoStart(); }, 3000);',
        ]
    s = '\n'.join(lines)

    # ④ 根容器 .onTouch（找 build() 里最后一层容器的收尾）
    lines = s.split('\n')
    b = None
    for i3, l in enumerate(lines):
        # ★★★ 2026-10-29 修：build() 的缩进不一定是 2 空格
        #   （GBoxCompletion / GClassicMaze 等 5 款是别的缩进，之前全被跳过）
        if _re.match(r'^\s*build\(\)\s*\{', l):
            b = i3
            break
    if b is None:
        return False, 'no build()'
    # build() 的收尾：从 b 开始配平，取倒数第二行（最后一层容器）
    depth = 0
    bend = None
    for j in range(b, min(b + 900, len(lines))):
        depth += lines[j].count('{') - lines[j].count('}')
        if depth <= 0 and j > b:
            bend = j
            break
    if bend is None:
        return False, 'build() unclosed'
    # 在 bend 之前找最后一层容器的收尾行（以 } 开头且带修饰符）
    root_end = None
    for j in range(bend - 1, b, -1):
        t = lines[j].strip()
        if t.startswith('}') and ('.' in t or t == '}'):
            root_end = j
            break
    if root_end is None:
        return False, 'root container end not found'
    old = lines[root_end]
    idx = old.find('}')
    new = (old[:idx + 1] + '\n    .onTouch((e: TouchEvent) => {\n'
           '      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）\n'
           '      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }\n'
           '    })' + old[idx + 1:])
    lines[root_end] = new
    s = '\n'.join(lines)

    write(path, s)
    return True, 'ok'
