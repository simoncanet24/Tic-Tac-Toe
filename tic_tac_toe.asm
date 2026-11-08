; ====================================================================
;  TIC-TAC-TOE (GATO) - Dos jugadores - Modo texto para Emu8086 (8086)
;  Curso : Arquitectura de Computadoras (EIF205) - Universidad Nacional
;  Tarea : Proyecto 2 - Implementacion de un juego en ensamblador
;
;  REGLAS
;    - X empieza. Los jugadores se turnan en el mismo teclado.
;    - Se marca una casilla con las teclas 1 al 9.
;    - Gana quien alinee 3 fichas (fila, columna o diagonal).
;
;  PUNTUACION
;    - Victoria: +3 puntos      Empate: +1 punto para cada jugador
;    - El marcador se acumula entre juegos mientras el programa corre.
;    - HIGH SCORE: el mayor puntaje alcanzado por cualquier jugador.
;
;  CONTROLES
;    1..9 : marcar casilla      ESC : volver al titulo
; ====================================================================

.model small
.stack 200h

; --------------------------------------------------------------------
;  CONSTANTES (equ no ocupa memoria: el ensamblador las sustituye)
; --------------------------------------------------------------------
BOARD_ROW    equ 7           ; fila de pantalla de la primera linea de casillas
BOARD_COL    equ 31          ; columna de pantalla de la primera marca
PTS_WIN      equ 3
PTS_DRAW     equ 1

CELL_EMPTY   equ 0
MARK_X       equ 1
MARK_O       equ 2

RES_NONE     equ 0           ; resultado de un juego
RES_X        equ 1
RES_O        equ 2
RES_DRAW     equ 3

; --------------------------------------------------------------------
;  MACROS
; --------------------------------------------------------------------

; Guarda / restaura registros de uso general
SaveRegs MACRO
    push ax
    push bx
    push cx
    push dx
ENDM

RestoreRegs MACRO
    pop dx
    pop cx
    pop bx
    pop ax
ENDM

; Mueve el cursor de texto: INT 10h, AH=02h, BH=pagina, DH=fila, DL=columna
SetCursor MACRO row, col
    mov ah, 02h
    mov bh, 0
    mov dh, row
    mov dl, col
    int 10h
ENDM

; Imprime una cadena con color en (fila, columna) con el procedimiento DrawStr
PrintAt MACRO row, col, attr, msg
    mov dh, row
    mov dl, col
    mov bl, attr
    mov si, offset msg
    call DrawStr
ENDM

; --------------------------------------------------------------------
;  SEGMENTO DE DATOS
; --------------------------------------------------------------------
.data
; ---- Tablero: 9 casillas en orden de filas (0..8) ----
;      0 = vacia, 1 = X, 2 = O
board        db 9 dup(0)

; ---- Estado del juego ----
turn         db 1            ; de quien es el turno (MARK_X / MARK_O)
moves        db 0            ; jugadas hechas (9 = tablero lleno)
result       db 0            ; RES_*
quitFlag     db 0            ; 1 = el jugador pidio volver al titulo

; ---- Puntajes (se conservan entre juegos) ----
scoreX       dw 0
scoreO       dw 0
highScore    dw 0

; ---- Las 8 lineas ganadoras (3 casillas cada una) ----
winLines     db 0,1,2,  3,4,5,  6,7,8        ; filas
             db 0,3,6,  1,4,7,  2,5,8        ; columnas
             db 0,4,8,  2,4,6                ; diagonales

