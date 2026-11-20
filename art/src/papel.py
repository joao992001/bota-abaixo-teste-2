"""Estilo 'papel e giz' (referência do usuário: cenario.png / versoes.png):
formas chapadas sem contorno, borda levemente irregular e textura de tracinhos horizontais."""
import random

from svg import shade


def rough(fid="rough", seed=1, scale=1.2, freq=0.09):
    """Filtro de borda irregular (recorte de papel)."""
    return (f'<filter id="{fid}" x="-10%" y="-10%" width="120%" height="120%">'
            f'<feTurbulence type="fractalNoise" baseFrequency="{freq}" numOctaves="2" seed="{seed}"/>'
            f'<feDisplacementMap in="SourceGraphic" scale="{scale}" xChannelSelector="R" yChannelSelector="G"/></filter>')


def hatch(clip_id, box, base, seed, k=1.0, dens=1.0, light_ratio=0.12, dark=None, light=None):
    """Tracinhos horizontais de giz dentro de clip_id. k = escala (1 = robô em 1x)."""
    x0, y0, x1, y1 = box
    rnd = random.Random(seed)
    dark = dark or shade(base, -0.32)
    light = light or shade(base, 0.35)
    out = [f'<g clip-path="url(#{clip_id})" stroke-linecap="round">']
    y = y0 + rnd.uniform(0, 1.2 * k)
    while y < y1:
        x = x0 - rnd.uniform(0, 8 * k)
        while x < x1:
            x += rnd.uniform(1.5, 9) * k / dens
            ln = rnd.uniform(1.0, 5.5) * k
            col = light if rnd.random() < light_ratio else dark
            out.append(f'<path d="M{x:.2f},{y + rnd.uniform(-0.2, 0.2) * k:.2f} h{ln:.2f}" stroke="{col}" '
                       f'stroke-width="{rnd.uniform(0.32, 0.6) * k:.2f}" stroke-opacity="{rnd.uniform(0.35, 0.8):.2f}"/>')
            x += ln
        y += rnd.uniform(0.9, 1.7) * k
    out.append('</g>')
    return "".join(out)


def shape(sid, d, fill, seed, box, k=1.0, dens=1.0, extra="", dark=None, light=None):
    """Forma chapada + tracinhos de giz recortados nela. d = path SVG."""
    return (f'<clipPath id="{sid}"><path d="{d}"/></clipPath>'
            f'<path d="{d}" fill="{fill}" {extra}/>' + hatch(sid, box, fill, seed, k, dens, dark=dark, light=light))


def rect_d(x, y, w, h, r=0):
    if r <= 0:
        return f"M{x},{y} h{w} v{h} h{-w} Z"
    return (f"M{x + r},{y} H{x + w - r} Q{x + w},{y} {x + w},{y + r} V{y + h - r} Q{x + w},{y + h} {x + w - r},{y + h} "
            f"H{x + r} Q{x},{y + h} {x},{y + h - r} V{y + r} Q{x},{y} {x + r},{y} Z")


def ellipse_d(cx, cy, rx, ry):
    return f"M{cx - rx},{cy} A{rx},{ry} 0 1 0 {cx + rx},{cy} A{rx},{ry} 0 1 0 {cx - rx},{cy} Z"
