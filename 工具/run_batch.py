#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""永不静默的跑批器：逐款调用测量脚本，每款必落一行，末尾必打 DONE。

背景（2026-11-10）：临时跑批脚本跑到 56/68、58/68 就无声结束 —— 根因是
`subprocess.run(timeout=)` 的「假超时」：超时后内部 communicate() 仍等管道 EOF，
主进程就这样卡/死，且没人写收尾行。

本脚本的硬约束：
  1. 每款用 `Popen(..., start_new_session=True)` 起独立进程组；
     超时后 `os.killpg(os.getpgid(pid), SIGKILL)` **杀掉整棵子进程树**，
     再 `communicate(timeout=5)` 收尸（拿不到也不阻塞）。
  2. 每款**必打一行** JSON 到 jsonl 与 stdout（start/result 都有），
     任何一条路径（正常/超时/异常/找不到卡片）都不会静默。
  3. 末尾**必打** `DONE n/N`；返回值 = 失败数（timeout/error/no_card 都算失败），
     外层可据此判断「跑批真的跑完了，且结果可判」。

用法
----
    python3 工具/run_batch.py 名单.txt
    python3 工具/run_batch.py 名单.txt --timeout 150
    python3 工具/run_batch.py 名单.txt --cmd 'python3 工具/shot_game.py {game}'
    python3 工具/run_batch.py 名单.txt --out _巡检记录/自定义.jsonl --dry-run

名单文件：每行一个游戏名（中文名或 enName 都行；`#` 开头与空行忽略）。
默认命令：`python3 工具/shot_game.py {game}`（{game} 会被替换成 enName）。

输出
----
    _巡检记录/layout-batch-<YYYYmmdd-HHMMSS>.jsonl
    每行一个 JSON：
      {"event":"start","i":3,"total":68,"game":"数独","en":"Sudoku",...}
      {"event":"result","i":3,"total":68,"game":"数独","en":"Sudoku",
       "outcome":"ok|timeout|error|no_card","max_bottom":1420,"lowest":"...",
       "elapsed_s":23.4,"returncode":0,"tail":"..."}
      {"event":"done","processed":68,"total":68,"failures":2,...}

