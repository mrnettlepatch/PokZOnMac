#!/usr/bin/env python3
"""Genera keybindings.mkxp1 (formato v3 de mkxp-z, RGSS1) para Pokémon Z.
Teclado: los valores por defecto de mkxp-z. Mando: mapeado estilo Xbox."""
import struct, sys

# Botones lógicos (Input::ButtonCode de mkxp-z)
DOWN, LEFT, RIGHT, UP = 2, 4, 6, 8
A, B, C, X, Y, Z, L, R = 11, 12, 13, 14, 15, 16, 17, 18
F5 = 25
KEY, CBUTTON, CAXIS = 1, 2, 3
NEG, POS = 0, 1

keyboard = [  # (scancode SDL, botón)
    (80, LEFT), (79, RIGHT), (82, UP), (81, DOWN),
    (44, C), (40, C),            # Espacio, Enter
    (41, B), (98, B), (27, B),   # Esc, Num0, X
    (225, A),                    # Shift izq.
    (7, Z), (20, L), (26, R), (4, X), (22, Y),   # D, Q, W, A, S
    (29, A), (6, C),             # Z, C (RGSS1)
]
pad = [  # (botón SDL del mando, botón)
    (0, C),    # A       -> Aceptar / hablar (mantener: correr)
    (1, B),    # B       -> Atrás / menú
    (2, B),    # X       -> Abrir menú (igual que la X del teclado)
    (6, B),    # Start   -> Abrir menú
    (3, A),    # Y       -> Correr (modo alterno), Megaevolución, ordenar
    (4, F5),   # Back    -> Objeto registrado
    (9, L),    # LB      -> Turbo / página anterior
    (10, R),   # RB      -> Página siguiente
    (7, Y),    # L3      -> Atajo PokéRider
    (8, Z),    # R3      -> Atajo DexNav
    (11, UP), (12, DOWN), (13, LEFT), (14, RIGHT),   # Cruceta
]
axes = [  # (eje, dirección, botón)
    (0, NEG, LEFT), (0, POS, RIGHT), (1, NEG, UP), (1, POS, DOWN),   # Stick izq.
    (4, POS, X),   # LT -> Atajo PokéVial
    (5, POS, Y),   # RT -> Atajo PokéRider
]

recs = []
for sc, t in keyboard: recs.append(struct.pack("<iiii", KEY, sc, 0, t))
for b, t in pad:       recs.append(struct.pack("<iiii", CBUTTON, b, 0, t))
for ax, d, t in axes:  recs.append(struct.pack("<iiii", CAXIS, ax, d, t))
data = struct.pack("<III", 3, 1, len(recs)) + b"".join(recs)
out = sys.argv[1] if len(sys.argv) > 1 else "keybindings.mkxp1"
open(out, "wb").write(data)
print(f"{out}: {len(recs)} asignaciones, {len(data)} bytes")
