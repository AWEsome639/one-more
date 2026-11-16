// GameLog.autoLevel 的算法单测（与 GameLog.ets 逐行对应）
let pass=0, fail=0;
const chk=(n,c,e)=>{ if(c){pass++;console.log('  ✅ '+n);} else {fail++;console.log('  🔴 '+n+'  '+(e||''));} };

// 复刻：最近 3 条该游戏记录
function autoLevel(mem, gameId) {
  let n=0, wins=0;
  for (let i=mem.length-1; i>=0 && n<3; i--) {
    const r=mem[i];
    if (r.g!==gameId) continue;
    n++;
    if (r.ok) wins++;
  }
  let lv=1;
  if (n>=3) {
    if (wins===3) lv=2;
    else if (wins===0) lv=0;
  }
  return lv;
}
const rec=(g,ok)=>({g,ok});

// ① 无记录 → 普通
chk('① 无记录 ⇒ 普通(1)', autoLevel([], 'gA')===1, autoLevel([],'gA'));

// ② 只有 2 局（样本不足）→ 普通
chk('② 只有 2 局 ⇒ 普通(1)', autoLevel([rec('gA',true),rec('gA',true)], 'gA')===1);

// ③ 连赢 3 局 → 困难
chk('③ 连赢 3 局 ⇒ 困难(2)', autoLevel([rec('gA',true),rec('gA',true),rec('gA',true)], 'gA')===2);

// ④ 连输 3 局 → 简单
chk('④ 连输 3 局 ⇒ 简单(0)', autoLevel([rec('gA',false),rec('gA',false),rec('gA',false)], 'gA')===0);

// ⑤ 两赢一输 → 普通（死区，不许抖）
chk('⑤ 两赢一输 ⇒ 普通(1)', autoLevel([rec('gA',true),rec('gA',true),rec('gA',false)], 'gA')===1);

// ⑥ 只看最近 3 局：4 连败后 3 连胜 → 困难
chk('⑥ 早期连败不影响（只看最近 3 局）',
  autoLevel([rec('gA',false),rec('gA',false),rec('gA',false),rec('gA',false),
             rec('gA',true),rec('gA',true),rec('gA',true)], 'gA')===2);

// ⑦ 别的游戏的记录不干扰
chk('⑦ 别的游戏记录不干扰',
  autoLevel([rec('gB',false),rec('gB',false),rec('gB',false),
             rec('gA',true),rec('gA',true),rec('gA',true)], 'gA')===2);

// ⑧ 交错：最近 3 条 gA 全胜，中间夹着 gB
chk('⑧ 交错记录只数自己的',
  autoLevel([rec('gA',true),rec('gB',false),rec('gA',true),rec('gB',false),
             rec('gA',true),rec('gB',false)], 'gA')===2);

// ⑨ 全胜 4 局 → 仍是困难（不越界）
chk('⑨ 全胜 4 局 ⇒ 困难(2)，不越界',
  autoLevel([rec('gA',true),rec('gA',true),rec('gA',true),rec('gA',true)], 'gA')===2);

// ⑩ 难度只在 0/1/2 之间
{
  let ok=true;
  for (const seq of [[true,true,true],[false,false,false],[true,false,true]]) {
    const lv=autoLevel(seq.map(o=>rec('gA',o)),'gA');
    if (lv<0||lv>2) ok=false;
  }
  chk('⑩ 结果永远在 0/1/2', ok);
}

console.log('\n  ── 自动难度单测：'+pass+' 通过 / '+fail+' 失败 ──\n');
process.exit(fail===0?0:1);
