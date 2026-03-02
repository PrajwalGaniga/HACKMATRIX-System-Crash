import { useState } from 'react';
import styles from './Controls.module.css';

const BACKEND_URL = 'http://localhost:8000';

async function callEndpoint(path) {
    const res = await fetch(`${BACKEND_URL}${path}`, { method: 'POST' });
    return res.json();
}

const AU_CONFIG = [
    { key: 'au4', label: 'AU4 — Brow Lowerer (Frustration)', min: 0, max: 1, step: 0.01, color: '#63b3ed' },
    { key: 'au23', label: 'AU23 — Lip Tightener (Suppressed Anger)', min: 0, max: 1, step: 0.01, color: '#f6ad55' },
    { key: 'blink_rate', label: 'Blink Rate (per min)', min: 0, max: 30, step: 1, color: '#68d391' },
];

export default function Controls({ socket, isConnected, activeApp = '' }) {
    const [auValues, setAuValues] = useState({ au4: 0.5, au23: 0.5, blink_rate: 12 });
    const [loading, setLoading] = useState(null); // track which button is loading
    const [feedback, setFeedback] = useState(null);

    const showFeedback = (msg, type = 'success') => {
        setFeedback({ msg, type });
        setTimeout(() => setFeedback(null), 4000);
    };

    // ── Simulate HIGH stress (Gemini + Twilio + Amber) ─────
    const handleSimulateStress = async () => {
        setLoading('stress');
        try {
            const data = await callEndpoint('/trigger-stress');
            const p = data.payload || data;
            const tip = p?.intervention_tip || p?.gemini?.intervention_tip || 'Intervention active.';
            const called = p?.call_result?.status === 'initiated';
            showFeedback(
                `⚡ HIGH tilt triggered!${called ? ' 📞 Calling +91 9110…' : ''} Gemini: "${tip}"`,
                'success'
            );
        } catch (err) {
            showFeedback(`❌ Backend unreachable: ${err.message}`, 'error');
        } finally {
            setLoading(null);
        }
    };

    // ── Simulate ELEVATED (softer demo, no Twilio call) ────
    const handleSimulateElevated = async () => {
        setLoading('elevated');
        try {
            const data = await callEndpoint('/trigger-elevated');
            const p = data.payload || data;
            const tip = p?.intervention_tip || 'Elevated monitoring active.';
            showFeedback(`⚠ Elevated state triggered. Gemini: "${tip}"`, 'success');
        } catch (err) {
            showFeedback(`❌ ${err.message}`, 'error');
        } finally {
            setLoading(null);
        }
    };

    // ── Reset ──────────────────────────────────────────────
    const handleReset = async () => {
        try {
            await callEndpoint('/reset-stress');
            showFeedback('✅ System reset — Amber Shift cleared.', 'success');
        } catch (err) {
            showFeedback(`❌ Reset failed: ${err.message}`, 'error');
        }
    };

    // ── Send live AU via socket (includes active_app context) ──
    const handleSendAU = () => {
        if (!socket || !isConnected) {
            showFeedback('❌ Socket not connected.', 'error');
            return;
        }
        socket.emit('au_metadata', { ...auValues, active_app: activeApp });
        showFeedback(
            `📡 Sent: AU4=${auValues.au4.toFixed(2)} AU23=${auValues.au23.toFixed(2)} Blink=${auValues.blink_rate}/min | ${activeApp}`,
            'success'
        );
    };

    return (
        <div className={styles.controls}>
            <div className={styles.sectionHeader}>
                <span className={styles.sectionIcon}>🎛️</span>
                <span className={styles.sectionTitle}>Aegis Controls</span>
            </div>

            {/* Active App badge */}
            {activeApp && (
                <div style={{
                    fontSize: '0.68rem', fontFamily: 'var(--font-mono)', color: 'var(--accent-cyan)',
                    background: 'rgba(118,228,247,0.05)', border: '1px solid rgba(118,228,247,0.2)',
                    borderRadius: 8, padding: '6px 12px',
                }}>
                    📍 Context: <strong>{activeApp}</strong>
                </div>
            )}

            {/* AU Sliders */}
            <div className={styles.auGroup}>
                {AU_CONFIG.map(({ key, label, min, max, step }) => (
                    <div className={styles.auRow} key={key}>
                        <div className={styles.auLabelRow}>
                            <span className={styles.auLabel}>{label}</span>
                            <span className={styles.auValue}>
                                {key === 'blink_rate' ? auValues[key] : auValues[key].toFixed(2)}
                            </span>
                        </div>
                        <input
                            type="range"
                            className={styles.slider}
                            min={min} max={max} step={step}
                            value={auValues[key]}
                            onChange={(e) => setAuValues((p) => ({ ...p, [key]: Number(e.target.value) }))}
                        />
                    </div>
                ))}
            </div>

            {/* Buttons */}
            <div className={styles.buttonGroup}>
                <button
                    id="simulate-stress-btn"
                    className={styles.btnStress}
                    onClick={handleSimulateStress}
                    disabled={loading !== null}
                >
                    {loading === 'stress' ? '⏳ Triggering…' : '🚨 Simulate HIGH Stress + Twilio Call'}
                </button>

                <button
                    id="simulate-elevated-btn"
                    className={styles.btnSend}
                    onClick={handleSimulateElevated}
                    disabled={loading !== null}
                    style={{ background: 'rgba(246,173,85,0.08)', borderColor: 'rgba(246,173,85,0.3)', color: 'var(--accent-amber)' }}
                >
                    {loading === 'elevated' ? '⏳ Triggering…' : '⚠ Simulate Elevated Stress'}
                </button>

                <button
                    id="send-au-btn"
                    className={styles.btnSend}
                    onClick={handleSendAU}
                    disabled={!isConnected}
                >
                    📡 Send Live AU + Context
                </button>

                <button
                    id="reset-btn"
                    className={styles.btnReset}
                    onClick={handleReset}
                >
                    🔄 Reset / Clear Amber Shift
                </button>
            </div>

            {/* Feedback */}
            {feedback && (
                <div className={`${styles.feedback} ${styles[feedback.type]}`}>
                    {feedback.msg}
                </div>
            )}
        </div>
    );
}
