// 跳棋 AI 的逻辑验收（2026-10-23 第二期）
// 目的：证明它不是在乱走 —— 至少要做到「能吃就吃」「不会自己走进必死」
const EMPTY=0, P_MAN=1, P_KING=2, A_MAN=3, A_KING=4;
const WIN=100000;

function genMoves(b,size,side,onlyFrom){
  const out=[]; const idx=(r,c)=>r*size+c;
  for(let i=0;i<b.length;i++){
    const v=b[i];
    const mine = side===1 ? (v===P_MAN||v===P_KING) : (v===A_MAN||v===A_KING);
    if(!mine||(onlyFrom>=0&&i!==onlyFrom)) continue;
    const r=Math.floor(i/size), c=i%size;
    const king = (side===1&&v===P_KING)||(side===3&&v===A_KING);
    const dirs = king?[-1,1]:(side===1?[-1]:[1]);
    for(const dr of dirs) for(const dc of [-1,1]){
      const tr=r+dr, tc=c+dc;
      if(tr<0||tr>=size||tc<0||tc>=size) continue;
      if(b[idx(tr,tc)]===EMPTY) out.push({from:i,to:idx(tr,tc),cap:-1});
      const lr=r+dr*2, lc=c+dc*2;
      if(lr<0||lr>=size||lc<0||lc>=size) continue;
      const mid=b[idx(tr,tc)];
      const opp = side===1 ? (mid===A_MAN||mid===A_KING) : (mid===P_MAN||mid===P_KING);
      if(opp&&b[idx(lr,lc)]===EMPTY) out.push({from:i,to:idx(lr,lc),cap:idx(tr,tc)});
    }
  }
  return out;
}
function afterMove(b,size,m,side){
  const n=b.slice(); let v=n[m.from]; n[m.from]=EMPTY;
  if(m.cap>=0) n[m.cap]=EMPTY;
  const r=Math.floor(m.to/size);
  if(v===P_MAN&&r===0) v=P_KING; else if(v===A_MAN&&r===size-1) v=A_KING;
  n[m.to]=v; return n;
}
function evalBoard(b,size){
  let s=0;
  for(let i=0;i<b.length;i++){
    const v=b[i]; if(v===EMPTY) continue;
    const r=Math.floor(i/size), c=i%size;
    const cen=(0.5-Math.abs(c-(size-1)/2)/size)*0.4;
    if(v===A_MAN) s+=1.0+(size-1-r)/size*0.35+cen;
    else if(v===A_KING) s+=2.5+cen;
    else if(v===P_MAN) s-=1.0+r/size*0.35+cen;
    else if(v===P_KING) s-=2.5+cen;
  }
  return s;
}
function search(b,size,side,depth,alpha0,beta0,budget){
  budget[0]--; if(budget[0]<=0) return evalBoard(b,size);
  const ms=genMoves(b,size,side,-1);
  if(ms.length===0) return side===3?-WIN:WIN;
  if(depth<=0) return evalBoard(b,size);
  let alpha=alpha0, beta=beta0;
  if(side===3){
    let best=-WIN*2;
    for(const m of ms){
      const sc=search(afterMove(b,size,m,side),size,1,depth-1,alpha,beta,budget);
      if(sc>best) best=sc;
      if(best>alpha) alpha=best;
      if(alpha>=beta) break;
    }
    return best;
  }
  let best2=WIN*2;
  for(const m of ms){
    const sc=search(afterMove(b,size,m,side),size,3,depth-1,alpha,beta,budget);
    if(sc<best2) best2=sc;
    if(best2<beta) beta=best2;
    if(alpha>=beta) break;
  }
  return best2;
}
function aiBest(board,size,level,onlyFrom){
  const ms=genMoves(board,size,3,onlyFrom);
  if(ms.length===0) return null;
  if(ms.length===1) return ms[0];
  const depth=level<=0?1:(level>=2?6:4);
  const budget=[level>=2?120000:30000];
  let best=ms[0], bestSc=-WIN*2;
  for(const m of ms){
    const sc=search(afterMove(board,size,m,3),size,1,depth-1,-WIN*2,WIN*2,budget);
    if(sc>bestSc){ bestSc=sc; best=m; }
    if(budget[0]<=0) break;
  }
  return best;
}

let pass=0, fail=0;
const chk=(n,c,e)=>{ if(c){pass++;console.log('  ✅ '+n);} else {fail++;console.log('  🔴 '+n+'  '+(e||''));} };
const SIZE=6;
function mk(){ return new Array(36).fill(EMPTY); }

// ① 能吃就必须吃
//   ⚠️ 第一次写错了：跳棋里 side=3（电脑）的兵是**往下走**（r 增大），
//      我把玩家子摆在电脑的上方，当然吃不到 —— 是测试错，不是代码错
{
  const b=mk();
  b[2*6+2]=A_MAN;     // 电脑的兵（往下走）
  b[3*6+3]=P_MAN;     // 玩家的兵，正在电脑的右下
  const m=aiBest(b,SIZE,2,-1);
  chk('① 白送子 ⇒ 必须吃', m!==null && m.cap>=0, JSON.stringify(m));
}

// ② 不吃子也能走出合法步
{
  const b=mk();
  b[4*6+2]=A_MAN; b[0*6+1]=P_MAN;
  const m=aiBest(b,SIZE,2,-1);
  const legal = m!==null && genMoves(b,SIZE,3,-1).some(x=>x.from===m.from&&x.to===m.to);
  chk('② 出招必须是合法走法', legal, JSON.stringify(m));
}

// ③ 能吃光对手时直接吃（同样修正方向）
{
  const b=mk();
  b[2*6+2]=A_MAN;
  b[3*6+3]=P_MAN;      // 唯一玩家子
  const m=aiBest(b,SIZE,2,-1);
  const eats = m!==null && m.cap===3*6+3;
  chk('③ 能吃光对手时直接吃', eats, JSON.stringify(m));
}

// ④ 三个难度都要能出招
{
  let ok=true;
  for(const lv of [0,1,2]){
    const b=mk(); b[3*6+3]=A_MAN; b[2*6+2]=P_MAN;
    const m=aiBest(b,SIZE,lv,-1);
    if(m===null) ok=false;
  }
  chk('④ 0/1/2 三档都能出招', ok);
}

// ⑤ 困难档不许太慢（≤ 3 秒）
{
  const b=mk();
  // 摆一个稍微丰满的盘
  for(const p of [2*6+1,2*6+3,2*6+5,3*6+2]) b[p]=A_MAN;
  for(const p of [4*6+2,5*6+1,5*6+3,4*6+4]) b[p]=P_MAN;
  const t0=Date.now();
  const m=aiBest(b,SIZE,2,-1);
  const ms=Date.now()-t0;
  chk('⑤ 困难档出招 ≤ 3000ms', m!==null && ms<=3000, ms+'ms');
}

// ⑥ 无路可走 ⇒ 返回 null
//   (5,0) 是最后一行的最左角：往下越界、往左下越界 ⇒ 真的没有走法
{
  const b=mk();
  b[5*6+0]=A_MAN;
  const m=aiBest(b,SIZE,2,-1);
  chk('⑥ 无路可走 ⇒ null', m===null, JSON.stringify(m));
}

console.log('\n  ── 跳棋 AI：'+pass+' 通过 / '+fail+' 失败 ──\n');
process.exit(fail===0?0:1);
