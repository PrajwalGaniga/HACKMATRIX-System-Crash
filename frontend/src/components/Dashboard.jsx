import { useEffect, useState } from 'react';
import styles from './Dashboard.module.css';

const BACKEND_URL = 'http://localhost:8000';

export default function Dashboard() {
    const [user, setUser] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    useEffect(() => {
        const fetchUser = async () => {
            try {
                const res = await fetch(`${BACKEND_URL}/api/user`);
                if (!res.ok) throw new Error(`HTTP ${res.status}`);
                const data = await res.json();
                setUser(data);
            } catch (err) {
                console.error('Failed to fetch user:', err);
                setError(err.message);
                // Fallback to mock data
                setUser({
                    name: 'Prajwal',
                    cgpa: 9.0,
                    interests: ['React', 'ML', 'E-Sports', 'AI'],
                    role: 'Professional Gamer / ML Engineer',
                    recovery_score: 87,
                    blink_normalization: 76,
                    sessions_today: 4,
                    tilt_events_avoided: 12,
                });
            } finally {
                setLoading(false);
            }
        };
        fetchUser();
    }, []);

    if (loading) {
        return (
            <div className={styles.dashboard}>
                <div className={styles.loading}>
                    Loading profile
                    <span className={styles.loadingDot}>.</span>
                    <span className={styles.loadingDot}>.</span>
                    <span className={styles.loadingDot}>.</span>
                </div>
            </div>
        );
    }

    return (
        <div className={styles.dashboard}>
            {/* Header */}
            <div className={styles.sectionHeader}>
                <span className={styles.sectionIcon}>👤</span>
                <span className={styles.sectionTitle}>Athlete Profile</span>
            </div>

            {/* Avatar + Identity */}
            <div className={styles.profileRow}>
                <div className={styles.avatar}>🎮</div>
                <div className={styles.profileInfo}>
                    <div className={styles.profileName}>{user.name}</div>
                    <div className={styles.profileRole}>{user.role}</div>
                </div>
            </div>

            {/* Stats Grid */}
            <div className={styles.statsGrid}>
                <div className={styles.statCard}>
                    <div className={styles.statLabel}>Academic CGPA</div>
                    <div className={`${styles.statValue} ${styles.blue}`}>{user.cgpa}</div>
                </div>
                <div className={styles.statCard}>
                    <div className={styles.statLabel}>Recovery Score</div>
                    <div className={`${styles.statValue} ${styles.green}`}>{user.recovery_score}%</div>
                </div>
                <div className={styles.statCard}>
                    <div className={styles.statLabel}>Blink Normalized</div>
                    <div className={`${styles.statValue} ${styles.amber}`}>{user.blink_normalization}%</div>
                </div>
                <div className={styles.statCard}>
                    <div className={styles.statLabel}>Tilts Avoided</div>
                    <div className={`${styles.statValue} ${styles.purple}`}>{user.tilt_events_avoided}</div>
                </div>
            </div>

            {/* Sessions Today */}
            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontFamily: 'var(--font-mono)' }}>
                🕹️ {user.sessions_today} Aegis sessions active today
                {error && <span style={{ color: 'var(--accent-amber)', marginLeft: 8 }}>(offline mode)</span>}
            </div>

            {/* Interests */}
            <div className={styles.interestsRow}>
                {(user.interests || []).map((interest) => (
                    <span key={interest} className={styles.tag}>{interest}</span>
                ))}
            </div>
        </div>
    );
}
