import { useEffect, useRef, useState, useCallback } from 'react';
import { io } from 'socket.io-client';
import './index.css';
import styles from './App.module.css';
import Overlay from './components/Overlay';
import Dashboard from './components/Dashboard';
import Controls from './components/Controls';
import StatusBar from './components/StatusBar';
import Notification from './components/Notification';

const BACKEND_URL = 'https://dawdlingly-pseudoinsane-pa.ngrok-free.dev';
const ACTIVE_APP_POLL_MS = 4000;

export default function App() {
  const socketRef = useRef(null);
  const [isConnected, setIsConnected] = useState(false);
  const [intervention, setIntervention] = useState(null);
  const [activeApp, setActiveApp] = useState('Detecting…');

  // ── Poll active window every 4s ────────────────────────
  const pollActiveApp = useCallback(async () => {
    try {
      const res = await fetch(`${BACKEND_URL}/api/active-app`);
      const data = await res.json();
      setActiveApp(data.active_app || 'Unknown');
    } catch (_) { /* silently ignore */ }
  }, []);

  useEffect(() => {
    pollActiveApp();
    const interval = setInterval(pollActiveApp, ACTIVE_APP_POLL_MS);
    return () => clearInterval(interval);
  }, [pollActiveApp]);

  // ── Socket.IO ──────────────────────────────────────────
  useEffect(() => {
    const socket = io(BACKEND_URL, {
      transports: ['websocket', 'polling'],
      reconnectionAttempts: 10,
      reconnectionDelay: 1500,
    });
    socketRef.current = socket;

    socket.on('connect', () => {
      console.log('✅ Socket connected:', socket.id);
      setIsConnected(true);
    });
    socket.on('disconnect', () => {
      console.log('❌ Socket disconnected');
      setIsConnected(false);
    });
    socket.on('connected', (data) => {
      console.log('🛡️ Aegis v2:', data.message);
      if (data.active_app) setActiveApp(data.active_app);
    });
    socket.on('intervention', (data) => {
      console.log('🚨 Intervention:', data);
      setIntervention(data);
      if (data.active_app) setActiveApp(data.active_app);
    });
    socket.on('error', console.error);

    return () => socket.disconnect();
  }, []);

  return (
    <div className={styles.app}>
      {/* ── Amber overlay (pointer-events: none) ─────── */}
      <Overlay intervention={intervention} />

      {/* ── Hype-Man toast notifications ─────────────── */}
      <Notification intervention={intervention} />

      {/* ── Navigation ───────────────────────────────── */}
      <nav className={styles.navbar}>
        <div className={styles.navLogo}>
          <div className={styles.navLogoIcon}>🛡️</div>
          <div>
            <div className={styles.navLogoText}>Aegis.ai</div>
            <div className={styles.navSubtext}>Bio-Stabilizer · MVP v2.0</div>
          </div>
        </div>
        <div className={styles.navRight}>
          {/* Active App Pill */}
          <div style={{
            display: 'flex', alignItems: 'center', gap: 6,
            padding: '4px 12px', borderRadius: 999,
            background: 'rgba(255,255,255,0.04)', border: '1px solid var(--border-subtle)',
            fontSize: '0.7rem', fontFamily: 'var(--font-mono)', color: 'var(--accent-cyan)',
            maxWidth: 220, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
          }}>
            <span style={{ opacity: 0.5 }}>📍</span>
            <span title={activeApp}>{activeApp}</span>
          </div>
          <span style={{ fontSize: '0.7rem', color: 'var(--text-muted)', fontFamily: 'var(--font-mono)' }}>
            gemini-2.5-flash · FastAPI · MongoDB
          </span>
        </div>
      </nav>

      {/* ── Main Content ─────────────────────────────── */}
      <main className={styles.main}>
        {/* Connection Banner */}
        <div className={`${styles.connectionBanner} ${isConnected ? styles.connected : styles.disconnected}`}>
          <div className={styles.connDot} />
          {isConnected
            ? `Socket.IO connected → ${BACKEND_URL} | Active: ${activeApp}`
            : `Connecting to ${BACKEND_URL}… make sure FastAPI is running.`}
        </div>

        {/* Left: StatusBar + Controls */}
        <div className={styles.leftColumn}>
          <StatusBar intervention={intervention} />
          <Controls
            socket={socketRef.current}
            isConnected={isConnected}
            activeApp={activeApp}
          />
        </div>

        {/* Right: Dashboard + History */}
        <div className={styles.rightColumn}>
          <Dashboard />
          <BiometricFeed intervention={intervention} />
        </div>
      </main>
    </div>
  );
}

