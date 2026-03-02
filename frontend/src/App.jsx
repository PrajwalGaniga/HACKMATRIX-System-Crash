import { useEffect, useRef, useState, useCallback } from 'react';
import { io } from 'socket.io-client';
import './index.css';
import styles from './App.module.css';
import Overlay from './components/Overlay';
import Notification from './components/Notification';
import Monitor from './components/Monitor';
import ProcessTracker from './components/ProcessTracker';
import ControlCenter from './components/ControlCenter';
import DebugLog from './components/DebugLog';
import WebcamEngine from './components/WebcamEngine';

const BACKEND_URL = 'http://127.0.0.1:8000';
const ACTIVE_APP_POLL_MS = 4000;

export default function App() {
  const socketRef = useRef(null);
  const [isConnected, setIsConnected] = useState(false);
  const [intervention, setIntervention] = useState(null);
  const [activeApp, setActiveApp] = useState('Detecting…');
  const [telemetry, setTelemetry] = useState(null);
  const [mlActive, setMlActive] = useState(false);
  const [modelLoaded, setModelLoaded] = useState(false);
  const [videoStream, setVideoStream] = useState(null);
  const [logs, setLogs] = useState([]);
  const isFallback = telemetry?.source === 'fallback' || telemetry?.source === 'fail_safe';

  const pushLog = useCallback((entry) => {
    setLogs(prev => {
      const next = [...prev, { ...entry, _id: Date.now() + Math.random() }];
      return next.slice(-150);
    });
  }, []);

  // ── Poll active window every 4s ────────────────────────
  const pollActiveApp = useCallback(async () => {
    try {
      const res = await fetch(`${BACKEND_URL}/api/active-app`);
      const data = await res.json();
      const app = data.active_app || 'Unknown';
      setActiveApp(app);
    } catch (_) { }
  }, []);

  useEffect(() => {
    pollActiveApp();
    const interval = setInterval(pollActiveApp, ACTIVE_APP_POLL_MS);
    return () => clearInterval(interval);
  }, [pollActiveApp]);

  // ── Health check: poll backend status every 5s ───────────
  useEffect(() => {
    const checkHealth = async () => {
      try {
        const r = await fetch(`${BACKEND_URL}/health`);
        const d = await r.json();
        setModelLoaded(d.model_loaded);
        // Sync mlActive from backend truth (in case of page reload)
        setMlActive(d.ml_active);
      } catch (_) { setModelLoaded(false); }
    };
    checkHealth();
    const hInterval = setInterval(checkHealth, 5000);
    return () => clearInterval(hInterval);
  }, []);

  // ── Socket.IO ──────────────────────────────────────────
  useEffect(() => {
    const socket = io(BACKEND_URL, {
      transports: ['websocket', 'polling'],
      reconnectionAttempts: 10,
      reconnectionDelay: 1500,
    });
    socketRef.current = socket;

    socket.on('connect', () => {
      setIsConnected(true);
      pushLog({ level: 'success', msg: `✅ Socket.IO connected → ${BACKEND_URL} (id: ${socket.id})` });
    });
    socket.on('disconnect', () => {
      setIsConnected(false);
      pushLog({ level: 'error', msg: '❌ Socket.IO disconnected. Attempting reconnect...' });
    });
    socket.on('connected', (data) => {
      if (data.active_app) {
        setActiveApp(data.active_app);
        pushLog({ level: 'system', msg: `📍 Active app detected: ${data.active_app}` });
      }
    });
    socket.on('intervention', (data) => {
      setIntervention(data);
      if (data.active_app) setActiveApp(data.active_app);
      const level = data.stress_level === 'HIGH' ? 'high' : data.stress_level === 'ELEVATED' ? 'elevated' : 'stable';
      pushLog({ level, msg: `${data.toast_emoji || '🛡️'} [${data.stress_level}] ${data.action} — "${data.toast_msg}" | Game: ${data.game_id || 'N/A'} | Gemini conf: ${(data.confidence * 100).toFixed(0)}%` });
      if (data.trigger_call) {
        pushLog({ level: 'warn', msg: `📞 Twilio call triggered → ${data.call_result?.status || 'pending'} (SID: ${data.call_result?.sid || 'N/A'})` });
      }
      if (data.game_options?.length) {
        pushLog({ level: 'info', msg: `🎮 Game menu sent to Flutter: [${data.game_options.join(', ')}] | CTA: "${data.cta_label}"` });
      }
    });
    socket.on('ml_telemetry', (data) => {
      setTelemetry(data);
      if (data.source === 'fallback') {
        pushLog({ level: 'fallback', msg: `⚠️ YOLO FALLBACK ACTIVE — no face for 30s. Reading fallback_stress.json (AU23=${(data.au23 * 100).toFixed(0)}%, BPM=${data.blink_rate})` });
      }
    });
    socket.on('error', (e) => {
      pushLog({ level: 'error', msg: `Socket error: ${JSON.stringify(e)}` });
    });

    return () => socket.disconnect();
  }, [pushLog]);

  const handleWebcamLog = useCallback((entry) => {
    pushLog(entry);
  }, [pushLog]);

  const handleTelemetry = useCallback((data) => {
    setTelemetry(data);
  }, []);

  return (
    <div className={styles.app}>
      {/* Hidden webcam engine */}
      <WebcamEngine active={mlActive} onTelemetry={handleTelemetry} onLog={handleWebcamLog} onStreamReady={setVideoStream} />

      {/* Amber overlay (pointer-events: none) */}
      <Overlay intervention={intervention} />

      {/* Hype-Man toast notifications */}
      <Notification intervention={intervention} />

      {/* Navigation */}
      <nav className={styles.navbar}>
        <div className={styles.navLogo}>
          <div className={styles.navLogoIcon}>🛡️</div>
          <div>
            <div className={styles.navLogoText}>Aegis.ai</div>
            <div className={styles.navSubtext}>Bio-Stabilizer · MVP v2.0</div>
          </div>
        </div>
        <div className={styles.navRight}>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 6,
            padding: '4px 12px', borderRadius: 999,
            background: 'rgba(255,255,255,0.04)', border: '1px solid var(--border-subtle)',
            fontSize: '0.7rem', fontFamily: 'var(--font-mono)', color: 'var(--accent-cyan)',
            maxWidth: 240, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
          }}>
            {mlActive && <span style={{ width: 7, height: 7, borderRadius: '50%', background: '#68D391', animation: 'pulseDot 1.5s ease-in-out infinite', flexShrink: 0 }} />}
            <span style={{ opacity: 0.5 }}>📍</span>
            <span title={activeApp}>{activeApp}</span>
          </div>
          <span style={{ fontSize: '0.7rem', color: 'var(--text-muted)', fontFamily: 'var(--font-mono)' }}>
            {isConnected ? '🟢 Connected' : '🔴 Offline'} · gemini-2.5-flash
          </span>
        </div>
      </nav>

      {/* Main Content */}
      <main className={styles.main}>
        {/* Connection Banner */}
        <div className={`${styles.connectionBanner} ${isConnected ? styles.connected : styles.disconnected}`}>
          <div className={styles.connDot} />
          {isConnected
            ? `Socket.IO connected → ${BACKEND_URL} | Active: ${activeApp} | ${mlActive ? '🎥 YOLOv8 Webcam LIVE' : '💤 ML Engine Off'}`
            : `Connecting to ${BACKEND_URL}… make sure FastAPI is running.`}
        </div>

        {/* Left Column: Context + Controls */}
        <div className={styles.leftColumn}>
          <ProcessTracker activeApp={activeApp} intervention={intervention} />
          <ControlCenter mlActive={mlActive} setMlActive={setMlActive} socket={socketRef.current} onLog={pushLog} isFallback={isFallback} modelLoaded={modelLoaded} />
        </div>

        {/* Right Column: Monitor + History + Debug */}
        <div className={styles.rightColumn}>
          <Monitor telemetryData={telemetry} mlActive={mlActive} isFallback={isFallback} videoStream={videoStream} />
          <BiometricFeed intervention={intervention} />
          <DebugLog externalLogs={logs} />
        </div>
      </main>

      <style>{`
        @keyframes pulseDot {
          0%, 100% { opacity: 1; transform: scale(1); }
          50% { opacity: 0.4; transform: scale(0.85); }
        }
      `}</style>
    </div>
  );
}

