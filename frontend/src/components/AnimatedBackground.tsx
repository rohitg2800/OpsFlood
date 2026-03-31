import React, { useEffect, useRef } from 'react';

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

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const frameDuration = reducedMotion ? 1000 / 12 : 1000 / 24;
    let lastFrameTime = 0;

    // Set canvas size
    const resizeCanvas = () => {
      canvas.width = window.innerWidth;
      canvas.height = window.innerHeight;
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
      const count = Math.floor(rainIntensity * (reducedMotion ? 0.3 : 0.55));
      for (let i = 0; i < count; i++) {
        raindrops.push({
          x: Math.random() * canvas.width,
          y: Math.random() * canvas.height,
          length: Math.random() * 20 + 10,
          speed: Math.random() * 5 + 8,
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

      ctx.clearRect(0, 0, canvas.width, canvas.height);

      // Draw gradient background based on severity
      const gradient = ctx.createLinearGradient(0, 0, 0, canvas.height);
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
      ctx.fillRect(0, 0, canvas.width, canvas.height);

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
        if (drop.y > canvas.height) {
          // Create ripple at bottom
          if (!reducedMotion && Math.random() > 0.9) {
            ripples.push({
              x: drop.x,
              y: canvas.height - 20,
              radius: 0,
              maxRadius: Math.random() * 30 + 20,
              opacity: 0.5,
              speed: Math.random() * 0.5 + 0.5,
            });
          }
          drop.y = -drop.length;
          drop.x = Math.random() * canvas.width;
        }
        if (drop.x > canvas.width) drop.x = 0;
        if (drop.x < 0) drop.x = canvas.width;
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
          ctx.fillRect(0, 0, canvas.width, canvas.height);
          lightningOpacity -= 0.05;
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
  }, [severity, rainIntensity, showLightning]);

  return (
    <canvas
      ref={canvasRef}
      className="fixed inset-0 pointer-events-none z-0"
      style={{ opacity: 0.6 }}
    />
  );
};

export default AnimatedBackground;