; ---- Textos (terminan en '$') ----
sTitle       db 'T I C - T A C - T O E$'
sSub         db 'Juego para 2 jugadores$'
sRules1      db 'Victoria: +3 puntos   Empate: +1 punto$'
sRules2      db 'Marca casillas con las teclas 1 al 9$'
sStart       db 'ENTER = Jugar   ESC = Salir$'
sHigh        db 'HIGH SCORE: $'
sLabX        db 'X: $'
sLabO        db 'O: $'
sBar         db '|$'
sHLine       db '---+---+---$'
sBlank30     db '                              $'
sTurnX       db 'Turno: X$'
sTurnO       db 'Turno: O$'
sTaken       db 'Casilla ocupada!$'
sFin         db 'FIN DEL JUEGO$'
sWinX        db 'Gana el jugador X!$'
sWinO        db 'Gana el jugador O!$'
sDraw        db 'Empate!$'
sOpciones    db 'R = Jugar de nuevo   ESC = Salir$'
sHelp        db 'Teclas 1-9: marcar   ESC: titulo$'

; --------------------------------------------------------------------
;  SEGMENTO DE CODIGO
; --------------------------------------------------------------------
.code

; ====================================================================
;  MAIN: titulo -> juego -> fin de juego -> (repetir)
; ====================================================================
main proc
    mov ax, @data            ; DS apunta al segmento de datos
    mov ds, ax
    mov es, ax               ; ES = DS (INT 10h AH=13h lee la cadena en ES:BP)

    mov ax, 0003h            ; modo texto 80x25 (tambien limpia)
    int 10h

    mov ah, 01h              ; ocultar el cursor parpadeante
    mov cx, 2000h
    int 10h

main_title:
    call ShowTitle           ; AL = 1 (jugar), 0 (salir)
    cmp al, 0
    je main_exit

main_game:
    call NewGame             ; tablero vacio y pantalla de juego
    call PlayGame            ; juega hasta que haya ganador, empate o ESC
    cmp quitFlag, 1          ; ESC durante el juego -> titulo
    je main_title
    call EndGame             ; AL = 1 (otra vez), 0 (salir)
    cmp al, 1
    je main_game

main_exit:
    call ClearScreen
    mov ah, 01h              ; restaurar el cursor
    mov cx, 0607h
    int 10h
    mov ax, 4C00h            ; terminar el programa
    int 21h
main endp

; ====================================================================
;  ClearScreen: limpia la pantalla (INT 10h, AH=06h)
;  AL=0 -> limpiar, BH=atributo, CX=esquina sup-izq, DX=esquina inf-der
; ====================================================================
ClearScreen proc
    SaveRegs
    mov ax, 0600h
    mov bh, 07h
    mov cx, 0000h
    mov dx, 184Fh
    int 10h
    RestoreRegs
    ret
ClearScreen endp

; ====================================================================
;  PutCh: escribe un caracter con color en una posicion
;  Entrada: AL = caracter, BL = atributo, DH = fila, DL = columna
;  No modifica ningun registro.
; ====================================================================
PutCh proc
    push ax
    push bx
    push cx
    push ax                  ; guardar el caracter
    mov ah, 02h              ; posicionar el cursor
    mov bh, 0
    int 10h
    pop ax                   ; recuperar el caracter
    mov ah, 09h              ; escribirlo con el color de BL
    mov cx, 1
    int 10h
    pop cx
    pop bx
    pop ax
    ret
PutCh endp

; ====================================================================
;  DrawStr: dibuja una cadena '$' con color usando UNA sola llamada al
;  BIOS (INT 10h, AH=13h). Es mucho mas rapido que dibujar letra por letra.
;  Entrada: SI = direccion de la cadena, DH = fila, DL = columna,
;           BL = atributo (color)
;  Requiere ES = DS (se configura en main).
; ====================================================================
DrawStr proc
    push ax
    push bx
    push cx
    push bp
    push si
    mov bp, si               ; ES:BP = inicio de la cadena
    xor cx, cx               ; CX = longitud de la cadena
ds_len:
    cmp byte ptr [si], '$'   ; fin de cadena?
    je ds_write
    inc si
    inc cx                   ; contar un caracter mas
    jmp ds_len
ds_write:
    mov ah, 13h              ; escribir cadena
    mov al, 0                ; modo 0: usa el color de BL, no mueve el cursor
    mov bh, 0                ; pagina 0
    int 10h                  ; DH = fila, DL = columna, CX = longitud
    pop si
    pop bp
    pop cx
    pop bx
    pop ax
    ret
