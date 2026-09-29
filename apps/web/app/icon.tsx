/**
 * The favicon, generated from the mark rather than shipped as a binary.
 *
 * Three squares is the contribution grid reduced to its atom, and drawing it
 * here means the tab icon can never drift out of step with the palette — it
 * reads the same values everything else does.
 */
import { ImageResponse } from 'next/og';

export const size = { width: 32, height: 32 };
export const contentType = 'image/png';

export default function Icon() {
  const square = (background: string) => ({
    position: 'absolute' as const,
    width: 12,
    height: 12,
    display: 'flex',
    background,
  });

  return new ImageResponse(
    (
      <div
        style={{
          width: '100%',
          height: '100%',
          display: 'flex',
          position: 'relative',
          background: '#09090b',
        }}
      >
        <div style={{ ...square('#3fb950'), left: 2, top: 17 }} />
        <div style={{ ...square('#ffa657'), left: 17, top: 17 }} />
        <div style={{ ...square('#58a6ff'), left: 9.5, top: 3 }} />
      </div>
    ),
    size,
  );
}