// ── BiometricFeed: Intervention History ───────────────────
function BiometricFeed({ intervention }) {
  const [history, setHistory] = useState([]);

  useEffect(() => {
    if (intervention?.stress_level) {
      setHistory(prev => [
        {
          id: Date.now(),
          time: new Date().toLocaleString('en-IN', { hour12: true, month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }),
          level: intervention.stress_level,
          action: intervention.action,
          tip: intervention.toast_msg || intervention.intervention_tip,
          app: intervention.active_app || '',
          called: intervention.call_result?.status === 'initiated',
          gameId: intervention.game_id,
          gameOptions: intervention.game_options || [],
        },
        ...prev.slice(0, 9),
      ]);
    }
  }, [intervention]);

  const levelColor = { HIGH: 'var(--accent-red)', ELEVATED: 'var(--accent-amber)', STABLE: 'var(--accent-green)' };

  return (
    <div style={{
      background: 'var(--bg-card)', border: '1px solid var(--border-subtle)',
      borderRadius: 'var(--radius-lg)', padding: 20, backdropFilter: 'blur(8px)',
      boxShadow: 'var(--shadow-card)',
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, borderBottom: '1px solid var(--border-subtle)', paddingBottom: 14, marginBottom: 14 }}>
        <span>📋</span>
        <span style={{ fontSize: '0.75rem', fontWeight: 600, letterSpacing: '1.5px', textTransform: 'uppercase', color: 'var(--text-secondary)', fontFamily: 'var(--font-mono)' }}>
          Intervention Log
        </span>
        {history.length > 0 && (
          <span style={{ marginLeft: 'auto', fontSize: '0.6rem', color: 'var(--text-muted)', fontFamily: 'var(--font-mono)' }}>
            {history.length} event{history.length !== 1 ? 's' : ''}
          </span>
        )}
      </div>
      {history.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '16px 0', color: 'var(--text-muted)', fontSize: '0.78rem', fontFamily: 'var(--font-mono)' }}>
          No events yet — trigger a simulation or enable webcam.
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {history.map(h => (
            <div key={h.id} style={{
              background: 'rgba(255,255,255,0.02)', border: `1px solid ${(levelColor[h.level] || '#333')}33`,
              borderRadius: 8, padding: '10px 14px',
            }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                <div>
                  <span style={{ fontSize: '0.68rem', fontFamily: 'var(--font-mono)', fontWeight: 700, color: levelColor[h.level] || 'var(--text-secondary)' }}>
                    {h.action === 'INTERVENE' ? '⚡' : h.action === 'MONITOR' ? '👁' : '✅'} {h.level} — {h.action}
                    {h.called && <span style={{ marginLeft: 8, color: 'var(--accent-cyan)', fontSize: '0.6rem' }}>📞 Called</span>}
                  </span>
                  <div style={{ fontSize: '0.58rem', color: 'var(--text-muted)', fontFamily: 'var(--font-mono)', marginTop: 2 }}>{h.time}</div>
                </div>
                {h.gameId && (
                  <span style={{ fontSize: '0.6rem', background: 'rgba(99,179,237,0.1)', border: '1px solid rgba(99,179,237,0.3)', color: 'var(--accent-cyan)', padding: '2px 8px', borderRadius: 4, fontFamily: 'var(--font-mono)', whiteSpace: 'nowrap' }}>
                    🎮 {h.gameId}
                  </span>
                )}
              </div>
              {h.tip && <div style={{ fontSize: '0.65rem', color: 'var(--text-secondary)', fontStyle: 'italic', marginTop: 5 }}>"{h.tip}"</div>}
              {h.app && <div style={{ fontSize: '0.6rem', color: 'var(--text-muted)', marginTop: 3 }}>📍 {h.app}</div>}
              {h.gameOptions?.length > 1 && (
                <div style={{ display: 'flex', gap: 4, marginTop: 6, flexWrap: 'wrap' }}>
                  {h.gameOptions.map(g => (
                    <span key={g} style={{ fontSize: '0.58rem', background: 'rgba(104,211,145,0.1)', border: '1px solid rgba(104,211,145,0.3)', color: '#68D391', padding: '1px 7px', borderRadius: 4, fontFamily: 'var(--font-mono)' }}>
                      {g}
                    </span>
                  ))}
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
