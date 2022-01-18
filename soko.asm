; simple sokoban game to practice assembly for the msx

CHGET: equ 09Fh
CHPUT: equ 0A2h
CLS: equ 0C3h
POSIT: equ 0C6h

RomSize: equ 2000h

  org 4000h

  db "AB"		; auto-executable msx rom
  dw Start		; entry point address
  dw 0			; basic extension address
  dw 0			; cart h/w control program address
  dw 0			; basic program pointer in rom
  dw 0,0,0

; entry point
Start:
  ld a,0
  ld hl,CurrentLevel
  ld (hl),a
  call LoadLevel

MainLoop:
  call ControlPlayer
  call CheckVictory
  jr MainLoop

MapW: equ 0E010h
MapH: equ 0E011h
Map: equ 0E012h
PlayerX: equ 0E001h
PlayerY: equ 0E002h
CurrentLevel: equ 0E005h

; wait for input, move player accordingly
ControlPlayer:
  ld hl,PlayerX
  ld a,(hl)
  inc hl
  ld l,(hl)
  ld h,a

  call CHGET
  sub 01Bh
  ld b,a

  djnz NotRight
  inc h
  jr ApplyMove
NotRight:
  djnz NotLeft
  dec h
  jr ApplyMove
NotLeft:
  djnz NotUp
  dec l
  jr ApplyMove
NotUp:
  djnz NotDown
  inc l

ApplyMove:
  call MovePlayer
  jr ControlPlayer_end

NotDown:
  add 01Bh
  cp 'r'
  jr nz,NotR

  call LoadLevel
  jr ControlPlayer_end

NotR:
  cp 's'
  jr nz,ControlPlayer_end

  ld hl,CurrentLevel
  ld b,(hl)
  inc b
  ld (hl),b
  call LoadLevel

ControlPlayer_end:
  ret

; move player to (h,l)
MovePlayer:
  push hl
  call GetTile
  ld a,(hl)
  pop hl

  cp 1
  jp z,MovePlayer_end
  cp 2
  jp z,PushBox

MovePlayer_noverif:
  push hl

  ; redraw old tile
  ld hl,PlayerX
  ld c,(hl)
  inc hl
  ld l,(hl)
  ld h,c

  push hl
  call GetTile
  ld b,(hl)
  pop hl
  inc h
  inc l
  inc l
  call POSIT
  call GetTileChar
  call CHPUT

  ; move player
  pop bc
  ld hl,PlayerX
  ld (hl),b
  inc hl
  ld (hl),c

  call DrawPlayer

MovePlayer_end:
  ret

PushBox:
  ; load player xy to (b,c)
  push hl
  ld hl,PlayerX
  ld b,(hl)
  inc hl
  ld c,(hl)
  pop hl

  push hl

  ld a,h
  sub b
  jr nz,PushX
  ld a,l
  sub c
  jr nz,PushY
  jp PushFail

PushX:
  cp 0FFh
  jr c,PushX_pos

  dec h
  jr PushBox_test

PushX_pos:
  inc h
  jr PushBox_test

PushY:
  cp 0FFh
  jr c,PushY_pos

  dec l
  jr PushBox_test

PushY_pos:
  inc l

PushBox_test:
  push hl
  inc h
  inc l
  inc l
  call POSIT
  pop hl

  call GetTile
  ld a,(hl)

  ld c,2

  cp 1
  jp z,PushFail
  cp 2
  jp z,PushFail
  cp 4
  jp z,PushFail
  cp 3
  jp nz,PBNoSlot

  ld c,4
PBNoSlot:

  ; move cursor to box position

  ; apply box push
  ld (hl),c
  pop hl
  push hl
  call GetTile
  ld a,0
  ld (hl),a

  ; redraw box
  ld a,c
  cp 2
  ld a,'$'
  jr nz,PBSlot
RedrawBox:
  call CHPUT
  jr NoPBSlot

PBSlot:
  ld a,'x'
  jr RedrawBox
NoPBSlot:

  ; get back to moving player
  pop hl
  jp MovePlayer_noverif

PushFail:
  pop hl
  inc h
  inc l
  inc l
  call POSIT

  ret

; display nice message on screen, wait for input
Congratulations:
  xor a
  call CLS
  ld h,7
  ld l,10
  call POSIT
  ld hl,CongratsMsg
  call Print
  ld h,5
  ld l,12
  call POSIT
  ld hl,RestartMsg
  call Print

CongratsLoop:
  call CHGET
  cp 'r'
  jr nz,CongratsLoop

  ; reset level to 0
  ld hl,CurrentLevel
  ld a,0
  ld (hl),a
  call LoadLevel

  ret

; print null-terminated string from addr hl
Print:
  ld a,(hl)
  call CHPUT
  inc hl
  and a
  jr nz,Print

  ret

; print number from b
PrintNum:
  xor a
  ex af,af'
  ld a,0FFh
  inc b
PrintNum_loop:
  inc a
  cp 10
  jp nz,PrintNum_not10

  xor a
  ex af,af'
  inc a
  ex af,af'

PrintNum_not10:
  dec b
  jp nz,PrintNum_loop

  ex af,af'
  add '0'
  call CHPUT
  ex af,af'
  add '0'
  call CHPUT

  ret

; load memory address of tile at h,l into hl
GetTile:
  push bc
  push af
  push de

  push hl

  ld hl,MapW
  ld c,(hl)
  pop hl
  ld b,0
  ld a,0FFh
  ld de,Map
  dec de
GetTile_loop:
  inc a
  inc de
  cp h
  jr z,GetTile_xeq
  cp c
  jr nz,GetTile_loop
  xor a
  inc b
  cp h
  jr z,GetTile_xeq
  jr GetTile_loop

