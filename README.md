# Tic-Tac-Toe en ensamblador 8086

Juego de Tic-Tac-Toe (gato) para dos jugadores, en modo texto, escrito en ensamblador 8086 para **Emu8086**.
Proyecto 2 de Arquitectura de Computadoras (EIF205), Escuela de Informática, Universidad Nacional.

**Integrantes:** Simon Canet Porras - Johan Jafeth Zuñiga Rodriguez - Jeremy Calderon Quesada

## Cómo ejecutarlo

1. Abrir **Emu8086**.
2. `File > Open` y elegir `tic_tac_toe.asm`.
3. Pulsar **Emulate** y luego **Run**.
4. Dar clic en la ventana de pantalla para que reciba el teclado.

## Cómo se juega

- X empieza y los jugadores se turnan en el mismo teclado.
- Se marca una casilla con las teclas `1` a `9` (el número aparece en las casillas vacías).
- Gana quien alinee 3 fichas en fila, columna o diagonal.
- `ESC` vuelve a la pantalla de título. Al terminar un juego, `R` reinicia sin cerrar el emulador.

## Puntuación

| Resultado | Puntos |
|---|---|
| Victoria | +3 |
| Empate | +1 para cada jugador |

El marcador se acumula entre juegos y el **High Score** guarda el mayor puntaje alcanzado mientras el programa sigue abierto.

## Archivos

| Archivo | Contenido |
|---|---|
| `tic_tac_toe.asm` | Código fuente del juego |
| `README.md` | Este archivo |

## Créditos

- Estructura de pantallas inspirada en proyectos públicos de Tic-Tac-Toe en ensamblador 8086.