DrawStr endp

; ====================================================================
;  PrintNum3: imprime AX (0..999) con 3 digitos en el cursor actual
; ====================================================================
PrintNum3 proc
    push ax
    push bx
    push dx
    xor dx, dx
    mov bx, 100
    div bx                   ; AX = centenas, DX = resto (0..99)
    add al, '0'
    push dx                  ; guardar el resto
    mov dl, al
    mov ah, 02h              ; imprimir centenas
    int 21h
    pop ax                   ; AX = resto
    mov bl, 10
    div bl                   ; AL = decenas, AH = unidades
    mov bx, ax               ; BL = decenas, BH = unidades
    mov dl, bl
    add dl, '0'
    mov ah, 02h
    int 21h
    mov dl, bh
    add dl, '0'
    mov ah, 02h
    int 21h
    pop dx
    pop bx
    pop ax
    ret
PrintNum3 endp

; ====================================================================
;  ShowTitle: pantalla de inicio. Salida: AL = 1 (jugar), 0 (salir)
; ====================================================================
ShowTitle proc
    push bx
    push dx
    push si
    call ClearScreen
    PrintAt 5, 30, 0Bh, sTitle
    PrintAt 7, 29, 07h, sSub
    PrintAt 9, 21, 07h, sRules1
    PrintAt 10, 22, 07h, sRules2
    PrintAt 13, 26, 0Ah, sStart
    PrintAt 16, 29, 0Eh, sHigh
    SetCursor 16, 41
    mov ax, highScore
    call PrintNum3
st_wait:
    mov ah, 00h              ; esperar tecla: AL = ASCII
    int 16h
    cmp al, 13               ; ENTER
    je st_play
    cmp al, 27               ; ESC
    je st_quit
    jmp st_wait
st_play:
    mov al, 1
    jmp st_done
st_quit:
    mov al, 0
st_done:
    pop si
    pop dx
    pop bx
    ret
ShowTitle endp

; ====================================================================
;  NewGame: tablero vacio y pantalla de juego
; ====================================================================
NewGame proc
    push ax
    push bx
    push dx
    push si
    call ClearScreen
    xor si, si
ng_clear:                    ; vaciar las 9 casillas
    mov board[si], CELL_EMPTY
    inc si
    cmp si, 9
    jb ng_clear
    mov moves, 0
    mov result, RES_NONE
    mov quitFlag, 0
    mov turn, MARK_X         ; X siempre empieza
    PrintAt 1, 30, 0Bh, sTitle
    PrintAt 17, 23, 07h, sHelp
    call DrawGrid
    call DrawHUD
    call DrawBoard
    pop si
    pop dx
    pop bx
    pop ax
    ret
NewGame endp

; ====================================================================
;  DrawGrid: dibuja las lineas fijas del tablero
; ====================================================================
DrawGrid proc
    push bx
    push dx
    push si
    PrintAt 8, 30, 07h, sHLine
    PrintAt 10, 30, 07h, sHLine
    PrintAt 7, 33, 07h, sBar
    PrintAt 7, 37, 07h, sBar
    PrintAt 9, 33, 07h, sBar
    PrintAt 9, 37, 07h, sBar
    PrintAt 11, 33, 07h, sBar
    PrintAt 11, 37, 07h, sBar
    pop si
    pop dx
    pop bx
    ret
DrawGrid endp

; ====================================================================
;  DrawCell: dibuja la marca de una casilla
;  Entrada: AL = indice de casilla (0..8)
;  - vacia: muestra su numero 1..9 en gris
;  - X en rojo, O en cyan
; ====================================================================
DrawCell proc
    push ax
    push bx
    push cx
    push dx
    push si
    mov bl, al
    xor bh, bh
    mov si, bx               ; SI = indice de casilla
    mov ah, 0
    mov al, bl
    mov bl, 3
    div bl                   ; AL = fila (0..2), AH = columna (0..2)
    shl al, 1                ; fila * 2 (hay una linea de separacion)
    add al, BOARD_ROW
    mov dh, al               ; DH = fila de pantalla
    mov al, ah
    shl al, 1
    shl al, 1                ; columna * 4
    add al, BOARD_COL
    mov dl, al               ; DL = columna de pantalla
    mov cl, board[si]        ; CL = contenido de la casilla
    cmp cl, MARK_X
    je dc_x
    cmp cl, MARK_O
    je dc_o
    mov ax, si               ; vacia: mostrar el numero de casilla
    add al, '1'
    mov bl, 08h
    jmp dc_put
