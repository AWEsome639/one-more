/**
 * 局域网联机 —— 同 Wi-Fi 下的双人对战
 *
 * ⚠️ 隐私口径的重要变更（2026-10-11）
 *   本模块是**整个应用唯一**需要网络的代码。在此之前「一局」没申请任何网络权限，
 *   隐私政策里也写着「连网络权限都没申请，飞行模式照样玩」。
 *   加入局域网联机后，那句话**必须改**，已同步更新为：
 *     「只有『局域网对战』这一个功能需要网络权限，而且是**只在同一个 Wi-Fi 内**通信；
 *       其余 353 款游戏、所有记录与统计，**依然完全离线、不上传任何数据**。」
 *   ⇒ 隐私政策的实质承诺（不采集、不上传、不出局域网）**没有改变**。
 *
 * 为什么不需要服务器：
 *   同一 Wi-Fi 下两台设备能互相广播/直连 ⇒ 用 UDP 广播做「发现」，
 *   用 TCP 做「对局消息」。零服务器、零成本、零备案。
 *
 * 协议（先做最小可用版）：
 *   UDP 41234  ← 广播 "YIJU/1 DISCOVER"                     （找房间）
 *   UDP 41234  → 房主回 "YIJU/1 HOST <port> <name>"          （应答，带上 TCP 端口）
 *   TCP <port> ⇄ 一行一条 JSON：{"t":"move","d":...}          （对局消息）
 *
 * 安全边界：
 *   · 只在**局域网**内监听，不碰公网
 *   · 不传任何身份信息，只用设备昵称
 *   · 一局结束就断开
 *
 * 拾海 2026-10-11
 */

