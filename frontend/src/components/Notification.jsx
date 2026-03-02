import { useState, useEffect, useCallback } from 'react';
import styles from './Notification.module.css';

const TOAST_DURATION = 6000; // ms

/**
 * Notification — Aegis.ai Hype-Man toast system.
 * Shows context-aware, non-intrusive toasts above games.
 * Stacks in top-right corner, auto-dismisses after TOAST_DURATION.
 */
export default function Notification({ intervention }) {
    const [toasts, setToasts] = useState([]);

    const dismiss = useCallback((id) => {
        setToasts((prev) =>
            prev.map((t) => (t.id === id ? { ...t, exiting: true } : t))
        );
        setTimeout(() => {
            setToasts((prev) => prev.filter((t) => t.id !== id));
        }, 400);
    }, []);

    useEffect(() => {
        if (!intervention) return;
        // Only show toast for INTERVENE or MONITOR, not STABLE/NONE resets
        if (intervention.action === 'NONE' && intervention.source === 'reset') return;
        if (!intervention.toast_msg && !intervention.intervention_tip) return;

        const id = Date.now();
        const toast = {
            id,
            exiting: false,
            stressLevel: (intervention.stress_level || 'STABLE').toLowerCase(),
            emoji: intervention.toast_emoji || (
                intervention.stress_level === 'HIGH' ? '🔥' :
                    intervention.stress_level === 'ELEVATED' ? '⚠️' : '✅'
            ),
            title: intervention.stress_level === 'HIGH'
                ? '⚡ Aegis Intervening'
                : intervention.stress_level === 'ELEVATED'
                    ? '👁 Elevated Alert'
                    : '✅ Stable',
            message: intervention.toast_msg || intervention.intervention_tip,
            tip: intervention.intervention_tip,
            activeApp: intervention.active_app || '',
            callTriggered: intervention.call_result?.status === 'initiated',
            callSid: intervention.call_result?.sid,
        };

        setToasts((prev) => [toast, ...prev].slice(0, 5)); // max 5 stacked

        const timer = setTimeout(() => dismiss(id), TOAST_DURATION);
        return () => clearTimeout(timer);
    }, [intervention, dismiss]);

    if (toasts.length === 0) return null;

    return (
        <div className={styles.toastContainer} role="status" aria-live="polite">
            {toasts.map((t) => (
                <div
                    key={t.id}
                    className={`${styles.toast} ${styles[t.stressLevel]} ${t.exiting ? styles.exiting : ''}`}
                    style={{ '--toast-duration': `${TOAST_DURATION}ms` }}
                    onClick={() => dismiss(t.id)}
                    role="alert"
                    aria-label={`Aegis ${t.stressLevel} alert`}
                >
                    {/* Emoji icon */}
                    <div className={styles.toastEmoji} aria-hidden="true">{t.emoji}</div>

                    {/* Body */}
                    <div className={styles.toastBody}>
                        <div className={styles.toastTitle}>{t.title}</div>
                        <div className={styles.toastMessage}>{t.message}</div>

                        {/* Active app context */}
                        {t.activeApp && (
                            <div className={styles.toastMeta}>
                                📍 {t.activeApp}
                            </div>
                        )}

                        {/* Twilio call badge */}
                        {t.callTriggered && (
                            <div className={styles.callBadge}>
                                📞 Calling +91 9110 687 983…
                                {t.callSid && <span style={{ opacity: 0.6 }}> {t.callSid.slice(0, 8)}</span>}
                            </div>
                        )}
                    </div>

                    {/* Close button */}
                    <button
                        className={styles.toastClose}
                        onClick={(e) => { e.stopPropagation(); dismiss(t.id); }}
                        aria-label="Dismiss"
                    >
                        ✕
                    </button>
                </div>
            ))}
        </div>
    );
}
