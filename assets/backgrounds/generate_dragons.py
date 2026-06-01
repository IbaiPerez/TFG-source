#!/usr/bin/env python3
"""
Genera imagen de dragones y monstruos marinos en estilo mapa antiguo.
Uso: python generate_dragons.py
Salida: dragons_overlay.png (1920x1920)
"""

from PIL import Image, ImageDraw, ImageFilter
import random
import math

# Configuración
IMAGE_SIZE = 1920
OUTPUT_PATH = "dragons_overlay.png"

# Crear imagen transparente
img = Image.new('RGBA', (IMAGE_SIZE, IMAGE_SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img, 'RGBA')

# Color tinta antigua (marrón oscuro)
INK_COLOR = (80, 60, 40, 200)
INK_LIGHT = (120, 100, 80, 150)

def draw_dragon(draw, x, y, size, rotation=0):
    """Dibuja un dragón en estilo antiguo"""
    # Cabeza
    head_r = int(size * 0.3)
    draw.ellipse([x-head_r, y-head_r, x+head_r, y+head_r], outline=INK_COLOR, width=3)

    # Cuernos
    horn_len = int(size * 0.4)
    draw.line([x-head_r//2, y-head_r, x-head_r//2-horn_len, y-head_r-horn_len], INK_COLOR, width=2)
    draw.line([x+head_r//2, y-head_r, x+head_r//2+horn_len, y-head_r-horn_len], INK_COLOR, width=2)

    # Ojo
    draw.ellipse([x-5, y-10, x+5, y], outline=INK_COLOR, width=1)

    # Cuerpo (serpentín)
    body_points = []
    for i in range(5):
        bx = x + (i-2) * size * 0.25
        by = y + i * size * 0.3
        body_points.append((bx, by))
    draw.line(body_points, INK_COLOR, width=4)

    # Cola
    tail_x = body_points[-1][0]
    tail_y = body_points[-1][1]
    draw.line([tail_x, tail_y, tail_x+size*0.4, tail_y+size*0.5], INK_COLOR, width=3)

    # Alas
    for wing_x_offset in [-size*0.3, size*0.3]:
        wing_x = x + wing_x_offset
        wing_y = y + size*0.2
        # Forma de ala
        wing_points = [
            (wing_x, wing_y),
            (wing_x + wing_x_offset*0.8, wing_y - size*0.3),
            (wing_x + wing_x_offset*1.2, wing_y - size*0.1),
        ]
        draw.polygon(wing_points, outline=INK_COLOR, width=2)

def draw_sea_monster(draw, x, y, size):
    """Dibuja un monstruo marino"""
    # Cabeza grande
    head_r = int(size * 0.35)
    draw.ellipse([x-head_r, y-head_r, x+head_r, y+head_r], outline=INK_COLOR, width=3)

    # Ojos
    draw.ellipse([x-head_r//2-5, y-10, x-head_r//2+5, y], outline=INK_COLOR, width=2)
    draw.ellipse([x+head_r//2-5, y-10, x+head_r//2+5, y], outline=INK_COLOR, width=2)

    # Tentáculos
    tentacle_count = random.randint(4, 6)
    for i in range(tentacle_count):
        angle = (2 * math.pi * i) / tentacle_count
        tent_x = x + math.cos(angle) * head_r * 1.5
        tent_y = y + math.sin(angle) * head_r * 1.5

        # Dibujar tentáculo ondulado
        points = [(x, y)]
        for j in range(4):
            px = x + math.cos(angle) * (j+1) * size * 0.25
            py = y + math.sin(angle) * (j+1) * size * 0.25
            points.append((px, py))
        draw.line(points, INK_COLOR, width=3)

    # Boca
    draw.arc([x-head_r//2, y-head_r//2, x+head_r//2, y+head_r//2], 0, 180, INK_COLOR, width=2)

def draw_sea_serpent(draw, x, y, size):
    """Dibuja una serpiente marina"""
    # Cuerpo ondulado
    points = []
    for i in range(8):
        px = x + i * size * 0.2
        py = y + math.sin(i * 0.8) * size * 0.3
        points.append((px, py))
    draw.line(points, INK_COLOR, width=4)

    # Cabeza
    head_size = int(size * 0.25)
    draw.ellipse([points[0][0]-head_size, points[0][1]-head_size,
                  points[0][0]+head_size, points[0][1]+head_size], outline=INK_COLOR, width=2)

    # Escamas decorativas
    for i, point in enumerate(points[1:]):
        scale_y_offset = -size * 0.15
        draw.arc([point[0]-5, point[1]+scale_y_offset-5,
                  point[0]+5, point[1]+scale_y_offset+5], 0, 180, INK_LIGHT, width=1)

def draw_decorative_flourish(draw, x, y, size):
    """Dibuja ornamentos decorativos (círculos, líneas, etc.)"""
    # Espiral
    points = []
    for angle in range(0, 360, 10):
        rad = math.radians(angle)
        r = angle / 360 * size
        px = x + r * math.cos(rad)
        py = y + r * math.sin(rad)
        points.append((px, py))

    if len(points) > 1:
        draw.line(points, INK_LIGHT, width=1)

    # Pequeños círculos decorativos
    for i in range(3):
        circle_r = random.randint(2, 5)
        cx = x + random.randint(-size, size)
        cy = y + random.randint(-size, size)
        draw.ellipse([cx-circle_r, cy-circle_r, cx+circle_r, cy+circle_r], outline=INK_LIGHT, width=1)

# Posicionar criaturas alrededor del pergamino
# El pergamino (40x40 en unidades Godot) está en el centro aproximadamente

# Dragones en las esquinas
dragon_positions = [
    (250, 250, 150),      # Superior izquierda
    (1670, 250, 150),     # Superior derecha
    (250, 1670, 150),     # Inferior izquierda
    (1670, 1670, 150),    # Inferior derecha
]

for dx, dy, dsize in dragon_positions:
    draw_dragon(draw, dx, dy, dsize)

# Monstruos marinos en los lados
monster_positions = [
    (960, 150, 140),      # Superior
    (960, 1770, 140),     # Inferior
    (150, 960, 140),      # Izquierda
    (1770, 960, 140),     # Derecha
]

for mx, my, msize in monster_positions:
    draw_sea_monster(draw, mx, my, msize)

# Serpientes marinas adicionales
serpent_positions = [
    (600, 300, 120),
    (1320, 300, 120),
    (300, 1620, 120),
    (1620, 1620, 120),
]

for sx, sy, ssize in serpent_positions:
    draw_sea_serpent(draw, sx, sy, ssize)

# Ornamentos decorativos dispersos
for _ in range(8):
    fx = random.randint(400, 1520)
    fy = random.randint(400, 1520)
    draw_decorative_flourish(draw, fx, fy, random.randint(30, 60))

# Aplicar efecto de antigüedad (desenfoque muy leve y variaciones)
# img = img.filter(ImageFilter.GaussianBlur(radius=0.5))

# Guardar imagen
img.save(OUTPUT_PATH, 'PNG')
print("[OK] Imagen generada: " + OUTPUT_PATH)
print("  Tamaño: {}x{}".format(IMAGE_SIZE, IMAGE_SIZE))
print("  Dragones: 4")
print("  Monstruos marinos: 4")
print("  Serpientes marinas: 4")
print("  Ornamentos: 8")
