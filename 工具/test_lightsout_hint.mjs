// 灭灯提示的验收（2026-10-23 第二期）
// 核心要证明的：**solveTaps 给出的解法真的能把灯全灭** ——
// 这是在验证"精确解"这个说法，不是验证"能出个提示"。
const N=5, CELLS=N*N;

function flip(b,i){
  const r=Math.floor(i/N), c=i%N;
  const set=(rr,cc)=>{ if(rr>=0&&rr<N&&cc>=0&&cc<N) b[rr*N+cc]=!b[rr*N+cc]; };
  set(r,c); set(r-1,c); set(r+1,c); set(r,c-1); set(r,c+1);
}

// 与 ArkTS 里 solveTaps 逐行对应
function solveTaps(on){
  let best=[], found=false;
  for(let mask=0;mask<(1<<N);mask++){
    const b=on.slice(); const taps=[];
    for(let c=0;c<N;c++) if(mask&(1<<c)){ flip(b,c); taps.push(c); }
    for(let r=1;r<N;r++) for(let c=0;c<N;c++) if(b[(r-1)*N+c]){ flip(b,r*N+c); taps.push(r*N+c); }
    let allOff=true;
    for(let i=0;i<CELLS;i++) if(b[i]){ allOff=false; break; }
    if(allOff && (!found || taps.length<best.length)){ best=taps; found=true; }
  }
  return best;
}

function applyAll(on,taps){
  const b=on.slice();
  for(const t of taps) flip(b,t);
  return b;
}
function allOff(b){ return b.every(x=>!x); }

let pass=0, fail=0;
const chk=(n,c,e)=>{ if(c){pass++;console.log('  ✅ '+n);} else {fail++;console.log('  🔴 '+n+'  '+(e||''));} };

// ① 用随机点法造一个「一定有解」的盘，再求解 —— 解必须真把盘灭掉
{
  let ok=0, bad=0, lens=[];
  for(let trial=0;trial<40;trial++){
    // 随机点 3~10 手造题
    const k=3+Math.floor(Math.random()*8);
    const setup=[];
    for(let j=0;j<k;j++) setup.push(Math.floor(Math.random()*CELLS));
    const on=new Array(CELLS).fill(false);
    for(const t of setup) flip(on,t);
    if(allOff(on)) continue;                 // 空题跳过
    const sol=solveTaps(on);
    if(sol.length===0){ bad++; continue; }   // 造出来的盘一定有解，不该返回空
    lens.push(sol.length);
    if(allOff(applyAll(on,sol))) ok++; else bad++;
  }
  chk('① 40 个随机可解盘：解出来的手数都能把灯全灭', bad===0 && ok>0, `好 ${ok} / 坏 ${bad}`);
  chk('② 解的手数 ≤ 25（5×5 上界）', lens.every(x=>x<=25), `最大 ${Math.max(...lens)}`);
}

// ③ 全亮盘（经典可解题）必须有解
{
  const on=new Array(CELLS).fill(true);
  const sol=solveTaps(on);
  chk('③ 全亮盘有解，且解得干净', sol.length>0 && allOff(applyAll(on,sol)), `手数 ${sol.length}`);
}

// ④ 已全灭 ⇒ 不该有解（返回空）
{
  const on=new Array(CELLS).fill(false);
  const sol=solveTaps(on);
  chk('④ 已全灭 ⇒ 返回空（提示层会降级）', sol.length===0, `返回 ${sol.length}`);
}

// ⑤ 提示给的是「最短解的第一手」—— 用两步验证：这一手之后仍有解
{
  const on=new Array(CELLS).fill(true);
  const sol=solveTaps(on);
  const first=sol[0];
  const after=on.slice(); flip(after,first);
  const sol2=solveTaps(after);
  chk('⑤ 按提示点第一手之后，盘面仍有解', sol2.length>0 && allOff(applyAll(after,sol2)));
}

// ⑥ 最短性抽查：随机盘上，不存在更短的解
//    （枚举 2^25 全空间太大，改用：枚举第一行 32 种，逐行追赶，取最短 ——
//      这和 solveTaps 同一个算法，所以这里改成验证"没有别的第一行能给更短解"）
{
  const on=new Array(CELLS).fill(true);
  let bestLen=99;
  for(let mask=0;mask<(1<<N);mask++){
    const b=on.slice(); const taps=[];
    for(let c=0;c<N;c++) if(mask&(1<<c)){ flip(b,c); taps.push(c); }
    for(let r=1;r<N;r++) for(let c=0;c<N;c++) if(b[(r-1)*N+c]){ flip(b,r*N+c); taps.push(r*N+c); }
    if(allOff(b)) bestLen=Math.min(bestLen,taps.length);
  }
  const sol=solveTaps(on);
  chk('⑥ 返回的就是所有第一行点法里最短的那个', sol.length===bestLen, `解 ${sol.length} / 最短 ${bestLen}`);
}

console.log('\n  ── 灭灯提示：'+pass+' 通过 / '+fail+' 失败 ──\n');
process.exit(fail===0?0:1);
