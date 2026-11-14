import React from 'react';
import brandMarkPng from '../assets/brand-mark.png';

interface BrandMarkProps {
  size?: number;
  light?: boolean;
  badge?: boolean;
}

export const BrandMark: React.FC<BrandMarkProps> = ({
  size = 24,
  light = true,
  badge = false,
}) => {
  const imgStyle: React.CSSProperties = {
    width: badge ? size * 0.72 : size,
    height: 'auto',
    display: 'block',
    filter: light ? 'brightness(0) invert(1)' : 'brightness(0)',
    objectFit: 'contain',
  };

  if (badge) {
    return (
      <div
        style={{
          width: size,
          height: size,
          borderRadius: Math.round(size * 0.26),
          background: 'linear-gradient(145deg, #1b1d24 0%, #0b0c10 58%, #000000 100%)',
          border: '1px solid rgba(255,255,255,0.12)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          boxShadow: '0 8px 24px rgba(0,0,0,0.45)',
          flexShrink: 0,
        }}
      >
        <img src={brandMarkPng} alt="Vorssaint" style={imgStyle} draggable={false} />
      </div>
    );
  }

  return <img src={brandMarkPng} alt="Vorssaint" style={imgStyle} draggable={false} />;
};