dc_x:
    mov al, 'X'
    mov bl, 0Ch
    jmp dc_put
dc_o:
    mov al, 'O'
    mov bl, 0Bh
dc_put:
    call PutCh
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
DrawCell endp

; ====================================================================
;  DrawBoard: dibuja las 9 casillas
; ====================================================================
DrawBoard proc
    push ax
    xor al, al
db_loop:
    call DrawCell
    inc al
    cmp al, 9
    jb db_loop
    pop ax
    ret
DrawBoard endp

; ====================================================================
;  DrawHUD: puntaje de X, puntaje de O y High Score (fila 3)
; ====================================================================
DrawHUD proc
    push ax
    push bx
    push dx
    push si
    PrintAt 3, 18, 0Ch, sLabX
    SetCursor 3, 21
    mov ax, scoreX
    call PrintNum3
    PrintAt 3, 28, 0Bh, sLabO
    SetCursor 3, 31
    mov ax, scoreO
    call PrintNum3
    PrintAt 3, 38, 0Eh, sHigh
    SetCursor 3, 50
    mov ax, highScore
    call PrintNum3
    pop si
    pop dx
    pop bx
    pop ax
    ret
DrawHUD endp

; ====================================================================
;  ShowTurn: limpia los mensajes y muestra el turno (fila 13)
; ====================================================================
ShowTurn proc
    push bx
    push dx
    push si
    PrintAt 13, 25, 07h, sBlank30
    PrintAt 14, 25, 07h, sBlank30
    cmp turn, MARK_X
    jne sw_o
    PrintAt 13, 30, 0Ch, sTurnX
    jmp sw_end
sw_o:
    PrintAt 13, 30, 0Bh, sTurnO
sw_end:
    pop si
    pop dx
    pop bx
    ret
ShowTurn endp

; ====================================================================
;  TryPlace: intenta marcar una casilla con la ficha del turno
;  Entrada: AL = casilla (0..8)    Salida: AL = 1 si se marco, 0 si ocupada
; ====================================================================
TryPlace proc
    push bx
    mov bl, al
    xor bh, bh               ; BX = indice
    cmp board[bx], CELL_EMPTY
    jne tp_busy
    mov al, turn
    mov board[bx], al        ; guardar la ficha en el tablero
    inc moves
    mov al, bl
    call DrawCell
    mov al, 1
    jmp tp_end
tp_busy:
    mov al, 0
tp_end:
    pop bx
    ret
TryPlace endp

; ====================================================================
;  GetMove: espera una jugada del teclado (bloqueante)
;  Salida: AL = 1 si se hizo una jugada, 0 si se pidio salir (ESC)
; ====================================================================
GetMove proc
    push bx
    push dx
    push si
gm_key:
    mov ah, 00h              ; AL = ASCII de la tecla
    int 16h
    cmp al, 27               ; ESC
    je gm_quit
    cmp al, '1'              ; solo valen las teclas 1..9
    jb gm_key
    cmp al, '9'
    ja gm_key
    sub al, '1'              ; AL = casilla 0..8
    call TryPlace
    cmp al, 1
    je gm_ok
    PrintAt 14, 28, 0Ch, sTaken   ; casilla ocupada: avisar y esperar otra
    jmp gm_key
gm_quit:
    mov quitFlag, 1
    mov al, 0
    jmp gm_end
gm_ok:
    mov al, 1
gm_end:
    pop si
    pop dx
    pop bx
    ret
