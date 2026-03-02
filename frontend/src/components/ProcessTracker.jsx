import React from 'react';
import styles from './ProcessTracker.module.css';
import { Target, MessageSquare, Briefcase } from 'lucide-react';

export default function ProcessTracker({ activeApp, intervention }) {
    const isGaming = activeApp?.toLowerCase().includes('pubg') || activeApp?.toLowerCase().includes('game');
    const isCoding = activeApp?.toLowerCase().includes('code');

    const statusIcon = isGaming ? '🎮' : isCoding ? '💻' : '🌐';

    let aiStatus = 'Monitoring cognitive load and processing baseline metrics...';
    if (intervention?.toast_msg) {
        aiStatus = `"${intervention.toast_msg}"`;
    } else if (isGaming) {
        aiStatus = 'Prajwal is locked in. Tracking tilt probability and APM...';
    } else if (isCoding) {
        aiStatus = 'Prajwal is cooking code. Monitoring syntax frustration levels...';
    }

    return (
        <div className={styles.trackerContainer}>
            <div className={styles.header}>
                <Target size={18} color="var(--accent-purple)" />
                <span className={styles.title}>Context Engine (Gemini 2.5)</span>
            </div>

            <div className={styles.content}>
                <div className={styles.appCard}>
                    <div className={styles.appIcon}>{statusIcon}</div>
                    <div className={styles.appInfo}>
                        <span className={styles.appLabel}>Active Application</span>
                        <span className={styles.appName} title={activeApp || 'Detecting...'}>
                            {activeApp || 'Detecting Workspace...'}
                        </span>
                    </div>
                </div>

                <div className={styles.geminiCard}>
                    <MessageSquare size={14} color="var(--text-muted)" style={{ marginTop: 2, flexShrink: 0 }} />
                    <span className={styles.geminiText}>{aiStatus}</span>
                </div>

                <div className={styles.profileRow}>
                    <div className={styles.badge}><Briefcase size={12} color="var(--accent-cyan)" /> ML Engineer / Gamer</div>
                    <div className={styles.badge}>CGPA 9.0</div>
                    <div className={styles.badge}>Recovery: 87%</div>
                </div>
            </div>
        </div>
    );
}