判定「跑批真的跑完了」：stdout/jsonl 末尾出现 `DONE n/N` 且 n == N
（进程被杀时不会有 DONE；此时 jsonl 里最后一个 event 就是停在哪款）。
"""
from __future__ import annotations

import argparse
import datetime
import io
import json
import os
import re
import shlex
import signal
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_OUT_DIR = os.path.join(ROOT, '_巡检记录')
DEFAULT_CMD = 'python3 工具/shot_game.py {game}'


# --------------------------------------------------------------------------- #
# 中文名 → enName（复用 GameRegistry；找不到就原样传，至少不会卡住）
# --------------------------------------------------------------------------- #
def registry_map() -> dict:
    """返回 {'zh': {中文名: enName}, 'en': set(enName)}。"""
    p = os.path.join(ROOT, 'entry/src/main/ets/core/GameRegistry.ets')
    zh = {}
    en = set()
    try:
        s = io.open(p, encoding='utf-8').read()
    except Exception:
        return {'zh': zh, 'en': en}
    # 每条记录形如 { id: 'sudoku', name: '数独', ... enName: 'Sudoku', ... }
    for m in re.finditer(
            r"id:\s*'([^']+)'.*?name:\s*'([^']+)'.*?enName:\s*'([^']+)'", s, re.S):
        _id, name, en_name = m.group(1), m.group(2), m.group(3)
        zh[name.strip()] = en_name.strip()
        en.add(en_name.strip())
    return {'zh': zh, 'en': en}


def resolve_en(game: str, reg: dict) -> str:
    """优先按中文名映射；否则原样返回（enName 或未知名都交给测量脚本自己判）。"""
    return reg['zh'].get(game.strip(), game.strip())


# --------------------------------------------------------------------------- #
# 单款执行
# --------------------------------------------------------------------------- #
# ★ 2026-11-11：`shot_game.py` 加固后输出改成「制表符四列」：
#   `名字	OK	1351	47.6s lowest='…' -> /path @2026-11-11T01:22:31`
#   ⇒ 两种格式都要认（判据 1901：包/工具版本对不上时先修解析，别怀疑被测对象）
LINE_RE = re.compile(r"max_bottom=(\d+)\s+lowest=(.+?)\s+->\s+(\S+)")
TAB_RE = re.compile(r"^\S.*?\t(OK|OK_NOSHOT|NOT_HOME|NO_CARD|TIMEOUT|CRASH)\t(\d+|-)\t([\d.]+)s", re.M)


def parse_measure(stdout: str):
    """从 shot_game 输出里取 (max_bottom, lowest, out_path)；取最后一条。"""
    mb, lo, out = None, None, None
    # ① 加固后的制表符格式（优先）
    last = None
    for m in TAB_RE.finditer(stdout or ''):
        last = m
    if last is not None:
        return (int(last.group(2)) if last.group(2) != '-' else None), None, None
    # ② 旧格式兜底
    for m in LINE_RE.finditer(stdout or ''):
        mb = int(m.group(1))
        lo = m.group(2).strip()
        out = m.group(3)
    return mb, lo, out


def classify(stdout: str, mb) -> str:
    s = stdout or ''
    if 'NO_CARD' in s:
        return 'no_card'
    if mb is not None:
        return 'ok'
    if any(k in s for k in ('NOT_HOME', 'WRONG_GAME', 'DUMP_FAIL')):
        return 'error'
    return 'error'


def run_one(game: str, en: str, cmd_template: str, timeout_s: float):
    """跑一款；返回 (outcome, max_bottom, lowest, elapsed_s, rc, tail)。永不抛异常。"""
    cmd = cmd_template.replace('{game}', en).replace('{game_zh}', game)
    argv = shlex.split(cmd)
    t0 = time.time()
    proc = None
    timed_out = False
    out_text = ''
    rc = None
    try:
        proc = subprocess.Popen(
            argv,
            cwd=ROOT,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            start_new_session=True,          # ★ 独立进程组，超时可整棵杀
            text=True,
        )
        try:
            out_text, _ = proc.communicate(timeout=timeout_s)
            rc = proc.returncode
        except subprocess.TimeoutExpired:
            timed_out = True
            # ★ 真超时：先杀进程组（含 hdc / python 子进程），再收尸
            try:
                os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
            except Exception:
                try:
                    proc.kill()
                except Exception:
                    pass
            try:
                out_text, _ = proc.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                out_text = (out_text or '')  # 收不到就用手上已有的
            rc = proc.returncode
    except Exception as e:                    # 起进程就失败
        out_text = f'{out_text or ""}\n[run_batch] spawn failed: {e!r}'
        rc = rc if rc is not None else -1
    finally:
        if proc is not None and proc.poll() is None:
            try:
                os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
            except Exception:
                pass

    elapsed = round(time.time() - t0, 1)
    mb, lo, _out = parse_measure(out_text)
    outcome = 'timeout' if timed_out else classify(out_text, mb)
    tail = (out_text or '').strip().splitlines()
    tail = tail[-1][:300] if tail else ''
    return outcome, mb, lo, elapsed, rc, tail


# --------------------------------------------------------------------------- #
# 主流程
# --------------------------------------------------------------------------- #
def read_names(path: str):
    names = []
    with io.open(path, encoding='utf-8') as f:
        for line in f:
            s = line.strip()
            if not s or s.startswith('#'):
                continue
            names.append(s)
    return names


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(
        description='永不静默的跑批器：逐款测量，每款必落一行，末尾必打 DONE n/N。')
    ap.add_argument('names_file', help='游戏名列表文件（每行一个；# 开头与空行忽略）')
    ap.add_argument('--timeout', type=float, default=150.0,
                    help='单款超时秒数（默认 150；超时杀整个进程组）')
    ap.add_argument('--cmd', default=DEFAULT_CMD,
                    help='测量命令模板（{game}=enName, {game_zh}=原名）；默认 python3 工具/shot_game.py {game}')
    ap.add_argument('--out', default=None,
                    help='jsonl 输出路径（默认 _巡检记录/layout-batch-<时间戳>.jsonl）')
    ap.add_argument('--out-dir', default=None, help='jsonl 输出目录（覆盖 --out 的默认目录）')
    ap.add_argument('--dry-run', action='store_true',
                    help='只解析名单并打印计划，不执行任何子进程')
    args = ap.parse_args(argv)

    names = read_names(args.names_file)
    total = len(names)
    if total == 0:
        print('names file is empty')
        return 1

    out_dir = args.out_dir or DEFAULT_OUT_DIR
    os.makedirs(out_dir, exist_ok=True)
    out_path = args.out or os.path.join(
        out_dir, 'layout-batch-%s.jsonl' % time.strftime('%Y%m%d-%H%M%S'))
    reg = registry_map()

    print('batch: %d 款 | timeout=%.0fs | out=%s' % (total, args.timeout, out_path),
          flush=True)
    print('cmd: %s' % args.cmd, flush=True)

    if args.dry_run:
        for i, g in enumerate(names, 1):
            print('[%d/%d] %s -> %s' % (i, total, g, resolve_en(g, reg)), flush=True)
        print('DRY_RUN %d/%d (no subprocess started)' % (total, total), flush=True)
        print('DONE 0/%d' % total, flush=True)
        return 0

    jl = io.open(out_path, 'a', encoding='utf-8')
    started_at = datetime.datetime.now().strftime('%Y-%m-%dT%H:%M:%S')
    processed = 0
    failures = 0

    def emit(rec):
        line = json.dumps(rec, ensure_ascii=False)
        print(line, flush=True)
        jl.write(line + '\n')
        jl.flush()

    try:
        for i, game in enumerate(names, 1):
            en = resolve_en(game, reg)
            emit({'event': 'start', 'i': i, 'total': total, 'game': game, 'en': en,
                  'ts': datetime.datetime.now().strftime('%Y-%m-%dT%H:%M:%S')})
            outcome, mb, lo, elapsed, rc, tail = run_one(game, en, args.cmd, args.timeout)
            processed += 1
            if outcome != 'ok':
                failures += 1
            emit({'event': 'result', 'i': i, 'total': total, 'game': game, 'en': en,
                  'outcome': outcome, 'max_bottom': mb, 'lowest': lo,
                  'elapsed_s': elapsed, 'returncode': rc, 'tail': tail})
    except KeyboardInterrupt:
        print('INTERRUPTED at %d/%d (已写出的结果在 jsonl 里)' % (processed, total), flush=True)
        emit({'event': 'interrupted', 'processed': processed, 'total': total})
        return 130
    finally:
        summary = {'event': 'done', 'processed': processed, 'total': total,
                   'failures': failures, 'started_at': started_at,
                   'finished_at': datetime.datetime.now().strftime('%Y-%m-%dT%H:%M:%S'),
                   'out': out_path}
        try:
            emit(summary)
        except Exception:
            print(json.dumps(summary, ensure_ascii=False), flush=True)
        print('DONE %d/%d (failures=%d) -> %s' % (processed, total, failures, out_path), flush=True)
        jl.close()

    return failures


if __name__ == '__main__':
    sys.exit(main())