GetMove endp

; ====================================================================
;  CheckWinner: revisa las 8 lineas con la tabla winLines
;  Salida: AL = RES_NONE / RES_X / RES_O / RES_DRAW
; ====================================================================
CheckWinner proc
    push bx
    push dx
    push si
    push di
    xor si, si               ; SI = desplazamiento de la linea (0,3,..,21)
cw_line:
    mov bl, winLines[si]
    xor bh, bh
    mov al, board[bx]        ; AL = ficha de la primera casilla
    cmp al, CELL_EMPTY
    je cw_next
    mov dl, al               ; DL = ficha a comparar
    mov di, si
    inc di
    mov bl, winLines[di]
    xor bh, bh
    cmp dl, board[bx]        ; segunda casilla igual?
    jne cw_next
    inc di
    mov bl, winLines[di]
    xor bh, bh
    cmp dl, board[bx]        ; tercera casilla igual?
    jne cw_next
    mov al, dl               ; hay ganador (RES_X = MARK_X, RES_O = MARK_O)
    jmp cw_exit
cw_next:
    add si, 3                ; siguiente linea
    cmp si, 24
    jb cw_line
    mov al, RES_NONE
    cmp moves, 9             ; tablero lleno sin ganador = empate
    jne cw_exit
    mov al, RES_DRAW
cw_exit:
    pop di
    pop si
    pop dx
    pop bx
    ret
CheckWinner endp

; ====================================================================
;  PlayGame: ciclo del juego  turno -> jugada -> revisar -> cambiar turno
; ====================================================================
PlayGame proc
    push ax
pg_turn:
    call ShowTurn
    call GetMove             ; AL = 1 jugada hecha, 0 salir
    cmp al, 0
    je pg_quit
    call CheckWinner         ; AL = resultado
    cmp al, RES_NONE
    jne pg_end
    xor turn, 3              ; cambiar de turno 1 <-> 2
    jmp pg_turn
pg_end:
    mov result, al
pg_quit:
    pop ax
    ret
PlayGame endp

; ====================================================================
;  UpdateHighScore: guarda el mayor puntaje alcanzado por cualquiera
; ====================================================================
UpdateHighScore proc
    push ax
    mov ax, scoreX
    cmp ax, highScore
    jbe uh_o
    mov highScore, ax
uh_o:
    mov ax, scoreO
    cmp ax, highScore
    jbe uh_done
    mov highScore, ax
uh_done:
    pop ax
    ret
UpdateHighScore endp

; ====================================================================
;  EndGame: suma puntos, muestra el resultado y pregunta que hacer
;  Salida: AL = 1 (jugar de nuevo), 0 (salir)
; ====================================================================
EndGame proc
    push bx
    push dx
    push si
    PrintAt 13, 25, 07h, sBlank30
    PrintAt 14, 25, 07h, sBlank30
    PrintAt 13, 29, 0Eh, sFin
    cmp result, RES_X
    je eg_x
    cmp result, RES_O
    je eg_o
    add scoreX, PTS_DRAW     ; empate: 1 punto para cada uno
    add scoreO, PTS_DRAW
    PrintAt 14, 31, 0Eh, sDraw
    jmp eg_cont
eg_x:
    add scoreX, PTS_WIN
    PrintAt 14, 28, 0Ch, sWinX
    jmp eg_cont
eg_o:
    add scoreO, PTS_WIN
    PrintAt 14, 28, 0Bh, sWinO
eg_cont:
    call UpdateHighScore
    call DrawHUD
    PrintAt 15, 24, 07h, sOpciones
eg_wait:
    mov ah, 00h
    int 16h
    cmp al, 'r'
    je eg_again
    cmp al, 'R'
    je eg_again
    cmp al, 27
    je eg_exit
    jmp eg_wait
eg_again:
    mov al, 1
    jmp eg_done
eg_exit:
    mov al, 0
eg_done:
    pop si
    pop dx
    pop bx
    ret
EndGame endp

end main
