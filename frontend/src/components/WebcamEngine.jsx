import React, { useRef, useEffect, useCallback, useState } from 'react';

const BACKEND_URL = 'http://127.0.0.1:8000';
const FPS = 0.5; // Smart-sampling: 1 frame every 2 seconds

/**
 * WebcamEngine — Headless component.
 * When `active` becomes true:
 *   1. Requests browser camera permission (triggers the OS prompt).
 *   2. Starts drawing frames to a hidden canvas at `FPS` rate.
 *   3. POSTs base64 frames to /api/infer-frame.
 *   4. Calls `onTelemetry(data)` with the AU response.
 *   5. Calls `onLog({level, msg})` for the Debug Console.
 */
export default function WebcamEngine({ active, onTelemetry, onLog, onStreamReady }) {
    const videoRef = useRef(null);
    const canvasRef = useRef(null);
    const streamRef = useRef(null);
    const intervalRef = useRef(null);
    const mountedRef = useRef(true);
    const noFaceCountRef = useRef(0);
    const [permissionState, setPermissionState] = useState('idle'); // idle | requesting | granted | denied

    const stopStream = useCallback(() => {
        clearInterval(intervalRef.current);
        intervalRef.current = null;
        if (streamRef.current) {
            streamRef.current.getTracks().forEach(t => t.stop());
            streamRef.current = null;
        }
        if (videoRef.current) videoRef.current.srcObject = null;
        setPermissionState('idle');
        onStreamReady?.(null);
        onLog?.({ level: 'warn', msg: '🛑 Webcam stream stopped.' });
    }, [onLog, onStreamReady]);

    const sendFrame = useCallback(async () => {
        if (!videoRef.current || !canvasRef.current || !mountedRef.current) return;
        const video = videoRef.current;
        const canvas = canvasRef.current;
        if (video.readyState < 2) return; // Not yet playing

        const ctx = canvas.getContext('2d');
        canvas.width = 320;
        canvas.height = 240;
        ctx.drawImage(video, 0, 0, 320, 240);
        const b64 = canvas.toDataURL('image/jpeg', 0.65);

        try {
            const res = await fetch(`${BACKEND_URL}/api/infer-frame`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ image_b64: b64 }),
                signal: AbortSignal.timeout(3000), // 3s timeout per frame
            });
            if (!res.ok) return;
            const data = await res.json();

            if (data.error) {
                noFaceCountRef.current++;
                if (noFaceCountRef.current % 30 === 1) {
                    onLog?.({ level: 'warn', msg: `⚠️ Inference error: ${data.error}` });
                }
                return;
            }

            // Reset no-face counter on successful detection
            if ((data.au4 + data.au23 + data.au7) > 0.05) {
                noFaceCountRef.current = 0;
            } else {
                noFaceCountRef.current++;
                // Log every 5 seconds of no-face
                if (noFaceCountRef.current % (FPS * 5) === 1) {
                    onLog?.({ level: 'system', msg: `👁 No face in frame — position yourself in front of camera. (${noFaceCountRef.current} misses)` });
                }
            }

            if (data.source === 'fail_safe') {
                onLog?.({ level: 'fallback', msg: `🚨 FAIL-SAFE ACTIVE — Model unavailable. Injecting stress payload. AU23=${(data.au23 * 100).toFixed(0)}%` });
            }

            onTelemetry?.(data);
        } catch (err) {
            if (err.name !== 'AbortError') {
                // Silently swallow — avoids console flood. Log once every ~10s
                if (noFaceCountRef.current % (FPS * 10) === 0) {
                    onLog?.({ level: 'error', msg: `📡 Frame send failed: ${err.message}` });
                }
                noFaceCountRef.current++;
            }
        }
    }, [onTelemetry, onLog]);

    useEffect(() => {
        mountedRef.current = true;

        if (!active) {
            stopStream();
            return;
        }

        const startStream = async () => {
            setPermissionState('requesting');
            onLog?.({ level: 'info', msg: '🎥 Requesting camera permission from browser...' });

            try {
                const stream = await navigator.mediaDevices.getUserMedia({
                    video: {
                        width: { ideal: 640 },
                        height: { ideal: 480 },
                        facingMode: 'user',
                        frameRate: { ideal: 15 },
                    }
                });

                if (!mountedRef.current) {
                    stream.getTracks().forEach(t => t.stop());
                    return;
                }

                streamRef.current = stream;
                setPermissionState('granted');
                onStreamReady?.(stream);
                onLog?.({ level: 'success', msg: `✅ Camera permission granted — ${stream.getVideoTracks()[0].label}` });
                onLog?.({ level: 'info', msg: `📐 Smart-sampling: Sending 1 frame every 2s to /api/infer-frame. YOLO running...` });

                if (videoRef.current) {
                    videoRef.current.srcObject = stream;
                    await videoRef.current.play();
                }

                // Start frame capture loop
                intervalRef.current = setInterval(sendFrame, 1000 / FPS);

            } catch (err) {
                setPermissionState('denied');
                onLog?.({ level: 'error', msg: `❌ Camera denied: ${err.message}. Please allow camera access in browser settings.` });
            }
        };

        startStream();

        return () => {
            mountedRef.current = false;
            clearInterval(intervalRef.current);
        };
    }, [active, sendFrame, stopStream, onLog]);

    return (
        <>
            <video ref={videoRef} style={{ display: 'none' }} muted playsInline />
            <canvas ref={canvasRef} style={{ display: 'none' }} />

            {/* Show camera status overlay if there is an issue */}
            {active && permissionState === 'denied' && (
                <div style={{
                    position: 'fixed', top: 70, right: 20, zIndex: 9000,
                    background: 'rgba(252, 129, 129, 0.15)',
                    border: '1px solid rgba(252, 129, 129, 0.5)',
                    borderRadius: 10, padding: '12px 18px',
                    color: '#FC8181', fontSize: '0.75rem',
                    fontFamily: 'var(--font-mono)', maxWidth: 280,
                }}>
                    ❌ Camera access denied.
                    <br />Open browser settings → Site Settings → Camera → Allow
                </div>
            )}
            {active && permissionState === 'requesting' && (
                <div style={{
                    position: 'fixed', top: 70, right: 20, zIndex: 9000,
                    background: 'rgba(99, 179, 237, 0.1)',
                    border: '1px solid rgba(99, 179, 237, 0.4)',
                    borderRadius: 10, padding: '12px 18px',
                    color: '#63B3ED', fontSize: '0.75rem',
                    fontFamily: 'var(--font-mono)',
                }}>
                    🎥 Requesting camera permission...
                </div>
            )}
        </>
    );
}
