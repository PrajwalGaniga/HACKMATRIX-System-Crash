import styles from './StatusBar.module.css';

const EMPTY_STATE = {
    stress_level: null,
    action: null,
    level: null,
    confidence: null,
    reasoning: null,
    intervention_tip: null,
    au_data: null,
};

function getLevelKey(stress_level) {
    if (!stress_level) return 'idle';
    return stress_level.toLowerCase();
}

export default function StatusBar({ intervention }) {
    const data = intervention || EMPTY_STATE;
    const levelKey = getLevelKey(data.stress_level);

    const auData = data.au_data || {};
    const au4 = auData.au4 !== undefined ? Number(auData.au4).toFixed(2) : '--';
    const au23 = auData.au23 !== undefined ? Number(auData.au23).toFixed(2) : '--';
    const blink = auData.blink_rate !== undefined ? auData.blink_rate : '--';

    const getAu23Class = () => {
        const v = parseFloat(au23);
        if (isNaN(v)) return '';
        if (v > 0.7) return styles.danger;
        if (v > 0.5) return styles.warn;
        return styles.ok;
    };

    const getBlinkClass = () => {
        const v = parseInt(blink);
        if (isNaN(v)) return '';
        if (v < 10) return styles.danger;
        if (v < 12) return styles.warn;
        return styles.ok;
    };

    const containerClass = [styles.statusBar, levelKey !== 'idle' ? styles[levelKey] : '']
        .filter(Boolean)
        .join(' ');

    const chipClass = [styles.levelChip, styles[levelKey]].join(' ');
    const reasoningClass = [styles.reasoning, levelKey !== 'idle' ? styles[levelKey] : ''].join(' ');

    return (
        <div className={containerClass}>
            {/* Header */}
            <div className={styles.header}>
                <div className={styles.title}>
                    <span className={styles.titleIcon}>🧠</span>
                    <span className={styles.titleText}>Gemini Cognitive Engine</span>
                </div>
                <div className={chipClass}>
                    {data.stress_level
                        ? `${data.stress_level}${data.confidence != null ? ` · ${(data.confidence * 100).toFixed(0)}%` : ''}`
                        : 'IDLE'}
                </div>
            </div>

            {/* AU Readings */}
            <div className={styles.readings}>
                <div className={styles.reading}>
                    <div className={styles.readingLabel}>AU4 Brow</div>
                    <div className={styles.readingValue}>{au4}</div>
                </div>
                <div className={styles.reading}>
                    <div className={styles.readingLabel}>AU23 Lip</div>
                    <div className={`${styles.readingValue} ${getAu23Class()}`}>{au23}</div>
                </div>
                <div className={styles.reading}>
                    <div className={styles.readingLabel}>Blink/min</div>
                    <div className={`${styles.readingValue} ${getBlinkClass()}`}>{blink}</div>
                </div>
            </div>

            {/* Reasoning + Tip */}
            {data.reasoning ? (
                <div className={reasoningClass}>
                    {data.reasoning}
                    {data.intervention_tip && (
                        <div className={styles.tip}>💬 "{data.intervention_tip}"</div>
                    )}
                </div>
            ) : (
                <div className={styles.idle}>
                    ⏳ Awaiting biosignal data… Click{' '}
                    <strong style={{ color: 'var(--accent-amber)' }}>Simulate Stress</strong> to begin.
                </div>
            )}
        </div>
    );
}