// ── Inline: Intervention History card ──────────────────────
function BiometricFeed({ intervention }) {
  const [history, setHistory] = useState([]);

  useEffect(() => {
    if (intervention && intervention.stress_level) {
      setHistory((prev) => [
        {
          id: Date.now(),
          time: new Date().toLocaleTimeString(),
          level: intervention.stress_level,
          action: intervention.action,
          tip: intervention.toast_msg || intervention.intervention_tip,
          app: intervention.active_app || '',
          called: intervention.call_result?.status === 'initiated',
        },
        ...prev.slice(0, 9),
      ]);
    }
  }, [intervention]);

  const levelColor = {
    HIGH: 'var(--accent-red)', ELEVATED: 'var(--accent-amber)', STABLE: 'var(--accent-green)',
  };

  return (
    <div style={{
      background: 'var(--bg-card)', border: '1px solid var(--border-subtle)',
      borderRadius: 'var(--radius-lg)', padding: 24, backdropFilter: 'blur(8px)',
      boxShadow: 'var(--shadow-card)',
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, borderBottom: '1px solid var(--border-subtle)', paddingBottom: 16, marginBottom: 16 }}>
        <span>📋</span>
        <span style={{ fontSize: '0.75rem', fontWeight: 600, letterSpacing: '1.5px', textTransform: 'uppercase', color: 'var(--text-secondary)', fontFamily: 'var(--font-mono)' }}>
          Intervention Log
        </span>
      </div>
      {history.length === 0 ? (
        <div style={{ textAlign: 'center', padding: 20, color: 'var(--text-muted)', fontSize: '0.8rem', fontFamily: 'var(--font-mono)' }}>
          No events yet — trigger a simulation.
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {history.map((h) => (
            <div key={h.id} style={{
              background: 'rgba(255,255,255,0.02)', border: '1px solid var(--border-subtle)',
              borderRadius: 8, padding: '10px 14px',
            }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ fontSize: '0.68rem', fontFamily: 'var(--font-mono)', fontWeight: 700, color: levelColor[h.level] || 'var(--text-secondary)' }}>
                  {h.action === 'INTERVENE' ? '⚡' : h.action === 'MONITOR' ? '👁' : '✅'} {h.level} — {h.action}
                  {h.called && <span style={{ marginLeft: 8, color: 'var(--accent-cyan)', fontSize: '0.6rem' }}>📞 Called</span>}
                </span>
                <span style={{ fontSize: '0.6rem', color: 'var(--text-muted)', fontFamily: 'var(--font-mono)' }}>{h.time}</span>
              </div>
              {h.tip && <div style={{ fontSize: '0.65rem', color: 'var(--text-secondary)', fontStyle: 'italic', marginTop: 3 }}>"{h.tip}"</div>}
              {h.app && <div style={{ fontSize: '0.6rem', color: 'var(--text-muted)', marginTop: 2 }}>📍 {h.app}</div>}
            </div>
          ))}
        </div>
      )}
      <style>{`
        @keyframes feedItemIn { from{opacity:0;transform:translateX(10px)} to{opacity:1;transform:translateX(0)} }
      `}</style>
    </div>
  );
}
