import React, { useState, useRef } from 'react';
import styles from './ControlCenter.module.css';
import { Settings2, Zap, AlertTriangle, MonitorPlay, UploadCloud, CheckCircle, Shield, ShieldOff } from 'lucide-react';

export default function ControlCenter({ mlActive, setMlActive, socket, onLog }) {
    const [isSimLoading, setIsSimLoading] = useState(false);
    const [uploadStatus, setUploadStatus] = useState(null);
    const fileInputRef = useRef(null);

    const toggleMl = async () => {
        try {
            const res = await fetch('http://127.0.0.1:8000/api/toggle-ml', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ active: !mlActive })
            });
            const data = await res.json();
            setMlActive(data.ml_active);
            onLog?.({ level: 'info', msg: `🔀 ML Engine ${data.ml_active ? 'STARTED' : 'STOPPED'} via API toggle` });
        } catch (err) {
            onLog?.({ level: 'error', msg: `Toggle ML error: ${err.message}` });
        }
    };

    const triggerSimulation = async (type) => {
        setIsSimLoading(true);
        try {
            const endpoint = type === 'HIGH' ? '/trigger-stress' : '/trigger-elevated';
            onLog?.({ level: 'warn', msg: `🧪 Developer Simulator: sending ${type} stress injection to Gemini...` });
            const res = await fetch(`http://127.0.0.1:8000${endpoint}`, { method: 'POST' });
            const data = await res.json();
            onLog?.({ level: type === 'HIGH' ? 'high' : 'elevated', msg: `✅ Simulator response: ${data.status}` });
        } catch (err) {
            onLog?.({ level: 'error', msg: `Simulator error: ${err.message}` });
        } finally {
            setIsSimLoading(false);
        }
    };

    const handleFileUpload = async (e) => {
        const file = e.target.files?.[0];
        if (!file) return;
        setUploadStatus('uploading');
        onLog?.({ level: 'info', msg: `📤 Uploading "${file.name}" for YOLO inference...` });
        try {
            const formData = new FormData();
            formData.append('file', file);
            const res = await fetch('http://127.0.0.1:8000/api/upload-frame', {
                method: 'POST',
                body: formData,
            });
            const data = await res.json();
            if (data.au_data) {
                setUploadStatus('done');
                onLog?.({ level: 'success', msg: `✅ YOLO result: AU4=${(data.au_data.au4 * 100).toFixed(0)}% | AU23=${(data.au_data.au23 * 100).toFixed(0)}% | BPM=${data.au_data.blink_rate} | Source=${data.au_data.source}` });
                onLog?.({ level: 'info', msg: data.message });
            } else {
                setUploadStatus('error');
                onLog?.({ level: 'error', msg: `Upload inference failed: ${data.error || JSON.stringify(data)}` });
            }
        } catch (err) {
            setUploadStatus('error');
            onLog?.({ level: 'error', msg: `Upload error: ${err.message}` });
        }
        setTimeout(() => setUploadStatus(null), 3000);
        e.target.value = '';
    };

    return (
        <div className={styles.container}>
            <div className={styles.header}>
                <Settings2 size={18} color="var(--accent-cyan)" />
                <span className={styles.title}>Operation Modes</span>
            </div>

            {/* Actual Mode Toggle */}
            <div className={styles.toggleRow}>
                <div className={styles.toggleContext}>
                    <span className={styles.toggleTitle}>
                        {mlActive && <span className={styles.scanDot} />}
                        Actual Mode (YOLOv8 ML)
                    </span>
                    <span className={styles.toggleDesc}>
                        {mlActive ? 'Scanning face via browser webcam…' : 'Use webcam to detect live AU markers.'}
                    </span>
                </div>
                <button
                    className={`${styles.shieldBtn} ${mlActive ? styles.shieldActive : ''}`}
                    onClick={toggleMl}
                >
                    {mlActive ? <Shield size={18} /> : <ShieldOff size={18} />}
                    <span>{mlActive ? 'Stop Monitoring' : 'Start Shield'}</span>
                </button>
            </div>

            {/* Developer Simulator */}
            <div className={styles.devSection}>
                <div className={styles.devHeader}>
                    <MonitorPlay size={14} />
                    <span>Developer Simulator</span>
                </div>

                <div className={styles.simGrid}>
                    <button
                        className={`${styles.simBtn} ${styles.highBtn}`}
                        onClick={() => triggerSimulation('HIGH')}
                        disabled={isSimLoading || mlActive}
                    >
                        <AlertTriangle size={16} />
                        <div className={styles.btnText}>
                            <span className={styles.btnTitle}>Trigger Loss Streak (HIGH)</span>
                            <span className={styles.btnSub}>Simulates PUBG tilt (+ Twilio call)</span>
                        </div>
                    </button>

                    <button
                        className={`${styles.simBtn} ${styles.elevatedBtn}`}
                        onClick={() => triggerSimulation('ELEVATED')}
                        disabled={isSimLoading || mlActive}
                    >
                        <Zap size={16} />
                        <div className={styles.btnText}>
                            <span className={styles.btnTitle}>Trigger Panic Loop (ELEVATED)</span>
                            <span className={styles.btnSub}>Simulates VS Code frustration</span>
                        </div>
                    </button>
                </div>

                {/* File Upload for Instant Testing */}
                <div className={styles.uploadSection}>
                    <input ref={fileInputRef} type="file" accept="image/*" style={{ display: 'none' }} onChange={handleFileUpload} />
                    <button
                        className={`${styles.simBtn} ${styles.uploadBtn}`}
                        onClick={() => fileInputRef.current?.click()}
                        disabled={uploadStatus === 'uploading'}
                    >
                        {uploadStatus === 'done'
                            ? <CheckCircle size={16} />
                            : <UploadCloud size={16} />}
                        <div className={styles.btnText}>
                            <span className={styles.btnTitle}>
                                {uploadStatus === 'uploading' ? 'Analysing frame…' : uploadStatus === 'done' ? 'Done! Check Debug Log' : 'Upload Image (Instant Test)'}
                            </span>
                            <span className={styles.btnSub}>Skips webcam — runs YOLO on any photo</span>
                        </div>
                    </button>
                </div>

                {mlActive && <div className={styles.lockMsg}>Simulator disabled while ML Engine is active.</div>}
            </div>
        </div>
    );
}
