import React, { useState, useEffect, useRef } from 'react';
import { AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer } from 'recharts';
import styles from './Monitor.module.css';
import { Activity, Shield, ShieldOff } from 'lucide-react';

export default function Monitor({ telemetryData, mlActive, isFallback, videoStream }) {
    const [dataPoints, setDataPoints] = useState([]);
    const videoRef = useRef(null);

    // Attach stream to video element
    useEffect(() => {
        if (videoRef.current && videoStream) {
            videoRef.current.srcObject = videoStream;
        }
    }, [videoStream]);

    useEffect(() => {
        if (telemetryData) {
            setDataPoints(prev => {
                const newData = [...prev, {
                    time: new Date().toLocaleTimeString('en-US', { hour12: false, hour: "numeric", minute: "numeric", second: "numeric" }),
                    stress: (Math.max(telemetryData.au4, telemetryData.au23) * 100),
                    au4: telemetryData.au4 * 100,
                    au23: telemetryData.au23 * 100
                }];
                return newData.slice(-40); // Keep last 40 ticks
            });
        }
    }, [telemetryData]);

    const current = telemetryData || { au4: 0, au7: 0, au23: 0, au43: 0, blink_rate: 15 };

    const intensityColor = (val) => {
        if (val > 0.7) return 'var(--accent-amber)';
        if (val > 0.4) return 'var(--accent-blue)';
        return 'var(--text-muted)';
    };

    return (
        <div className={styles.monitorContainer}>
            <div className={styles.header}>
                <Activity size={18} color={mlActive ? '#68D391' : 'var(--accent-blue)'} />
                <span className={styles.title}>Live Biometric Feed (YOLOv8)</span>
                {mlActive && (
                    <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginLeft: 'auto' }}>
                        <span style={{ width: 8, height: 8, borderRadius: '50%', background: '#68D391', animation: 'scanPulse 1.2s ease-in-out infinite' }} />
                        <span style={{ fontSize: '0.62rem', color: '#68D391', fontFamily: 'var(--font-mono)' }}>SCANNING</span>
                    </div>
                )}
                {telemetryData?.source === 'fallback' && (
                    <span style={{ marginLeft: 'auto', fontSize: '0.6rem', background: 'rgba(246,173,85,0.15)', border: '1px solid rgba(246,173,85,0.4)', color: 'var(--accent-amber)', padding: '2px 8px', borderRadius: 4, fontFamily: 'var(--font-mono)' }}>
                        ⚠ Fallback
                    </span>
                )}
            </div>

            <div className={styles.visualArea}>
                {mlActive ? (
                    <div style={{ position: 'relative', width: '100%', height: 160, backgroundColor: '#000', borderRadius: 8, overflow: 'hidden' }}>
                        <video
                            ref={videoRef}
                            autoPlay playsInline muted
                            style={{ width: '100%', height: '100%', objectFit: 'cover', opacity: isFallback ? 0.3 : 1, filter: isFallback ? 'grayscale(100%)' : 'none' }}
                        />
                        {/* Fake AU Point Overlays mapping to intensity */}
                        {!isFallback && current.au4 > 0.1 && (
                            <div style={{ position: 'absolute', top: '35%', left: '45%', width: 24, height: 6, background: 'rgba(255,255,255,0.8)', boxShadow: '0 0 10px #F6AD55', borderRadius: 4, transform: 'rotate(-10deg)', opacity: current.au4 }} />
                        )}
                        {!isFallback && current.au4 > 0.1 && (
                            <div style={{ position: 'absolute', top: '35%', right: '45%', width: 24, height: 6, background: 'rgba(255,255,255,0.8)', boxShadow: '0 0 10px #F6AD55', borderRadius: 4, transform: 'rotate(10deg)', opacity: current.au4 }} />
                        )}
                        {!isFallback && current.au23 > 0.1 && (
                            <div style={{ position: 'absolute', bottom: '25%', left: '50%', transform: 'translateX(-50%)', width: 30, height: 8, background: 'rgba(255,255,255,0.9)', boxShadow: '0 0 10px #FC8181', borderRadius: 6, opacity: current.au23 }} />
                        )}

                        {isFallback && (
                            <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', flexDirection: 'column', color: 'var(--accent-amber)', fontSize: '0.75rem', fontFamily: 'var(--font-mono)', textAlign: 'center' }}>
                                <span>⚠ MODEL UNAVAILABLE</span>
                                <span style={{ fontSize: '0.65rem', opacity: 0.7 }}>Injecting Fail-Safe Stress</span>
                            </div>
                        )}
                    </div>
                ) : (
                    <div style={{ width: '100%', height: 160, backgroundColor: 'rgba(0,0,0,0.3)', borderRadius: 8, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', border: '1px dashed var(--border-subtle)' }}>
                        <ShieldOff size={28} color="var(--text-muted)" style={{ opacity: 0.5, marginBottom: 8 }} />
                        <span style={{ color: 'var(--text-muted)', fontSize: '0.75rem', fontFamily: 'var(--font-mono)' }}>System Paused (UI Idle)</span>
                        <span style={{ color: 'var(--text-muted)', fontSize: '0.65rem', opacity: 0.5, marginTop: 4 }}>Saving GPU cycles</span>
                    </div>
                )}
            </div>

            <div className={styles.auGrid}>
                <AuBar label="AU4 (Brow Lowerer)" value={current.au4} color={intensityColor(current.au4)} />
                <AuBar label="AU7 (Lid Tightener)" value={current.au7} color={intensityColor(current.au7)} />
                <AuBar label="AU23 (Lip Tightener)" value={current.au23} color={intensityColor(current.au23)} />
                <div className={styles.bpmStat}>
                    <span className={styles.bpmLabel}>Blink Rate</span>
                    <span className={styles.bpmValue} style={{ color: current.blink_rate < 10 ? 'var(--accent-amber)' : 'var(--accent-green)' }}>
                        {current.blink_rate} <span className={styles.bpmUnit}>BPM</span>
                    </span>
                </div>
            </div>
        </div>
    );
}

function AuBar({ label, value, color }) {
    const pct = Math.round(value * 100);
    return (
        <div className={styles.auItem}>
            <div className={styles.auHeader}>
                <span className={styles.auLabel}>{label}</span>
                <span className={styles.auValue}>{pct}%</span>
            </div>
            <div className={styles.barTrack}>
                <div className={styles.barFill} style={{ width: `${pct}%`, backgroundColor: color }} />
            </div>
        </div>
    );
}