import { socket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';

/** 发现用的广播端口（固定） */
const DISCOVER_PORT: number = 41234;
/** 房主的 TCP 端口（固定 —— SocketStateBase 拿不到 localAddress，见下方注释） */
const TCP_PORT: number = 41235;
/** 握手魔数 —— 用来过滤同网段其它应用的广播 */
const MAGIC: string = 'YIJU/1';

/** 房间信息 */
export interface LanRoom {
  ip: string;        // 房主 IP
  port: number;      // 房主 TCP 端口
  host: string;      // 房主昵称
  gameId: string;    // 玩哪一款
}

/** 一条对局消息 */
export interface LanMsg {
  t: string;         // 类型：hello / move / sync / bye
  d: string;         // 负载（各游戏自定义，通常是 JSON 串）
}

export class Lan {
  private static udp: socket.UDPSocket | null = null;
  private static tcp: socket.TCPSocket | null = null;
  private static server: socket.TCPSocketServer | null = null;
  private static conn: socket.TCPSocketConnection | null = null;
  private static onMsg: (m: LanMsg) => void = () => {};
  /** 握手是否完成（join 靠它判断是否真的连上了） */
  private static handshake: boolean = false;

  /** 本机昵称（可在设置里改，默认用系统给的短名） */
  static nick(): string {
    return AppStorage.get<string>('lanNick') ?? 'Player';
  }

  static setNick(n: string): void {
    AppStorage.setOrCreate('lanNick', n);
  }

  // ───────── 房主（开房）─────────

  /**
   * 开一个房间：起 TCP 服务端 + 开始广播自己
   * @param gameId 玩哪一款
   * @param onMsg  收到消息时回调
   * @returns 实际监听的端口（失败返回 0）
   */
  static async host(gameId: string, onMsg: (m: LanMsg) => void): Promise<number> {
    Lan.onMsg = onMsg;
    try {
      Lan.closeAll();
      const srv: socket.TCPSocketServer = socket.constructTCPSocketServerInstance();
      // ⚠️ 不能用 port: 0 让系统分配 —— `SocketStateBase` 里**没有 localAddress**，
      //    拿不到实际端口就没法告诉对手。⇒ 固定端口（同一 Wi-Fi 内够用）
      await srv.listen({ address: '0.0.0.0', port: TCP_PORT, family: 1 });
      Lan.server = srv;

      srv.on('connect', (c: socket.TCPSocketConnection) => {
        Lan.conn = c;
        c.on('message', (v: socket.SocketMessageInfo) => {
          const text: string = Lan.decode(v.message);
          if (text.indexOf('hello') >= 0) {
            c.send({ data: JSON.stringify({ t: 'ack', d: Lan.nick() }) }).catch(() => {});
          }
          Lan.dispatch(text);
        });
        c.on('close', () => {
          Lan.conn = null;
        });
      });

      await Lan.startBeacon(TCP_PORT, gameId);
      return TCP_PORT;
    } catch (e) {
      const err = e as BusinessError;
      console.error('Lan.host failed: ' + err.message);
      return 0;
    }
  }

  /** 广播自己的房间（每 1.5 秒一次） */
  private static async startBeacon(port: number, gameId: string): Promise<void> {
    try {
      const udp: socket.UDPSocket = socket.constructUDPSocketInstance();
      Lan.udp = udp;
      await udp.bind({ address: '0.0.0.0', port: DISCOVER_PORT, family: 1 });
      udp.setExtraOptions({ broadcast: true });

      udp.on('message', async (v: socket.SocketMessageInfo) => {
        const text: string = Lan.decode(v.message);
        if (text.startsWith(MAGIC + ' DISCOVER')) {
          const reply: string = MAGIC + ' HOST ' + port + ' ' + Lan.nick() + ' ' + gameId;
          await udp.send({
            data: reply,
            address: { address: v.remoteInfo.address, port: DISCOVER_PORT, family: 1 },
          });
        }
      });

      // 周期广播（用 setInterval 保持存活）
      setInterval(() => {
        udp.send({
          data: MAGIC + ' HERE ' + port + ' ' + Lan.nick() + ' ' + gameId,
          address: { address: '255.255.255.255', port: DISCOVER_PORT, family: 1 },
        }).catch(() => {});
      }, 1500);
    } catch (e) {
      const err = e as BusinessError;
      console.error('Lan.startBeacon failed: ' + err.message);
    }
  }

  // ───────── 加入方（找房）─────────

  /**
   * 扫一遍局域网，返回找到的房间（等 2 秒收应答）
   */
  static async scan(): Promise<LanRoom[]> {
    const found: LanRoom[] = [];
    try {
      const udp: socket.UDPSocket = socket.constructUDPSocketInstance();
      await udp.bind({ address: '0.0.0.0', port: 0, family: 1 });
      udp.setExtraOptions({ broadcast: true });

      udp.on('message', (v: socket.SocketMessageInfo) => {
        const text: string = Lan.decode(v.message);
        const parts: string[] = text.split(' ');
        // YIJU/1 HOST <port> <nick> <gameId>
        if (parts.length >= 5 && parts[0] === MAGIC && parts[1] === 'HOST') {
          const room: LanRoom = {
            ip: v.remoteInfo.address,
            port: Number.parseInt(parts[2], 10),
            host: parts[3],
            gameId: parts[4],
          };
          let dup: boolean = false;
          for (let i = 0; i < found.length; i++) {
            if (found[i].ip === room.ip && found[i].port === room.port) {
              dup = true;
              break;
            }
          }
          if (!dup) {
            found.push(room);
          }
        }
      });

      // 发三次广播（UDP 不保证送达，多试两次）
      for (let k = 0; k < 3; k++) {
        await udp.send({
          data: MAGIC + ' DISCOVER',
          address: { address: '255.255.255.255', port: DISCOVER_PORT, family: 1 },
        });
        await new Promise<void>((resolve) => {
          setTimeout(() => resolve(), 120);
        });
      }

      // 等 3 秒收应答（2 秒在模拟器上偶发收不到，放宽一点）
      await new Promise<void>((resolve) => {
        setTimeout(() => resolve(), 3000);
      });
      udp.close();
    } catch (e) {
      const err = e as BusinessError;
      console.error('Lan.scan failed: ' + err.message);
    }
    return found;
  }

  /**
   * 加入一个房间
   *
   * ★ 必须**等到对手回话才算连上**，不能只看 connect() 有没有抛错。
   *   实测（2026-10-11）：受限网络下 socket.connect() 会直接 resolve 而不抛错，
   *   于是 join() 返回 true、UI 显示已连接，而对端根本没收到连接、消息一条也发不出去。
   *   ⇒ 改成「发 hello → 等对端 ack → 收到才算成功」，超时 3 秒判失败并主动断开。
   */
  static async join(room: LanRoom, onMsg: (m: LanMsg) => void): Promise<boolean> {
    Lan.handshake = false;
    Lan.onMsg = (m: LanMsg) => {
      if (m.t === 'hello' || m.t === 'ack') {
        Lan.handshake = true;
      }
      onMsg(m);
    };
    try {
      Lan.closeAll();
      const tcp: socket.TCPSocket = socket.constructTCPSocketInstance();
      Lan.tcp = tcp;
      await tcp.connect({ address: { address: room.ip, port: room.port, family: 1 } });
      tcp.on('message', (v: socket.SocketMessageInfo) => {
        Lan.dispatch(Lan.decode(v.message));
      });
      await Lan.send({ t: 'hello', d: Lan.nick() });

      for (let i = 0; i < 30; i++) {
        if (Lan.handshake) {
          return true;
        }
        await new Promise<void>((resolve) => {
          setTimeout(() => resolve(), 100);
        });
      }
      Lan.closeAll();
      return false;
    } catch (e) {
      const err = e as BusinessError;
      console.error('Lan.join failed: ' + err.message);
      return false;
    }
  }

  // ───────── 收发 ─────────

  /** 发一条（房主走 server 的连接，加入方走 tcp） */
  static async send(m: LanMsg): Promise<void> {
    const payload: string = JSON.stringify(m) + '\n';
    try {
      if (Lan.conn !== null) {
        await Lan.conn.send({ data: payload });
      } else if (Lan.tcp !== null) {
        await Lan.tcp.send({ data: payload });
      }
    } catch (e) {
      const err = e as BusinessError;
      console.error('Lan.send failed: ' + err.message);
    }
  }

  private static dispatch(text: string): void {
    const lines: string[] = text.split('\n');
    for (let i = 0; i < lines.length; i++) {
      const line: string = lines[i].trim();
      if (line.length === 0) {
        continue;
      }
      try {
        const m: LanMsg = JSON.parse(line) as LanMsg;
        Lan.onMsg(m);
      } catch (e) {
        // 不是 JSON 就忽略（可能是别的应用串台）
      }
    }
  }

  /** ArrayBuffer / string → string */
  private static decode(msg: string | ArrayBuffer): string {
    if (typeof msg === 'string') {
      return msg;
    }
    const buf: ArrayBuffer = msg as ArrayBuffer;
    const bytes: Uint8Array = new Uint8Array(buf);
    let out: string = '';
    for (let i = 0; i < bytes.length; i++) {
      out += String.fromCharCode(bytes[i]);
    }
    return out;
  }

  /** 断线清理 */
  static leave(): void {
    Lan.send({ t: 'bye', d: '' }).then(() => {
      Lan.closeAll();
    });
  }

  /** 关掉所有连接（开新房/退出时调） */
  static closeAll(): void {
    try {
      if (Lan.conn !== null) {
        Lan.conn.close();
        Lan.conn = null;
      }
      if (Lan.tcp !== null) {
        Lan.tcp.close();
        Lan.tcp = null;
      }
      if (Lan.server !== null) {
        Lan.server.close();
        Lan.server = null;
      }
      if (Lan.udp !== null) {
        Lan.udp.close();
        Lan.udp = null;
      }
    } catch (e) {
      // 已经关了就算了
    }
  }
}
