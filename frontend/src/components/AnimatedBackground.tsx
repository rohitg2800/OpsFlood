import React, { useEffect, useMemo, useRef } from 'react';
import { isLiteMotionDevice } from '../utils/performance';

interface AnimatedBackgroundProps {
  severity?: 'LOW' | 'MODERATE' | 'SEVERE' | 'CRITICAL';
  rainIntensity?: number; // 0-100
  showLightning?: boolean;
}

export const AnimatedBackground: React.FC<AnimatedBackgroundProps> = ({
  severity = 'LOW',
  rainIntensity = 30,
  showLightning = false,
}) => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const animationRef = useRef<number | null>(null);
  const liteMotion = useMemo(() => isLiteMotionDevice(), []);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const frameDuration = liteMotion ? 1000 / 18 : 1000 / 30;
    const resolutionScale = liteMotion ? 0.58 : 0.82;
    const viewport = { width: window.innerWidth, height: window.innerHeight };
    let lastFrameTime = 0;

    // Set canvas size
    const resizeCanvas = () => {
      viewport.width = window.innerWidth;
      viewport.height = window.innerHeight;
      canvas.width = Math.max(1, Math.floor(viewport.width * resolutionScale));
      canvas.height = Math.max(1, Math.floor(viewport.height * resolutionScale));
      canvas.style.width = `${viewport.width}px`;
      canvas.style.height = `${viewport.height}px`;
    };
    resizeCanvas();
    window.addEventListener('resize', resizeCanvas);

    // Rain particles
    const raindrops: Array<{
      x: number;
      y: number;
      length: number;
      speed: number;
      opacity: number;
      wind: number;
    }> = [];

    // Initialize raindrops
    const initRaindrops = () => {
      raindrops.length = 0;
      const count = Math.floor(rainIntensity * (liteMotion ? 0.2 : 0.34));
      for (let i = 0; i < count; i++) {
        raindrops.push({
          x: Math.random() * viewport.width,
          y: Math.random() * viewport.height,
          length: Math.random() * (liteMotion ? 14 : 20) + 8,
          speed: Math.random() * (liteMotion ? 3.6 : 5) + (liteMotion ? 6 : 8),
          opacity: Math.random() * 0.5 + 0.2,
          wind: Math.random() * 2 - 1,
        });
      }
    };
    initRaindrops();

    // Water ripples
    const ripples: Array<{
      x: number;
      y: number;
      radius: number;
      maxRadius: number;
      opacity: number;
      speed: number;
    }> = [];

    // Lightning flash
    let lightningOpacity = 0;
    let lightningTimer = 0;

    // Animation loop
    const animate = (timestamp: number) => {
      animationRef.current = requestAnimationFrame(animate);

      if (document.hidden) return;
      if (timestamp - lastFrameTime < frameDuration) return;
      lastFrameTime = timestamp;

      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      ctx.setTransform(resolutionScale, 0, 0, resolutionScale, 0, 0);

      // Draw gradient background based on severity
      const gradient = ctx.createLinearGradient(0, 0, 0, viewport.height);
      switch (severity) {
        case 'CRITICAL':
          gradient.addColorStop(0, 'rgba(107, 0, 15, 0.3)');
          gradient.addColorStop(0.5, 'rgba(176, 0, 32, 0.2)');
          gradient.addColorStop(1, 'rgba(255, 0, 55, 0.1)');
          break;
        case 'SEVERE':
          gradient.addColorStop(0, 'rgba(107, 0, 15, 0.25)');
          gradient.addColorStop(0.5, 'rgba(176, 0, 32, 0.15)');
          gradient.addColorStop(1, 'rgba(245, 158, 11, 0.1)');
          break;
        case 'MODERATE':
          gradient.addColorStop(0, 'rgba(245, 158, 11, 0.15)');
          gradient.addColorStop(0.5, 'rgba(255, 176, 0, 0.1)');
          gradient.addColorStop(1, 'rgba(0, 0, 0, 0.05)');
          break;
        default:
          gradient.addColorStop(0, 'rgba(0, 0, 0, 0.1)');
          gradient.addColorStop(0.5, 'rgba(0, 0, 0, 0.05)');
          gradient.addColorStop(1, 'rgba(0, 0, 0, 0)');
      }
      ctx.fillStyle = gradient;
      ctx.fillRect(0, 0, viewport.width, viewport.height);

      // Draw and update raindrops
      raindrops.forEach((drop) => {
        ctx.beginPath();
        ctx.moveTo(drop.x, drop.y);
        ctx.lineTo(
          drop.x + drop.wind * drop.length * 0.1,
          drop.y + drop.length
        );
        ctx.strokeStyle = `rgba(200, 220, 255, ${drop.opacity})`;
        ctx.lineWidth = 1;
        ctx.stroke();

        // Update position
        drop.y += drop.speed;
        drop.x += drop.wind;

        // Reset if off screen
        if (drop.y > viewport.height) {
          // Create ripple at bottom
          if (!liteMotion && Math.random() > 0.94) {
            ripples.push({
              x: drop.x,
              y: viewport.height - 20,
              radius: 0,
              maxRadius: Math.random() * 30 + 20,
              opacity: 0.5,
              speed: Math.random() * 0.5 + 0.5,
            });
          }
          drop.y = -drop.length;
          drop.x = Math.random() * viewport.width;
        }
        if (drop.x > viewport.width) drop.x = 0;
        if (drop.x < 0) drop.x = viewport.width;
      });

      // Draw and update ripples
      for (let i = ripples.length - 1; i >= 0; i--) {
        const ripple = ripples[i];
        ctx.beginPath();
        ctx.arc(ripple.x, ripple.y, ripple.radius, 0, Math.PI * 2);
        ctx.strokeStyle = `rgba(200, 220, 255, ${ripple.opacity})`;
        ctx.lineWidth = 1;
        ctx.stroke();

        ripple.radius += ripple.speed;
        ripple.opacity -= 0.01;

        if (ripple.opacity <= 0 || ripple.radius >= ripple.maxRadius) {
          ripples.splice(i, 1);
        }
      }

      // Lightning effect for critical severity
      if (showLightning && severity === 'CRITICAL') {
        lightningTimer++;
        if (lightningTimer > 200 && Math.random() > 0.995) {
          lightningOpacity = 0.8;
          lightningTimer = 0;
        }

        if (lightningOpacity > 0) {
          ctx.fillStyle = `rgba(255, 255, 255, ${lightningOpacity})`;
          ctx.fillRect(0, 0, viewport.width, viewport.height);
          lightningOpacity -= liteMotion ? 0.08 : 0.05;
        }
      }

    };

    animationRef.current = requestAnimationFrame(animate);

    return () => {
      window.removeEventListener('resize', resizeCanvas);
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current);
      }
    };
  }, [liteMotion, severity, rainIntensity, showLightning]);

  return (
    <canvas
      ref={canvasRef}
      className="fixed inset-0 pointer-events-none z-0 will-change-transform"
      style={{ opacity: liteMotion ? 0.36 : 0.54, transform: 'translateZ(0)' }}
    />
  );
};

export default AnimatedBackground;
