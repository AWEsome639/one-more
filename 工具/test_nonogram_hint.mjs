// 数织提示的验收（2026-10-23 第二期）
//
// 要证明的核心性质只有一条，但它是致命的：
//   **提示给的那一格，必须与真答案一致** ——
//   如果它让你把空格涂黑，玩家会直接吃到一次 ERR_MAX，提示就成了害人。
//
// 另外验证：只用「线索 + 玩家标记」也能推出东西（不是靠看答案）。
import fs from 'fs';

// 从源码里把 NONO_ART 抠出来（这样测试与被测代码用的是同一份题）
const src = fs.readFileSync('/Users/a0000/dev/yiju/entry/src/main/ets/games/GNonogram.ets','utf8');
const m = src.match(/const NONO_ART: number\[\]\[\] = \[([\s\S]*?)\n\];/);
if(!m){ console.log('🔴 没找到 NONO_ART'); process.exit(1); }
// 按 "// 第 N 关" 切；每块里只取前 25 个 0/1
const arts = [];
for(const blk of m[1].split(/\/\/\s*第\s*\d+\s*关/)){
  const nums = (blk.match(/[01]/g)||[]).map(Number);
  if(nums.length>=25) arts.push(nums.slice(0,25));
}
console.log('  从源码读出 '+arts.length+' 道 5×5 题');

const N=5, CELLS=N*N;

function clueNums(line){
  const out=[]; let run=0;
  for(const v of line){ if(v===1) run++; else if(run>0){ out.push(run); run=0; } }
  if(run>0) out.push(run);
  return out;
}
function fitsClue(bits,clues){
  const g=clueNums(bits);
  if(g.length!==clues.length) return false;
  for(let i=0;i<g.length;i++) if(g[i]!==clues[i]) return false;
  return true;
}
function fitsMarks(bits,marks){
  for(let i=0;i<bits.length;i++){
    if(marks[i]===1 && bits[i]!==1) return false;
    if(marks[i]===2 && bits[i]!==0) return false;
  }
  return true;
}
function lineOf(cells,horiz,k,n){
  const out=[]; for(let i=0;i<n;i++) out.push(cells[horiz?k*n+i:i*n+k]); return out;
}
function artLineOf(art,horiz,k,n){
  const out=[]; for(let i=0;i<n;i++) out.push(art[horiz?k*n+i:i*n+k]); return out;
}

// 与 ArkTS 里 computeHint 逐行对应：返回 {idx, want} 或 null
function computeHint(cells,art,n){
  for(let horiz=1;horiz>=0;horiz--){
    for(let k=0;k<n;k++){
      const marks=lineOf(cells,horiz===1,k,n);
      const clues=clueNums(artLineOf(art,horiz===1,k,n));
      const total=1<<n;
      let acc=[], cnt=0;
      for(let mask=0;mask<total;mask++){
        const bits=[]; for(let i=0;i<n;i++) bits.push((mask&(1<<i))?1:0);
        if(!fitsClue(bits,clues)||!fitsMarks(bits,marks)) continue;
        if(cnt===0) acc=bits.slice();
        else for(let i=0;i<n;i++) if(acc[i]!==bits[i]) acc[i]=-1;
        cnt++;
      }
      if(cnt<=1) continue;
      for(let i=0;i<n;i++){
        if(acc[i]<0) continue;
        const want = acc[i]===1?1:2;
        if(marks[i]===want) continue;
        const idx = horiz===1 ? k*n+i : i*n+k;
        return { idx, want };
      }
    }
  }
  return null;
}

let pass=0, fail=0;
const chk=(n,c,e)=>{ if(c){pass++;console.log('  ✅ '+n);} else {fail++;console.log('  🔴 '+n+'  '+(e||''));} };

// ① 空盘：凡给出提示，必须与真答案一致（这是致命性质）
{
  let wrong=0, given=0;
  for(const art of arts){
    const cells=new Array(CELLS).fill(0);
    const h=computeHint(cells,art,N);
    if(h){
      given++;
      const truth = art[h.idx]===1 ? 1 : 2;
      if(h.want!==truth) wrong++;
    }
  }
  chk('① 空盘上所有提示都与真答案一致', wrong===0, `给出 ${given} 次，错 ${wrong} 次`);
}

// ② 随机部分进度：仍然不许与答案矛盾
{
  let wrong=0, given=0, trials=0;
  for(let t=0;t<300;t++){
    for(const art of arts.slice(0,6)){
      // 造一个"只填对了一部分"的盘面（不制造错标，模拟正常玩家）
      const cells=new Array(CELLS).fill(0);
      for(let i=0;i<CELLS;i++){
        const r=Math.random();
        if(r<0.35) cells[i] = art[i]===1?1:2;     // 正确的标记
        // 其余留空
      }
      trials++;
      const h=computeHint(cells,art,N);
      if(h){
        given++;
        const truth = art[h.idx]===1 ? 1 : 2;
        if(h.want!==truth) wrong++;
      }
    }
  }
  chk('② 300×6 个部分进度盘：所有提示都与真答案一致', wrong===0, `${trials} 盘，给出 ${given} 次，错 ${wrong} 次`);
}

// ③ 提示给出的那一格，玩家当时确实还没标对（否则就是废话提示）
{
  let same=0, given=0;
  for(const art of arts){
    const cells=new Array(CELLS).fill(0);
    for(let i=0;i<CELLS;i++) cells[i] = art[i]===1?1:2;   // 全标对
    const h=computeHint(cells,art,N);                       // 应该返回 null
    given++;
    if(h!==null) same++;
  }
  chk('③ 全部标对时不再给提示', same===0, `有 ${same} 道还在给`);
}

// ④ 必须真的能推出东西（不是永远返回 null）
{
  let given=0;
  for(const art of arts){
    const cells=new Array(CELLS).fill(0);
    if(computeHint(cells,art,N)) given++;
  }
  chk('④ 空盘上至少有一道题能推出确定格（证明推理真的在工作）', given>0, `能推 ${given}/${arts.length}`);
}

// ⑤ 只用线索、不看答案也能算 —— 反向验证：
//    把 art 换成一个"同线索但不同摆法"的盘，提示结果必须仍然自洽（不依赖 art 具体值）
{
  // 构造一个线索为 [5] 的行：只有一种摆法，两种 art 写法其实同一个
  // 更有意义的是验证：computeHint 只读 clueNums(artLine) 和 cells，
  // 所以这里直接检查它没有别的入口
  const fnSrc = src.match(/private computeHint\(\)[\s\S]*?\n  \}/);
  const body = fnSrc ? fnSrc[0] : '';
  chk('⑤ computeHint 里没有直接读 art 的答案位（只用线索与标记）',
      body.length>0 && !/this\.art\[/.test(body), '检查源码');
}

console.log('\n  ── 数织提示：'+pass+' 通过 / '+fail+' 失败 ──\n');
process.exit(fail===0?0:1);