GetTile_xeq:
  push af
  ld a,b
  cp l
  jr z,GetTile_yeq
  pop af
  jp GetTile_loop

GetTile_yeq:
  pop af
  push de
  pop hl

  pop de
  pop af
  pop bc

  ret

; draw level
DrawLevel:
  ; d is w, e is h
  ld hl,MapW
  ld d,(hl)
  inc hl
  ld e,(hl)

  ; load map ptr to hl
  ld hl,Map

DrawMap:
  ld b,(hl)
  inc hl

  call GetTileChar

  call CHPUT
  dec d
  jp nz,DrawMap

  ; set d to mapw
  push hl
  ld hl,MapW
  ld d,(hl)
  pop hl

  ; write newline
  ld a,0Ah
  call CHPUT
  ld a,0Dh
  call CHPUT

  ; dec h
  dec e
  jp nz,DrawMap

  ret

; checks if victory conditions are met, if so loads next level
CheckVictory:
  ld hl,MapW
  ld b,(hl)
  ld d,b
  inc hl
  ld c,(hl)
CheckVictory_loop:
  inc hl
  ld a,(hl)
  cp 3
  jp z,CheckVictory_end
  dec b
  jr nz,CheckVictory_loop
  ld b,d
  dec c
  jr nz,CheckVictory_loop

  ; victory! load the next level
  ld hl,CurrentLevel
  ld a,(hl)
  inc a
  ld (hl),a
  call LoadLevel

CheckVictory_end:
  ret

; loads ascii char for tile b into a
GetTileChar:
  inc b

  djnz NotFloor
  ld a,'.'
  jr GetTileChar_end
NotFloor:
  djnz NotWall
  ld a,'#'
  jr GetTileChar_end
NotWall:
  djnz NotBox
  ld a,'$'
  jr GetTileChar_end
NotBox:
  djnz NotSlot
  ld a,'_'
  jr GetTileChar_end
NotSlot:
  ld a,'x'

GetTileChar_end:
  ret

; draw player
DrawPlayer:
  ld hl,PlayerX
  ld a,(hl)
  inc hl
  ld l,(hl)
  ld h,a
  inc h
  inc l
  inc l
  call POSIT
  ld a,'@'
  call CHPUT
  call POSIT

  ret

; load level
LoadLevel:
  ; load map addr into hl
  ld hl,CurrentLevel
  ld a,(hl)
  ld hl,LevelArr
  cp WinLevel
  jp z,Congratulations
  inc a
LevelAddrLoop:
  dec a
  jr z,LevelAddrLoop_out
  inc hl
  inc hl
  jr LevelAddrLoop
LevelAddrLoop_out:
  ld c,(hl)
  inc hl
  ld h,(hl)
  ld l,c

  ; w and h
  ld de,MapW
  ldi
  ldi

  ; load map
  push hl

  ld hl,(MapW)
  ld d,(hl)
  inc hl
  ld e,(hl)

  ld a,0
  ld b,0
LoadMap_mulloop:
  ccf
  add a,d
  jr nc,LoadMap_nocarry

  inc b

LoadMap_nocarry:
  dec e
  jr nz,LoadMap_mulloop

  pop hl
  ld c,a
  ld de,Map

  ldir

  ; get player position
  ld hl,MapW
  ld d,(hl)
  ;dec d
  ld b,0
  ld c,0
  ld hl,Map
LoadPlayer:
  ld a,(hl)
  cp 4
  jp z,LoadPlayer_end

  inc hl
  inc b
  ld a,b
  cp d
  jr nz,LoadPlayer

  ld b,0
  inc c
  jr LoadPlayer

LoadPlayer_end:
  ld (hl),0

  ld hl,PlayerX
  ld (hl),b
  inc hl
  ld (hl),c

  ; draw level
  xor a
  call CLS
  ld h,1
  ld l,2
  call POSIT
  call DrawLevel

  ; draw help
  ld hl,MapH
  ld l,(hl)
  ld h,1
  inc l
  inc l
  inc l
  call POSIT
  ld hl,RestartMsg
  call Print
  ld hl,SkipMsg
  call Print

  ; print level number
  ld h,1
  ld l,1
  call POSIT
  ld hl,CurrentLevel
  ld b,(hl)
  inc b
  call PrintNum
  ld a,'/'
  call CHPUT
  ld b,WinLevel
  call PrintNum

  call DrawPlayer

  ret

; string constants
CongratsMsg:
  db "Congratulations!",0
RestartMsg:
  db "Press 'r' to restart",0Ah,0Dh,0
SkipMsg:
  db "Press 's' to skip",0

; level data

; array of map addresses
LevelArr:
  dw map1
  dw map2
  dw map3
WinLevel: equ 3

map1:
  db 6,6
  db 1,1,1,1,1,1
  db 1,4,0,0,0,1
  db 1,0,2,2,0,1
  db 1,0,1,0,3,1
  db 1,0,0,0,3,1
  db 1,1,1,1,1,1
map2:
  db 7,6
  db 1,1,1,1,1,1,1
  db 1,3,0,0,0,0,1
  db 1,0,4,2,2,0,1
  db 1,1,2,1,0,0,1
  db 1,3,0,3,0,0,1
  db 1,1,1,1,1,1,1
map3:
  db 5,5
  db 1,1,1,1,1
  db 1,3,2,3,1
  db 1,2,2,4,1
  db 1,3,2,3,1
  db 1,1,1,1,1

RomEnd:

  ; pad rom with 0FFh
  ds 4000h+RomSize-RomEnd,0FFh
