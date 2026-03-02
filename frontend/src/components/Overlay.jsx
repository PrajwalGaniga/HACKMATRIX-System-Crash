import { useEffect, useState } from 'react';
import styles from './Overlay.module.css';

/**
 * Overlay — translucent amber tint layer.
 * Sits above everything with pointer-events: none.
 * Activated when intervention.level === "AMBER_SHIFT"
 */
export default function Overlay({ intervention }) {
  const [showBadge, setShowBadge] = useState(false);

  const level = intervention?.level;
  const isAmber = level === 'AMBER_SHIFT';
  const isElevated = level === 'ELEVATED_ALERT';

  useEffect(() => {
    if (isAmber || isElevated) {
      const t = setTimeout(() => setShowBadge(true), 300);
      return () => clearTimeout(t);
    } else {
      setShowBadge(false);
    }
  }, [isAmber, isElevated]);

  const overlayClass = [
    styles.overlay,
    isAmber ? styles.amberActive : '',
    isElevated ? styles.elevatedActive : '',
  ]
    .filter(Boolean)
    .join(' ');

  const badgeClass = [
    styles.badge,
    showBadge ? styles.visible : '',
    isAmber ? styles.amberBadge : styles.elevatedBadge,
  ]
    .filter(Boolean)
    .join(' ');

  const vignetteClass = [
    styles.vignette,
    isAmber ? styles.amberVignette : '',
  ]
    .filter(Boolean)
    .join(' ');

  return (
    <div className={overlayClass} aria-hidden="true">
      <div className={vignetteClass} />
      {(isAmber || isElevated) && (
        <div className={badgeClass}>
          <span className={styles.badgeDot} />
          {isAmber ? '⚡ Aegis Intervening — Amber Shift Active' : '⚠ Elevated Stress — Monitoring'}
        </div>
      )}
    </div>
  );
}
