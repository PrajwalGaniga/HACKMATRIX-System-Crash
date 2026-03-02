import React, { useState, useEffect, useRef } from 'react';
import styles from './DebugLog.module.css';
import { Terminal } from 'lucide-react';

const MAX_LOGS = 120;

const levelStyle = {
    success: { color: '#68D391' },       // green
    info: { color: '#63B3ED' },       // blue
    warn: { color: '#F6AD55' },       // amber
    error: { color: '#FC8181' },       // red
    high: { color: '#FC8181', fontWeight: 700 },
    elevated: { color: '#F6AD55', fontWeight: 700 },
    stable: { color: '#68D391' },
    system: { color: '#718096' },       // muted
    fallback: { color: '#F6AD55', fontStyle: 'italic' },
};

export default function DebugLog({ externalLogs = [] }) {
    const [logs, setLogs] = useState([
        { ts: formattedNow(), level: 'system', msg: '— Aegis.ai Debug Console initialised —' },
        { ts: formattedNow(), level: 'system', msg: 'Connect to backend and start monitoring to see live events.' },
    ]);
    const bottomRef = useRef(null);

    // Accept external log pushes (from sockets + webcam engine)
    useEffect(() => {
        if (!externalLogs.length) return;
        const latest = externalLogs[externalLogs.length - 1];
        if (!latest) return;
        setLogs(prev => {
            const next = [...prev, { ts: formattedNow(), ...latest }];
            return next.slice(-MAX_LOGS);
        });
    }, [externalLogs]);

    // Auto-scroll
    useEffect(() => {
        bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
    }, [logs]);

    return (
        <div className={styles.container}>
            <div className={styles.header}>
                <Terminal size={16} color="var(--accent-green)" />
                <span className={styles.title}>Debug Console</span>
                <span className={styles.count}>{logs.length}/{MAX_LOGS}</span>
                <button className={styles.clearBtn} onClick={() => setLogs([])}>Clear</button>
            </div>
            <div className={styles.logArea}>
                {logs.map((log, i) => (
                    <div key={i} className={styles.logLine}>
                        <span className={styles.ts}>{log.ts}</span>
                        <span className={styles.msg} style={levelStyle[log.level] || levelStyle.system}>
                            {log.msg}
                        </span>
                    </div>
                ))}
                <div ref={bottomRef} />
            </div>
        </div>
    );
}

function formattedNow() {
    const d = new Date();
    return d.toLocaleTimeString('en-GB', { hour12: false }) + '.' + String(d.getMilliseconds()).padStart(3, '0');
}
