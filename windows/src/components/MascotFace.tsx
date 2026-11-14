import React, { useEffect, useState } from 'react';

interface MascotFaceProps {
  size?: number;
  look?: { x: number; y: number };
  mood?: 'idle' | 'happy' | 'sleepy' | 'dragging';
  accent?: string;
}

export const MascotFace: React.FC<MascotFaceProps> = ({
  size = 20,
  look = { x: 0, y: 0 },
  mood = 'idle',
  accent = '#38bdf8',
}) => {
  const [blinking, setBlinking] = useState(false);

  useEffect(() => {
    const id = window.setInterval(() => {
      setBlinking(true);
      window.setTimeout(() => setBlinking(false), 140);
    }, 4200);
    return () => window.clearInterval(id);
  }, []);

  const dx = Math.max(-2.4, Math.min(2.4, look.x * 2.2));
  const dy = Math.max(-1.8, Math.min(1.8, look.y * 1.6));
  const eyeH = blinking || mood === 'sleepy' ? 1.5 : mood === 'happy' ? 3.2 : 5;
  const eyeY = 12.2 + dy + (blinking ? 1.6 : 0);

  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 28 28"
      fill="none"
      style={{
        display: 'block',
        transform: mood === 'dragging' ? 'translateY(-1.5px) scale(1.06)' : undefined,
        transition: 'transform 160ms ease',
        flexShrink: 0,
      }}
    >
      {/* Antenna */}
      <line x1="14" y1="2.8" x2="14" y2="6.2" stroke={accent} strokeWidth="1.7" strokeLinecap="round" />
      <circle cx="14" cy="2.6" r="1.7" fill={accent} />

      {/* Ears */}
      <rect x="2.2" y="11" width="3" height="7" rx="1.5" fill="rgba(255,255,255,0.22)" />
      <rect x="22.8" y="11" width="3" height="7" rx="1.5" fill="rgba(255,255,255,0.22)" />

      {/* Head shell */}
      <rect
        x="4.5"
        y="6"
        width="19"
        height="17.5"
        rx="7.5"
        fill="#1e2430"
        stroke="rgba(255,255,255,0.2)"
        strokeWidth="1"
      />

      {/* Visor */}
      <rect x="6.5" y="9.5" width="15" height="9.2" rx="4.4" fill="#06080d" />

      {/* Eyes */}
      {mood === 'happy' ? (
        <>
          <path
            d={`M ${9.2 + dx} ${14.5 + dy} Q ${10.8 + dx} ${11.8 + dy} ${12.4 + dx} ${14.5 + dy}`}
            stroke={accent}
            strokeWidth="1.9"
            strokeLinecap="round"
          />
          <path
            d={`M ${15.6 + dx} ${14.5 + dy} Q ${17.2 + dx} ${11.8 + dy} ${18.8 + dx} ${14.5 + dy}`}
            stroke={accent}
            strokeWidth="1.9"
            strokeLinecap="round"
          />
        </>
      ) : (
        <>
          <rect
            x={9.3 + dx}
            y={eyeY}
            width="3.1"
            height={eyeH}
            rx="1.5"
            fill={accent}
            style={{ transition: 'height 90ms ease' }}
          />
          <rect
            x={15.6 + dx}
            y={eyeY}
            width="3.1"
            height={eyeH}
            rx="1.5"
            fill={accent}
            style={{ transition: 'height 90ms ease' }}
          />
        </>
      )}
    </svg>
  );
};
