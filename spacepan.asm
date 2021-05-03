.cpu "6502i"

SRCROM = "Space Panic (USA, Europe).col"
srcromdat = binary(SRCROM)



screen = $0400
charset = $0800

FIRSTCOL = (40-32)/2

char .function ch
.endf charset + (ch*8)

line .function li ;the upper line is cut off, so we add 1 first
.endf screen + (li*40)

colline .function li
.endf $d800 + (li*40)


c64screen .function addr
.endf line(addr / $20) + (addr & $1f) + FIRSTCOL

c64color .function addr
.endf colline(addr / $20) + (addr & $1f) + FIRSTCOL


bioschar .function ch
.endf ascii_charset + (ch-$1d)*8


.virtual 2
;;;; system vars
temp        .fill 6

gamecnt     .byte ?
framecnt    .byte ?

d011_mir    .byte ?
bordercol   .byte ?
bgcol       .byte ?

soundqueue  .byte ?
soundmute   .byte ?
pauseflag   .byte ?

joy         .fill 2
key         .fill 8

mathresult  .word ?
mathtemp    .byte ?

spriteen    .byte ?
spritemsb   .byte ?
spriteptr   .fill 8
spritex     .fill 8
spritey     .fill 8
spritecol   .fill 8

r_seed      .byte ?
r_rept      .byte ?
r_val       .byte ?


;;;;;general game vars
g_2player   .byte ?
g_skill     .byte ?
g_flags     .byte ?
                ;same as original game:
                    ;bit 0 - currently active player
                    ;bit 5 - player 1 seen intro
                    ;bit 6 - player 2 seen intro

g_hiscorelo .byte ?
g_scorelo   .fill 2
g_hiscorehi .byte ?
g_scorehi   .fill 2
g_round     .fill 2
g_lives     .fill 2
g_extralives .fill 2

g_roundid   .byte ?
g_laddertbllo
            .fill 5
g_laddertblhi
            .fill 5
            
g_curenemy  .byte ?

g_enemyspeed .byte ?
g_enemyiqadd .byte ?

g_oxylow    .byte ?
g_oxybonus  .word ?
g_oxybonusrate  .byte ?
g_oxybonustimer .byte ?
g_oxybonusreload    .byte ?
g_oxybonuslowticks  .byte ?
g_oxybar    .byte ?
g_oxybartimer   .byte ?
g_oxybarreload  .byte ?


;;;;;player
p_flags     .byte ?
                ;bit 0 - 1 to enable waiting for timer
                ;bit 2 - 1 if player is falling
p_x         .byte ?
p_y         .byte ?
p_dir       .byte ?
p_walk      .byte ?
p_frame     .byte ?
p_timer     .byte ?

p_buzzmutetimer
            .byte ?

;;;;;enemies
ENEMIES = 7
e_flags     .fill ENEMIES
e_type      .fill ENEMIES
e_dir       .fill ENEMIES
e_timer     .fill ENEMIES
e_y         .fill ENEMIES
e_x         .fill ENEMIES
e_iq        .fill ENEMIES ;(intelligence)
e_frame     .fill ENEMIES
e_escapecnt .fill ENEMIES
e_fallcnt   .fill ENEMIES
ETBL_SIZE = * - e_flags

.cerror * > m_zp, "too many zeropage variables"
.endv

.virtual $200
    ;the original hole table ($719a) goes like this:
        ;for each onscreen line (bottom -> top):
            ;for 10 possible holes:
                ;byte 0 -   bit 7: active
                ;           bit 0: occupied
                ;byte 1 -   dig level (0=undug, 3=fully dug)
                ;byte 2 -   pixel-wise x-position ($10 is the lowest possible)
MAX_HOLES = 10
HOLE_SIZE = 3
holetable   .fill 4*MAX_HOLES*HOLE_SIZE


.endv


copyx   .macro src, dst, siz=-1
            left := \siz > 0 ? \siz : size(\src)
            offs := 0
            .if left > $ff
                ldx #0
-               .while left > $ff
                    lda \src+offs,x
                    sta \dst+offs,x
                    
                    left := left - $100
                    offs := offs + $100
                .next
                inx
                bne -
            .endif
            .if left > $81
                ldx #left
-               lda \src+offs-1,x
                sta \dst+offs-1,x
                dex
                bne -
            .elsif left > 2
                ldx #left-1
-               lda \src+offs,x
                sta \dst+offs,x
                dex
                bpl -
            .else
                .rept left
                    lda \src+offs
                    sta \dst+offs
                    
                    offs := offs + 1
                .next
            .endif
        .endm

copyy   .macro src, dst, siz=-1
            left := \siz > 0 ? \siz : size(\src)
            offs := 0
            .if left > $ff
                ldy #0
-               .while left > $ff
                    lda \src+offs,y
                    sta \dst+offs,y
                    
                    left := left - $100
                    offs := offs + $100
                .next
                iny
                bne -
            .endif
            .if left > $81
                ldy #left
-               lda \src+offs-1,y
                sta \dst+offs-1,y
                dey
                bne -
            .elsif left > 2
                ldy #left-1
-               lda \src+offs,y
                sta \dst+offs,y
                dey
                bpl -
            .else
                .rept left
                    lda \src+offs
                    sta \dst+offs
                    
                    offs := offs + 1
                .next
            .endif
        .endm


            * = $0800
palfreqtbl  .binary "music/palfreq"
            
            lda #$7f
            sta $dc0d
            sta $dd0d
            lda #$00
            sta $d01a
            lda #<nmi
            sta $fffa
            lda #>nmi
            sta $fffb
            lda #$35
            sta $01
            
            lda $dc04
            sta r_val
            lda $02a6
            and #1
            sta $02a6
            tax
            lda ciatbllo,x
            sta $dc04
            lda ciatblhi,x
            sta $dc05
            lda #$11
            sta $dc0e
            txa
            beq +
-           .for i = 0, i < $1000, i=i+$100
                lda palfreqtbl + i,x
                sta freqtbl + i,x
            .next
            inx
            bne -
+           jsr m_reset
            
            lda #$0b
            sta $d011
            lda $dd00
            ora #3
            sta $dd00
            lda #8
            sta $d016
            lda #$12
            sta $d018
            lda #<irq
            sta $fffe
            lda #>irq
            sta $ffff
            lda #$00
            sta $d012
            sta r_seed
            sta soundqueue
            sta soundmute
            sta pauseflag
            sta $d015
            sta spriteen
            sta $d01d
            sta $d017
            lda #$ff
            sta $d01c
            ldx #5 ;sprite multi-colors are green and blue
            stx $d025 ;this means the player's helmet cannot be a different color
            inx
            stx $d026
            lda #1
            sta $d019
            sta $d01a
            lda $dc0d
            lda #$81
            sta $dc0d
            cli
            
            ; -------------------- title screen
title       lda #0
            sta g_hiscorelo
            sta g_hiscorehi
            sta bgcol
            sta bordercol
            jsr screenoff
            
            jsr clearscreen
            jsr loadascii
            
            lda #<char($60)
            sta temp
            lda #>char($60)
            sta temp+1
            ldx #size(collogo_meta)-1
_logoloop   stx temp+2
            lda collogo_meta,x
            asl
            asl
            asl
            tax
            ldy #0
            .for i = 0, i < 7, i=i+1
                lda collogo_charset + i,x
                sta (temp),y
                iny
            .next
            lda collogo_charset+7,x
            sta (temp),y
            tya
            sec
            adc temp
            sta temp
            bcc +
            inc temp+1
+           ldx temp+2
            dex
            bpl _logoloop
            
            
           
            ldx #($2c/2)-1
-           lda collogo_screen,x
            sta line(4)+FIRSTCOL+5,x
            lda collogo_screen+($2c/2),x
            sta line(5)+FIRSTCOL+5,x
            lda collogo_colors,x
            sta colline(4)+FIRSTCOL+5,x
            sta colline(5)+FIRSTCOL+5,x
            dex
            bpl -
            
            ldx #$1e
            stx line(4)+FIRSTCOL+5+($2c/2)
            inx
            stx line(4)+FIRSTCOL+5+($2c/2)+1
            
            
            
            #copyx copyright_1, line(14)+FIRSTCOL+$07
            #copyx copyright_2, line(16)+FIRSTCOL+$0a
            #copyx copyright_3, line(21)+FIRSTCOL+$0a
            
            jsr screenon
            
            ldx #7
-           lda #60
            jsr waitgames
            dex
            bne -
            
            
            ; -------------------- game/skill selection
skillmenu   jsr screenoff
            
            jsr loadascii
            jsr clearscreen
            
            #copyx skillmenu_1, line(1)+FIRSTCOL+5
            #copyx skillmenu_2, line(3)+FIRSTCOL+5
            ldx #size(skillmenu_m)-1
-           lda skillmenu_m,x
            sta line(6)+FIRSTCOL+7,x
            sta line(8)+FIRSTCOL+7,x
            sta line(10)+FIRSTCOL+7,x
            sta line(12)+FIRSTCOL+7,x
            sta line(15)+FIRSTCOL+7,x
            sta line(17)+FIRSTCOL+7,x
            sta line(19)+FIRSTCOL+7,x
            sta line(21)+FIRSTCOL+7,x
            dex
            bpl -
            ldx #'1'
            stx line(6)+FIRSTCOL+5
            stx line(6)+FIRSTCOL+15
            stx line(15)+FIRSTCOL+15
            inx
            stx line(8)+FIRSTCOL+5
            stx line(8)+FIRSTCOL+15
            stx line(17)+FIRSTCOL+15
            inx
            stx line(10)+FIRSTCOL+5
            stx line(10)+FIRSTCOL+15
            stx line(19)+FIRSTCOL+15
            inx
            stx line(12)+FIRSTCOL+5
            stx line(12)+FIRSTCOL+15
            stx line(21)+FIRSTCOL+15
            inx
            stx line(15)+FIRSTCOL+5
            inx
            stx line(17)+FIRSTCOL+5
            inx
            stx line(19)+FIRSTCOL+5
            inx
            stx line(21)+FIRSTCOL+5
            ldx #'S'
            stx line(15)+FIRSTCOL+27
            stx line(17)+FIRSTCOL+27
            stx line(19)+FIRSTCOL+27
            stx line(21)+FIRSTCOL+27
            inx
            stx line(15)+FIRSTCOL+17
            stx line(17)+FIRSTCOL+17
            stx line(19)+FIRSTCOL+17
            stx line(21)+FIRSTCOL+17
            lda #'W'
            sta line(15)+FIRSTCOL+18
            sta line(17)+FIRSTCOL+18
            sta line(19)+FIRSTCOL+18
            sta line(21)+FIRSTCOL+18
            lda #'O'
            sta line(15)+FIRSTCOL+19
            sta line(17)+FIRSTCOL+19
            sta line(19)+FIRSTCOL+19
            sta line(21)+FIRSTCOL+19
            
            lda #6
            sta bordercol
            sta bgcol
            jsr screenon
            
-           lda #1
            bit key+7
            bne _1
            bit key+3
            bne _7
            bit key+2
            bne _5
            bit key+1
            bne _3
            lda #8
            bit key+7
            bne _2
            bit key+3
            bne _8
            bit key+2
            bne _6
            bit key+1
            beq -
_4          lda #3
            .byte $2c
_1          lda #0
            .byte $2c
_2          lda #1
            .byte $2c
_3          lda #2
            .byte $2c
_5          lda #4
            .byte $2c
_6          lda #5
            .byte $2c
_7          lda #6
            .byte $2c
_8          lda #7
            
            ldx #3
            sax g_skill
            inx
            sax g_2player
            
            
            ;-------------------actual game
            lda #0
            sta bordercol
            sta bgcol
            jsr screenoff
            
            ;$8159 - do pattern copies
            ldx #7
            lda #0
-           sta char(0),x
            dex
            bpl -
            #copyx c_8301, char($08)
            #copyx c_8369, char($18)
            #copyx c_8379, char($20)
            #copyx c_8389, char($28)
            #copyx c_83d9, char($38)
            #copyx c_83e9, char($40)
            #copyx c_83f9, char($48)
            #copyx c_84d1, char($70)
            ;$8188 - copy NUMBER
            #copyx bioschar('0'), char($d8), $0a*8
            ;$8195 - copy ASCII
            #copyx bioschar('A'), char($e2), $1a*8
            ;$81a2 - copy other chars
            #copyx bioschar('0')-$20, char($fc), 3*8
            #copyx bioschar('0')+$4e, char($ff), 8
            
            ;and now begin the main game loop
            lda #0
-           jsr game_start
            jsr game_main
            jsr game_end
            cmp #$02
            bne -
            
            jmp skillmenu
            
            
game_start  tax
            bne _noinit
            ;$9104 - init vars
            sta g_scorelo+0
            sta g_scorelo+1
            sta g_scorehi+0
            sta g_scorehi+1
            
            ldx #3
            lda g_skill
            bne +
            ldx #5
+           stx g_lives+0
            lda g_2player
            bne +
            tax
+           stx g_lives+1
            
            ldx #1
            stx g_round+0
            stx g_round+1
            dex
            stx g_flags
            stx g_extralives+0
            stx g_extralives+1
            
_noinit     ; ---- $913c - init enemies/oxygen
            ldx #ETBL_SIZE
            lda #0
-           sta e_flags-1,x
            dex
            bne -
                ;$a488
                lda g_flags
                and #1
                tay
                ldx g_round,y
                cpx #$15+1
                bcc +
                ldx #$15
+               lda enemytbllo-1,x
                sta temp
                lda enemytblhi-1,x
                sta temp+1
                ldy #0
                lda (temp),y
                ldx g_skill
                ldy diffdivtbl,x
                jsr mula100divy
                cmp #7
                bcs +
                lda #7
+               sta g_enemyspeed
                
                ldy #1
                lda (temp),y
                ldy g_skill
                ldx diffdivtbl,y
                jsr mulaxdiv100
                sta g_enemyiqadd
                
                ;this is useless enemy init code, exists in the original too
                ;but enemy params written here get overwritten by the enemy
                ;spawn routine on round start
                .comment
                ldy #2
                lax (temp),y
                dex
                iny
_initenemyloop  lda #$80
                sta e_flags,x
                lda (temp),y
                sta e_type,x
                iny
                lda (temp),y
                iny
                stx temp+2
                sty temp+3
                ldy g_skill
                ldx diffdivtbl,y
                jsr mulaxdiv100
                ldx temp+2
                ldy temp+3
                sta e_iq,x
                dex
                bpl _initenemyloop
                .endc
            ;$9164
            ldx #4*MAX_HOLES*HOLE_SIZE - 1
            lda #0
-           sta holetable,x
            dex
            bpl -
            ;$9171
            ;lda #0
            sta g_oxylow
            lda g_flags
            and #1
            tax
            lda g_round,x
            ldx #0
            cmp #4
            bcc +
            inx
            cmp #7
            bcc +
            inx
+           lda oxytbl_bonusrate,x
            sta g_oxybonusrate
            lda oxytbl_bonuslo,x
            sta g_oxybonus
            lda oxytbl_bonushi,x
            sta g_oxybonus+1
            lda oxytbl_bonusreload,x
            sta g_oxybonusreload
            sta g_oxybonustimer
            lda oxytbl_barreload,x
            sta g_oxybarreload
            sta g_oxybartimer
            lda #$50
            sta g_oxybonuslowticks
            asl
            sta g_oxybar
            
            
            ; ------ $929a - init display
            jsr screenoff
            jsr clearscreen_0
            
            ldy #1 ;"1up"
            lda #1
            jsr copystring
            ldy #2 ;"2up
            lda #1
            jsr copystring
            ldy #1
            jsr displayscore
            ldy #2
            jsr displayscore
            ldy #0
            jsr displayscore
            ldy #3 ;"oxygen"
            lda #1
            jsr copystring
            ldy #0
            jsr displayoxybonus
                ;$a7b6, init oxybar
                ldx #$14+8-1
-               lda #$18
                sta c64screen($0042),x
                lda #7
                cpx #$14
                bcc +
                lda #2
+               sta c64color($0042),x
                dex
                bpl -
            jsr displaylives
            jsr displayround
            ldy #7 ;upper border
            lda #6
            jsr copystring
            ldy #8 ;lower border
            lda #6
            jsr copystring
            
            
            ; $92e5 - do game intro, if needed
            lda g_flags
            lsr
            lda #$20
            bcc +
            asl
+           bit g_flags
            bne _nointro
            ora g_flags
            sta g_flags
            ldy #4
            lda #1
            jsr copystring
            ldy #2
            jsr displayoxybonus
            ldy #6
            lda #1
            jsr copystring
            jsr screenon
            
            lda #$74
            sta spritex+0
            sta spritex+1
            sta spritex+2
            lda #0
            sta spritemsb
            lda enemycoltbl+0
            sta spritecol+0
            lda enemycoltbl+1
            sta spritecol+1
            lda enemycoltbl+2
            sta spritecol+2
            lda #$72
            sta spritey+0
            lda #$82
            sta spritey+1
            lda #$92
            sta spritey+2
            lda #EN_WALK0+EN_TYPE0
            sta spriteptr+0
            lda #EN_WALK0+EN_TYPE1
            sta spriteptr+1
            lda #EN_WALK0+EN_TYPE2
            sta spriteptr+2
            lda #7
            sta spriteen
            
            ldy #1
            jsr initsong
            lda #$31
            jsr waitgames
            lda #$ff
            jsr waitgames
            jsr cleargamescreen
            jmp _afterintro
_nointro    
            jsr screenon
_afterintro 
            
            lda #0
            sta spriteen
            ;$934f - "get ready"
            lda g_flags
            lsr
            lda #9
            adc #0
            tay
            lda #1
            jsr copystring
            lda #$3e
            jsr waitgames
            jsr cleargamescreen
            
            
            ; ------------ $9202 initialize player
            lda #1
            sta spritecol+7
            lda g_flags
            and #1
            tax
            lda g_lives,x
            asl
            asl
            asl
            adc #$14
            sta p_x
            lda #$b0
            sta p_y
            lda #PL_WALK0
            sta p_frame
            lda #0
            sta p_walk
            sta p_dir
            sta p_buzzmutetimer
            
_playerloop ldy #6
            jsr initsong
            
            jsr displayplayer
            
            lda #4
            sta p_timer
-           lda p_timer
            bne -
            
            lda p_x
            cmp #$80
            beq +
            clc
            adc #4
            sta p_x
            
            ldx p_walk
            inx
            txa
            and #3
            sta p_walk
            ;clc
            adc #PL_WALK0
            sta p_frame
            jmp _playerloop
            
+           lda #PL_WALK0
            sta p_frame
            lda #0
            sta p_flags
            jsr displayplayer
            
            
            
            
            ; --------- $91d4 - generate round layout
-           jsr rand
            and #7
            cmp g_roundid
            beq -
            sta g_roundid
            ;write platforms
            ldx #$1c
-           lda #$0d
            sta colline(6)+FIRSTCOL+1,x
            sta colline(10)+FIRSTCOL+1,x
            sta colline(14)+FIRSTCOL+1,x
            sta colline(18)+FIRSTCOL+1,x
            sta colline(6)+FIRSTCOL+2,x
            sta colline(10)+FIRSTCOL+2,x
            sta colline(14)+FIRSTCOL+2,x
            sta colline(18)+FIRSTCOL+2,x
            lda #$20
            sta line(6)+FIRSTCOL+1,x
            sta line(10)+FIRSTCOL+1,x
            sta line(14)+FIRSTCOL+1,x
            sta line(18)+FIRSTCOL+1,x
            lda #$21
            sta line(6)+FIRSTCOL+2,x
            sta line(10)+FIRSTCOL+2,x
            sta line(14)+FIRSTCOL+2,x
            sta line(18)+FIRSTCOL+2,x
            dex
            dex
            bpl -
            ;write ladders
            ldx g_roundid
            lda ladderdisptbllo,x
            sta temp
            lda ladderdisptblhi,x
            sta temp+1
_ladderdisploop
            ldy #0
            lda (temp),y
            beq _afterladderdisp
            sta _ladchar+1
            iny
            lda (temp),y
            sta temp+4
            iny
            lda (temp),y
            sta temp+2
            and #$1f
            sta temp+5
            iny
            lda (temp),y
            .rept 3
                asl temp+2
                rol
            .next
            tax
            tya
            sec
            adc temp
            sta temp
            bcc +
            inc temp+1
+           
            lda linetbllo,x
            sta temp+2
            lda linetblhi,x
            sta temp+3
            ldx temp+4
            ldy temp+5
            lda temp+2
            sta temp+4
            lda temp+3
            eor #(>screen) ^ $d8
            sta temp+5
-
_ladchar    lda #0
            sta (temp+2),y
            lda #4
            sta (temp+4),y
            lda temp+2
            clc
            adc #40
            sta temp+2
            sta temp+4
            bcc +
            inc temp+3
            inc temp+5
+           dex
            bne -
            geq _ladderdisploop
_afterladderdisp
            
            ;setup ladder table
            lda g_roundid
            asl
            asl
            adc g_roundid
            tay
            ldx #0
-           lda laddertbllo,y
            sta g_laddertbllo,x
            lda laddertblhi,y
            sta g_laddertblhi,x
            iny
            inx
            cpx #5
            bcc -
            
            
            ; ----------- $993a - spawn enemies
            lda g_flags
            and #1
            tax
            ldy g_round,x
            cpy #$15+1
            bcc +
            ldy #$15
+           lda enemytbllo-1,y
            sta temp
            lda enemytblhi-1,y
            sta temp+1
            
            lda g_roundid
            asl
            adc g_roundid
            tay
            lda ub62blo,y
            sta temp+2
            lda ub62bhi,y
            sta temp+3
            
            lda #0
            sta enemiesonrow+0
            sta enemiesonrow+1
            sta enemiesonrow+2
            
            ldy #2
            lax (temp),y
            dex
            iny
_mainspawnloop
            lda #$80
            sta e_flags,x
            asl
            sta e_dir,x
            lda #EN_WALK1
            sta e_frame,x
            lda (temp),y
            sta e_type,x
            iny
            lda (temp),y
            sta e_iq,x
            iny
            tya
            pha
            
            ;decide which row the enemy will be on
-           jsr rand
            ldy #0
            cmp #$56
            bcc +
            iny
            cmp #$ab
            bcc +
            iny
+           lda enemiesonrow,y ;don't spawn more than 3 enemies per row
            cmp #3
            bcs -
            ;clc
            adc #1
            sta enemiesonrow,y
            tya
            lsr
            ror
            ror
            ror
            adc #$30
            sta e_y,x
            
            ;now test xpos
-           jsr rand
            and #$1f
            ldy #0
            cmp (temp+2),y
            bcs -
            tay
            iny
            lda (temp+2),y
            sta e_x,x
            jsr checkintraenemycollision
            bcs -
            
            jsr displayenemy
            lda g_enemyspeed
            sta e_timer,x
            txa
            pha
            ldy #$0b
            jsr initsong
            lda #$2e
            jsr waitgames
            pla
            tax
            
            pla
            tay
            dex
            bpl _mainspawnloop
            
            
            
            ldy #$11
            jsr initsong
            lda #$90
            jmp waitgames
            
enemiesonrow
            .fill 3
            
diffdivtbl ;$a4ec
            .byte $32,$4b,$64,$7d
            
            ;$b4c2
enemytbllo  .for i = 0, i < $2a, i=i+2
                .byte <((srcromdat[$34c2+i] | (srcromdat[$34c2+i+1] << 8)) - $b4ec + enemytbl)
            .next
enemytblhi  .for i = 0, i < $2a, i=i+2
                .byte >((srcromdat[$34c2+i] | (srcromdat[$34c2+i+1] << 8)) - $b4ec + enemytbl)
            .next
enemytbl    .binary SRCROM, $34ec,$13f
            
            ;$b62b
ub62blo     .for i = 0, i < $30, i=i+2
                .byte <((srcromdat[$362b+i] | (srcromdat[$362b+i+1] << 8)) - $b65b + ub62b)
            .next
ub62bhi     .for i = 0, i < $30, i=i+2
                .byte >((srcromdat[$362b+i] | (srcromdat[$362b+i+1] << 8)) - $b65b + ub62b)
            .next
ub62b       .binary SRCROM, $365b,$190

            ;$91bf
            ;table goes:
            ;   byte - bonus loss rate
            ;   word - initial bonus
            ;   word - bonus loss timer reload
            ;   word - bar loss timer reload
oxytbl=[$02,$c8,$45,$34,
        $03,$12c,$40,$30,
        $04,$190,$38,$2a,
        ]
oxytbl_bonusrate
            .byte oxytbl[::4]
oxytbl_bonuslo
            .byte <oxytbl[1::4]
oxytbl_bonushi
            .byte >oxytbl[1::4]
oxytbl_bonusreload
            .byte oxytbl[2::4]
oxytbl_barreload
            .byte oxytbl[3::4]
            
            
            ;$aa7f
ladderdisptbllo .for i = 0, i < $10, i=i+2
                .byte <((srcromdat[$2a7f+i] | (srcromdat[$2a7f+i+1] << 8)) - $aacf + ladderdisptbl)
            .next
ladderdisptblhi .for i = 0, i < $10, i=i+2
                .byte >((srcromdat[$2a7f+i] | (srcromdat[$2a7f+i+1] << 8)) - $aacf + ladderdisptbl)
            .next
ladderdisptbl   .binary SRCROM,$2acf,$220
            
            
            ;$b2ee
laddertbllo .for i = 0, i < $50, i=i+2
                .byte <((srcromdat[$32ee+i] | (srcromdat[$32ee+i+1] << 8)) - $b33e + laddertbl)
            .next
laddertblhi .for i = 0, i < $50, i=i+2
                .byte >((srcromdat[$32ee+i] | (srcromdat[$32ee+i+1] << 8)) - $b33e + laddertbl)
            .next
laddertbl   .binary SRCROM,$333e,$184

            
            
            
            
game_main   ; ------------ $94c0 - handle oxygen
            ; -- try taking bonus
            lda g_oxybonus
            ora g_oxybonus+1
            beq _notakeoxybonus
            lda g_oxybonustimer
            bne _notakeoxybonus
            lda g_oxybonus
            sec
            sbc g_oxybonusrate
            sta g_oxybonus
            bcs +
            dec g_oxybonus+1
+           ldy #0
            jsr displayoxybonus
            
            ;$94f0
            lda g_oxylow
            lsr
            bcc _oxybonusmode0
            dec g_oxybonuslowticks
            beq _notakeoxybonus
            clc
            gcc _afteroxybonus
_oxybonusmode0
            sec
            dec g_oxybonuslowticks
            bne _afteroxybonus
            lda g_oxylow
            ora #1
            sta g_oxylow
            lda #$14
            sta g_oxybonuslowticks
            clc
_afteroxybonus
            ;for some reason the original code fetches the reload value
            ;again, but it's the same as was written in level init
            lda g_oxybonusreload
            bcs +
            asl
+           sta g_oxybonustimer
_notakeoxybonus
            ; -- try taking bar
            lda g_oxybartimer
            bne _notakeoxybar
            dec g_oxybar
            
            ;$ae8d - update display
            lda g_oxybar
            lsr
            lsr
            lsr
            sta temp
            lda g_oxybar
            and #7
            tax
            lda #FIRSTCOL+$15
            bit g_oxylow
            bpl +
            lda #FIRSTCOL+$1d
+           sec
            sbc temp
            tay
            lda oxybartbl,x
            sta line(2),y
            
            ;oxybar reload depends on if oxygen is low
            ;if so, $12, if not, value in reload var
            lda g_oxylow
            bpl _nolowoxy
            lda g_oxybar
            bne +
            lda #2
            rts
+           lda #$12
            gne _setoxybartimer
_nolowoxy   lda g_oxybar
            bne _skipmakeoxylow
            lda g_oxylow
            ora #$80
            sta g_oxylow
            lda #$40
            sta g_oxybar
            lda #4
            sta spritecol+7
            ldy #10
            jsr initsong
_skipmakeoxylow
            lda g_oxybarreload
_setoxybartimer
            sta g_oxybartimer
_notakeoxybar
            
            
            
            ; --------------------- $95cf - handle player
handleplayer
            lda p_flags
            lsr
            bcc +
            ldy p_timer
            bne _noplayer
+           asl
            sta p_flags
            
            ;lda p_flags
            and #4
            beq _nofall
            ldy p_y
            cpy #$b0
            beq _falldone
            jsr gethole
            bcc _keepfalling
            ldx p_x
            ldy p_y
            jsr checkholehere
            bcc _falldone
            lda holetable+1,y
            cmp #3
            bne _falldone
_keepfalling
            lda p_y
            clc
            adc #4
            sta p_y
            lda #PL_FALL
            gne _afterfall
_falldone   lda #4 ^ $ff
            and p_flags
            sta p_flags
            ldy #$12
            jsr initsong
            lda #PL_WALK0
_afterfall  sta p_frame
            jsr displayplayer
            lda #3
            gne _resetplayertimer
            
_nofall     ;in a single player game, player can use either port
            lda g_2player
            bne +
            lda joy
            ora joy+1
            jmp _gotinput
+           ;otherwise get the appropriate joystick
            lda g_flags
            and #1
            tax
            lda joy,x
_gotinput   tax
            and #$10
            bne _dig
            txa
            and #$0c
            bne _xmove
            txa
            and #3
            bne _ymove
            
_nomove     lda p_frame
            cmp #PL_WALK3+1
            bcs +
            lda #PL_WALK0
            sta p_frame
            jsr displayplayer
_resetplayertimer4
            lda #4
_resetplayertimer
            sta p_timer
            lda #1
            ora p_flags
            sta p_flags
+           jmp _afterplayer
            
            ; all of these routines accept the relevant joy buttons in A
            ; there is no need to special-case "no/invalid buttons pressed"
            
_xmove      ; ---- $963e player x movement
            
            ;try and see if the player is slightly lower or higher than platform
            ;if so, get him off the ladder and back on ground before x-moving
            ldx p_y
            ;grounded?
            cpx #$b0
            beq _xmovenormal
            cpx #$90
            beq _xmovenormal
            cpx #$70
            beq _xmovenormal
            cpx #$50
            beq _xmovenormal
            cpx #$30
            beq _xmovenormal
            ;need to move down first?
            ldy #4
            cpx #$b0-4
            beq _xmovev
            cpx #$90-4
            beq _xmovev
            cpx #$70-4
            beq _xmovev
            cpx #$50-4
            beq _xmovev
            cpx #$30-4
            beq _xmovev
            ;need to move up?
            ldy #-4
            cpx #$b0+4
            beq _xmovev
            cpx #$90+4
            beq _xmovev
            cpx #$70+4
            beq _xmovev
            cpx #$50+4
            beq _xmovev
            cpx #$30+4
            bne _afterxmove
_xmovev     cmp #8
            lda #0
            rol
            eor #1
            sta p_dir
            lda #PL_WALK0
            sta p_frame
            tya
            clc
            adc p_y
            sta p_y
            ldy #6
            jsr initsong
            jmp _afterxmove
            
            
_xmovenormal ; do actual movement
            ldy #4
            cmp #8
            lda #0
            rol
            eor #1
            sta p_dir
            beq +
            ldy #-4
+           tya
            ;clc
            adc p_x
            cmp #$10
            bcc _xbadmove
            cmp #$f1
            bcs _xbadmove
            ldy p_y
            cpy #$b0
            beq _setxmove
            sta _getxmove+1
            
            ;$a34f - don't let player walk over occupied hole
            ;if return with carry set goto _getxmove
                lda p_y
                clc
                adc #$04
                and #$f0
                tay
                jsr gethole
                
                ldx #MAX_HOLES
-               lda holetable,y
                bpl _a34f_next
                lda p_dir
                lsr
                lda p_x
                bcc +
                ;sec
                sbc #$0d
                cmp holetable+2,y
                bcs _a34f_next
                ;clc
                adc #$0c
                cmp holetable+2,y
                bcs _a34f_clc_return
                gcc _a34f_next
+               ;clc
                adc #$0c
                cmp holetable+2,y
                bcc _a34f_next
                ;sec
                sbc #$0c
                cmp holetable+2,y
                bcc _a34f_clc_return
_a34f_next      .rept HOLE_SIZE
                    iny
                .next
                dex
                bne -
                beq _getxmove
_a34f_clc_return
            lda holetable,y
            lsr
            bcs _xbadmove
            
            ;$96a2 - don't let player walk over half-dug hole
            jsr checkplayerfacinghole
            bcs _getxmove
            lda holetable+1,y
            cmp #3
            bne _xbadmove
            
            ;$96b1 - don't let player fall if there is an occupied hole below
            lda #$0c
            ldx p_dir
            beq +
            lda #-$0c
+           clc
            adc p_x
            sta temp
            ldy p_y
-           cpy #$b0
            beq _getxmove
            tya
            clc
            adc #$20
            tay
            sty temp+1
            ldx temp
            jsr checkholehere
            bcc _getxmove
            lda holetable,y
            lsr
            bcs _xbadmove
            lda holetable+1,y
            ldy temp+1
            cmp #3
            beq -
            
            ;$96df - update xpos and walk
_getxmove   lda #0
_setxmove   sta p_x
            ldx p_walk
            inx
            txa
            and #3
            sta p_walk
            clc
            adc #PL_WALK0
            sta p_frame
            ldy #6
            jsr initsong
            jmp _afterxmove
            
_xbadmove   lda #0
            sta p_walk
            lda #PL_WALK3
            sta p_frame
            
_afterxmove 
            jsr displayplayer
            
            ;$9723 - check if we need to fall
            ldx p_x
            ldy p_y
            jsr checkholehere
            bcc +
            lda holetable+1,y
            cmp #3
            bne +
            lda #4
            ora p_flags
            sta p_flags
            ldy #4
            jsr initsong
            
+           jmp _resetplayertimer4
            
            
            
_ymove      ; ---- $9759 player y movement
            
            tax
            
            lda p_dir
            and #2
            bne _yclimbing
            
_ychecklad  jsr checkplayerladder
            bcc _afterymove
            
            lda checkplayerladder._joy+1
_ydoclimb   ldy #-4
            cmp #2
            lda #1
            rol
            ;eor #1 ;maybe?
            sta p_dir
            lsr
            bcc +
            ldy #4
+           tya
            clc
            adc p_y
            sta p_y
            
            ldx p_frame
            inx
            cpx #PL_CLIMB1
            beq +
            ldx #PL_CLIMB0
+           stx p_frame
            
            ldy #5
            jsr initsong
            
_afterymove 
            jsr displayplayer
            jmp _resetplayertimer4
            
_yclimbing  txa
            ldy p_y
            cpy #$b0
            beq _ychecklad
            cpy #$90
            beq _ychecklad
            cpy #$70
            beq _ychecklad
            cpy #$50
            beq _ychecklad
            cpy #$30
            beq _ychecklad
            gne _ydoclimb
            
            
            
_canceldig  jsr displayplayer
            jmp _noplayer
            
_dig        ; $9822 ----- dig hole
            
            
            ;we know fire is pressed - use the joystick to figure out
            ;if player wants to dig or undig
            ;in the original routine, bit 0 of input is undig and 4 is dig
            txa
            and #$0f
            beq _canceldig ;no action

            ldy p_y
            cpy #$b0
            beq _disallowdig
            ldy p_frame
            cpy #PL_CLIMB0
            beq _disallowdig
            cpy #PL_CLIMB1
            beq _disallowdig
            
            lsr ;up is always undig
            bcs _setundig
            lsr ;down is always dig
            bcs _setdig
            ;now, bit 0 is left and bit 1 is right
            ldx p_dir ;test the other direction if facing left
            beq +
            lsr
+           lsr ;left is undig if facing right
            bcs _setundig
_setdig     lda #0
            beq +
_setundig   lda #1
+           sta temp+5
            
            cpy #PL_DIG0
            beq _alreadydig
            cpy #PL_DIG1
            beq _alreadydig
            
            ;$983a - not already digging
            jsr checkplayerfacinghole
            bcc _digoccupied
            lda temp+5 ;can't undig with no hole!
            bne _disallowdig
            ;see if we can dig a new hole
            lda #6
            ldx p_dir
            beq +
            lda #-$12
+           clc
            adc p_x
            cmp #9
            bcc _disallowdig
            cmp #$f8-$0c
            bcs _disallowdig
            sta temp
            ldy p_y
            jsr gethole
            ;check if there is already a misaligned hole here
            ;the original game loops through this twice with the modded xpos
            ;as well as that + $0c, here there is just extra compares in the loop
            ldx #MAX_HOLES
-           lda holetable+1,y
            beq _chkdignext
            lda holetable+2,y
            sec
            sbc #$0b
            cmp temp
            bcs +
            ;clc
            adc #$16
            cmp temp
            bcs _disallowdig
+           lda holetable+2,y
            sec
            sbc #+($0b + $0c)
            cmp temp
            bcs _chkdignext
            ;clc
            adc #$16
            cmp temp
            bcs _disallowdig
_chkdignext .rept HOLE_SIZE
                iny
            .next
            dex
            bne -
            ; check if there is a ladder here
            lda p_y
            ldx #1
            cmp #$90
            beq +
            inx
            cmp #$70
            beq +
            inx
            cmp #$50
            beq +
            inx
+           lda g_laddertbllo,x
            sta temp+1
            lda g_laddertblhi,x
            sta temp+2
            ldy #0
            lax (temp+1),y
            iny
-           lda (temp+1),y
            sec
            sbc #8
            cmp temp
            bcs +
            ;clc
            adc #$10
            cmp temp
            bcs _disallowdig
+           lda (temp+1),y
            sec
            sbc #+($08 + $0c)
            cmp temp
            bcs +
            ;clc
            adc #$10
            cmp temp
            bcs _disallowdig
+           iny
            iny
            dex
            bne -
            ;all ok, prepare player for digging
            lda #PL_DIG1
            clc
            adc temp+5
_digwait    sta p_frame
            jsr displayplayer
            lda p_frame
            cmp #PL_DIG1
            bne +
            ldy #9
            jsr initsong
+           lda #$0f
            jmp _resetplayertimer
            
_alreadydig ;$98ea - already digging
            jsr checkplayerfacinghole ;already a hole here?
            bcc _digoccupied ;ok, we have the index, skip below
            ;check for the first free hole slot
            ldy p_y
            jsr gethole
-           lda holetable,y
            bpl _digoccupied
            .rept HOLE_SIZE
                iny
            .next
            gne -
_digoccupied
            ;$9904 - we already have a hole index in Y, so skip above stuff
            lda temp+5
            bne _undigmode
            lda holetable,y ;can't dig an occupied hole
            lsr
            bcs _disallowdig
            lda holetable+1,y ;fully dug already?
            cmp #3
            beq _disallowdig
            ldx p_frame ;only dig on transitions from dig1 -> dig0
            inx
            txa
            cmp #PL_DIG1
            beq _digwait
            tya ;dig one more level
            tax
            inc holetable+1,x
            lda #$80
            ora holetable,y
            sta holetable,y
            lda #$0c
            ldx p_dir
            beq +
            lda #-$0c
+           clc
            adc p_x
            sta holetable+2,y
            jsr displayhole
            lda #PL_DIG0
            gne _digwait
            
_undigmode  ;$993e - undig hole
            lda holetable+1,y ;already undug
            beq _disallowdig
            lda #PL_DIG0
            cmp p_frame
            bne _digwait
            tya ;undig level
            tax
            dec holetable+1,x
            bne +
            lda holetable,y ;don't deactivate if occupied
            lsr             ;(presumably so enemies can die)
            bcs +
            rol
            and #$7f
            sta holetable,y
+           jsr displayhole
            lda #PL_DIG1
            gne _digwait
            
            
_disallowdig
            ldy #$0f
            jsr initsong
            lda #2
            sta p_buzzmutetimer
_afterdig   lda #$0d
            jmp _resetplayertimer
            
            
            
_afterplayer
            lda p_buzzmutetimer
            beq +
            dec p_buzzmutetimer
            bne +
            lda #8
            ora soundmute
            sta soundmute
+           
_noplayer   
            
            ; ------------------- $9a05 handle one enemy
handleenemy ldx g_curenemy
            inx
            cpx #ENEMIES
            bcc +
            ldx #0
+           stx g_curenemy
            
            lda e_timer,x
            bne _noenemy
            lda e_flags,x
            bpl _noenemy
            bit bitmasktbl+4
            beq +
            and #$ef
            sta e_flags,x
            tay
            lda #$10
            ora soundmute
            sta soundmute
            tya
+           bit bitmasktbl+5
            bne _escaping
            bit bitmasktbl+6
            bne _trapped
            
            ;---------- $9dd7 enemy walking
            lda e_x,x
            ldy e_y,x
            clc
            adc #$0c
            tax
            jsr checkholehere
            ldx g_curenemy
            bcs +
            lda e_x,x
            ldy e_y,x
            sbc #$0c - 1
            tax
            jsr checkholehere
            ldx g_curenemy
            bcc ++
+           lda holetable,y ;don't let enemy walk over occupied hole
            lsr
            bcs _moveok
+           
            ;$9dfe
            ldy e_y,x
            lda e_x,x
            tax
            jsr checkladderhere
            ldx g_curenemy
            bcs _moveladder
            
            ;adjust movement
            lda e_dir,x
            cmp #2 ;which axis are we moving?
            lda e_y,x
            bcs +
            lda e_x,x
+           sta temp
            cmp #$10 ;flip direction?
            beq +
            cmp #$f0
            bne ++
+           lda e_dir,x
            eor #1
            sta e_dir,x
+           lda e_dir,x ;now apply direction
            cmp #2
            bcs +
            eor #1
+           lsr
            lda #-4
            bcc +
            lda #4
            clc
+           adc temp
            tay
            lda e_dir,x
            cmp #2
            bcs +
            sty e_x,x
            gcc ++
+           sty e_y,x
+           
            ;$9e2e check enemy<->enemy collision
            jsr checkintraenemycollision
            bcc _moveok
            ;collision, change direction
            sta e_dir,x
_moveok     
            ;$9f6e player kill pre-checks
            ldy e_y,x
            jsr gethole
            bcc _chkkill
            lda #MAX_HOLES
            sta temp
-           lda holetable,y
            bpl +
            lda holetable+2,y
            sec
            sbc #9
            cmp e_x,x
            bcs +
            ;clc
            adc #$12
            cmp e_x,x
            bcs _skipchkkill
+           .rept HOLE_SIZE
                iny
            .next
            dec temp
            bne -
            
_chkkill    ;$9f95 check if should kill player
                ;$a400
                lda e_y,x
                sec
                sbc #9
                cmp p_y
                beq +
                bcs _skipchkkill
+               clc
                adc #$1a
                cmp p_y
                bcc _skipchkkill
                lda e_x,x
                ;sec
                sbc #$0b
                bcs +
                lda #0
+               cmp p_x
                beq +
                bcs _skipchkkill
+               lda e_x,x
                clc
                adc #$0b
                bcc +
                lda #$ff
+               cmp p_x
                bcc _skipchkkill
                
                ; ------ $9d81 kill player
                lda #$1f
                sta soundmute
                lda #0
                sta p_dir
                lda #PL_CAUGHT
                sta p_frame
                lda #EN_CATCH
                sta e_frame,x
                lda p_x
                sec
                sbc #2
                sta e_x,x
                lda p_y
                sta e_y,x
                jsr displayplayer
                jsr displayenemy
                
                ldy #8
                jsr initsong
                lda #$3e
                jsr waitgames
                
                ldy #$0d
                jsr initsong
                lda #$b4
                jsr waitgames
                
                lda #1
                rts
            
            
_skipchkkill
            ;$9fa4 check for fall
            lda e_x,x
            ldy e_y,x
            tax
            jsr checkholehere
            ldx g_curenemy
            bcc _walkresetenemytimerreload
            lda holetable,y
            ora #1
            sta holetable,y
            lda holetable+1,y
            cmp #3
            bne _initfallnotfull
            lda e_flags,x
            ora #$40
            sta e_flags,x
            lda e_y,x
            clc
            adc #$0c
            sta e_y,x
            lda #$1a
            sta e_escapecnt,x
            ldy #7
            jsr initsong
            ldx g_curenemy
            lda #5
            gne _walkresetenemytimer
            
_initfallnotfull
            cmp #2
            lda e_y,x
            bcc +
            adc #5 - 1
            gcc ++
+           adc #3
+           sta e_y,x
            lda e_flags,x
            ora #$20
            sta e_flags,x
            lda #EN_WALK1
            sta e_frame,x
            
_walkresetenemytimerreload
            lda g_enemyspeed
_walkresetenemytimer
            sta e_timer,x
            ldy e_frame,x
            iny
            cpy #EN_WALK1
            beq +
            ldy #EN_WALK0
+           sty e_frame,x
            jsr displayenemy
            jmp _afterenemy
            
            
_moveladder ;$9e74 alt movement routine for when ladder is found
            ;ladder ptr is in (temp),y
            iny
            lda (temp),y ;allowed movements on ladder
            sta temp
            
            ldy #0 ;targeting flags
            lda p_y
            cmp e_y,x
            bcs +
            iny
+           lda p_x
            cmp e_x,x
            bcs +
            tya
            ora #2
            tay
+           sty temp+1
            
            ;$9e8b
-           jsr rand
            cmp #$c9
            bcs -
            tay
            beq -
            cmp e_iq,x
            bcc +
            lda temp+1
            eor #3
            ora #$80
            sta temp+1
            gmi _noenemylad
+           lda p_y
            cmp e_y,x
            bne +
            lda temp+1
            ora #$40
            sta temp+1
            gne _noenemylad
+           
            ;$9eae
            lda temp+1
            lsr
            lda temp
            bcs +
            lsr
+           lsr
            bcs _noenemylad
            
            ldy #0
            lda e_y,x
            cmp #$b0
            beq +
            iny
            cmp #$90
            beq +
            iny
            cmp #$70
            beq +
            iny
            cmp #$50
            beq +
            iny
+           lda g_laddertbllo,y
            sta temp+2
            lda g_laddertblhi,y
            sta temp+3
            ldy #0
            lda (temp+2),y
            sta temp+4
            iny
_enemyladloop
            lda temp+1
            lsr
            lsr
            lda e_x,x
            bcc +
            cmp (temp+2),y
            bcs _enemyladloop2
            gcc _enemynextlad2
+           cmp (temp+2),y
            beq _enemyladloop2
            bcs _enemynextlad2
_enemyladloop2
            iny
            lda temp+1
            lsr
            lda (temp+2),y
            bcs +
            lsr
+           lsr
            bcs _enemyladfound
            
            .byte $80 ;nop #$xx
_enemynextlad2
            iny
_enemynextlad1
            iny
            dec temp+4
            bne _enemyladloop
-           lda temp+1
            eor #2
            sta temp+1
            jmp _noenemylad
_enemyladfound
            jsr rand
            asl
            bcc -
            
_noenemylad ;$9f0d
            lda temp+1
            lsr
            lda temp
            bcs +
            lsr
+           lsr
            bcc _enemyladmovex
            
            lda temp+1
            and #$40
            bne _enemyladmovex
            jsr rand
            asl
            bcs _enemyladmovex
            
            ldy #4
            lda temp+1
            lsr
            bcc +
            ldy #-4
+           tya
            clc
            adc e_y,x
            sta temp
            
            tya
            asl
            lda #3
            bcc +
            lda #2
+           sta temp+1
            
            ;useless call to checkintraenemycollision here
                ;$a9e5
                lda #0
                sta temp+2
                ldy #ENEMIES-1
-               lda e_flags,y
                bpl _enemyymovenext
                lda temp+1
                lsr
                lda temp
                bcs +
                cmp e_y,y
                bcc _enemyymovenext
                ;sec
                sbc #$38
                cmp e_y,y
                bcc _enemyymovenextinc
                beq _enemyymovenextinc
                gcs _enemyymovenext
+               cmp e_y,y
                beq +
                bcs _enemyymovenext
+               clc
                adc #$38
                cmp e_y,y
                bcc _enemyymovenext
_enemyymovenextinc
                inc temp+2
_enemyymovenext dey
                bpl -
                lda temp+2
                cmp #3
            bcs _moveok
            lda temp
            ldy temp+1
            sta e_y,x
            sty e_dir,x
            
            jmp _moveok
_enemyladmovex
            ;$9f4b
            ldy #4
            lda temp+1
            and #2
            beq +
            ldy #-4
+           tya
            clc
            adc e_x,x
            sta e_x,x
            
            tya
            asl
            lda #0
            rol
            sta e_dir,x
            
            ;another useless call to checkintraenemycollision here...
            
            jmp _moveok
            
            
            
_escaping   ;---------- $9cc0 enemy escaping
            dec e_y,x
            ldy e_frame,x
            iny
            cpy #EN_WALK1
            beq +
            ldy #EN_WALK0
+           sty e_frame,x
            jsr displayenemy
            
            lda e_y,x
            cmp #$90
            beq _escapedone
            cmp #$70
            beq _escapedone
            cmp #$50
            beq _escapedone
            cmp #$30
            beq _escapedone
            ;still escaping, check if the enemy should be killed
            and #$0f
            cmp #$06 ;is it too late?
            bcc _escapenext
            lda e_y,x ;is the hole undug?
            and #$f0
            tay
            lda e_x,x
            tax
            jsr checkholehere
            ldx g_curenemy
            lda holetable+1,y
            bne _escapenext
            ;lda #0
            sta holetable,y
            lda #3
            ora soundmute
            sta soundmute
            gne _enemyfall
            
_escapenext ;$9d12
            lda #$14
            sta e_timer,x
            ldy #$0c
            jsr initsong
            jmp _afterenemy
            
_escapedone ;... $9d23 done escaping
            lda g_enemyspeed
            sta e_timer,x
            lda #2
            ora soundmute
            sta soundmute
            lda e_flags,x
            and #$20 ^ $ff
            sta e_flags,x
            ldy e_y,x
            lda e_x,x
            tax
            jsr checkholehere
            bcc _afterenemy
            sty temp
            ldx g_curenemy
            lda e_flags,x
            and #$40
            beq _escapedisplayhole
            eor e_flags,x
            sta e_flags,x
            ;see if we need to power up the enemy
            lda e_type,x
            cmp #3
            beq _escapedisplayhole
            lda g_flags
            and #1
            tay
            lda g_round,y
            cmp #1
            beq _escapedisplayhole
            inc e_type,x
            lda e_iq,x
            clc
            adc g_enemyiqadd
            bcs _escapedisplayhole
            sta e_iq,x
_escapedisplayhole
            ldy temp
            lda #0
            sta holetable,y
            sta holetable+1,y
            jsr displayhole
            jmp _afterenemy
            
            
_trapped    ;---------- $9a5f enemy trapped
            ;enemy dug?
            lda e_y,x
            and #$f0
            tay
            lda e_x,x
            tax
            jsr checkholehere
            ldx g_curenemy
            lda holetable+1,y
            beq _trappedkill
            ldy e_frame,x
            iny
            cpy #EN_ESCAPE1
            beq +
            ldy #EN_ESCAPE0
+           sty e_frame,x
            lda #5
            sta e_timer,x
            jsr displayenemy
            dec e_escapecnt,x
            beq +
            ldy #7
            jsr initsong
            jmp _afterenemy
            
+           lda #1
            ora soundmute
            sta soundmute
            lda e_flags,x
            ora #$20
            sta e_flags,x
            gne _afterenemy
            
_trappedkill
            lda #0
            sta holetable,y
            lda #1
            ora soundmute
            sta soundmute
            ; ... fall through ...
            ;---------- $9ab3 make enemy fall
_enemyfall  
            ldy #4
            jsr initsong
            ldx g_curenemy
            
_fallloop   ;$9ac7, allow for "chaining" enemy falls
            lda e_y,x
            sta temp
            lda e_x,x
            sta temp+1
            ldx #ENEMIES-1
-           lda e_flags,x
            bpl ++
            lda e_y,x
            cmp temp
            bne ++
            lda e_x,x
            cmp temp+1
            bne ++
            lda #EN_WALK0
            sta e_frame,x
            jsr displayenemy
            lda e_y,x
            cmp #$b0
            beq +
            cmp #$90
            beq +
            cmp #$70
            beq +
            cmp #$50
            beq +
            cmp #$30
            bne ++
+           inc e_fallcnt,x
+           dex
            bpl -
            
            lda #$13
            ora soundmute
            sta soundmute
            
            ;$9b07 check if hit ground
            ldy temp
            cpy #$b0
            beq +
            cpy #$90
            beq +
            cpy #$70
            beq +
            cpy #$50
            beq +
            cpy #$30
            bne _nohitground
+           
            ldx temp+1
            jsr checkholehere
            bcc +
            lda holetable+1,y
            pha
            lda #0
            sta holetable,y
            sta holetable+1,y
            lda temp
            pha
            lda temp+1
            pha
            jsr displayhole
            pla
            sta temp+1
            pla
            sta temp
            pla
            cmp #3
            beq _nohitground
+           lda #1
            sta temp
            jmp _fallnext
_nohitground
            ldx #ENEMIES-1
-           lda e_flags,x
            bpl +
            lda e_y,x
            cmp temp
            bne +
            lda e_x,x
            cmp temp+1
            bne +
            inc e_y,x
+           dex
            bpl -
            
            lda #0
            sta temp
_fallnext   ;$9b4c
            jsr waitgame
            ldx g_curenemy
            lda temp
            beq _fallloop
            
            
            
            ;$9b5c enemy hit floor
            ldy #$12
            jsr initsong
            lda #$0a
            jsr waitgames
            ldx g_curenemy
            
            lda e_fallcnt,x
            cmp e_type,x
            bcs _killenemy
            
            ;$9b9e not enough falls
            
            ;check for dropping an enemy on another enemy
            lda #0
            sta temp
            ldy #ENEMIES-1
-           jsr checkfallcollision
            bcc +
            inc temp
+           dey
            bpl -
            lda temp
            cmp #2
            bcs _killenemy
            
            ;not enough falls, don't kill enemy
            lda e_flags,x
            and #$60 ^ $ff
            ora #$10
            sta e_flags,x
            lda #0
            sta e_fallcnt,x
            
            lda #$3e
            sta e_timer,x
            
            jsr displayenemy
            
            ldy #$10
            jsr initsong
            jmp _afterenemy
            
_killenemy  ;$9bd2 ok, kill enem(y/ies)
            lda #0 ;bonus score
            sta temp
            sta temp+1
            
            ldy #ENEMIES-1
_killloop   jsr checkfallcollision
            bcc _nextkill2
            sty temp+2
            
            lda e_flags,y
            and #$7f
            sta e_flags,y
            
            lda e_type,y
            asl
            asl
            sbc #4-1
            sta temp+3
            lda e_fallcnt,y
            beq +
            ;sec
            sbc #1
+           ora temp+3
            tay
            lda enemyscoretbl,y
            clc
            adc temp
            sta temp
            bcc +
            inc temp+1
+           
            ldx temp+2
            jsr displayenemy
            ldx g_curenemy
            
            ;make other enemies smarter
            ldy #ENEMIES-1
-           lda e_flags,y
            bpl +
            lda e_iq,y
            clc
            adc g_enemyiqadd
            bcs +
            sta e_iq,y
+           dey
            bpl -
            
_nextkill   ldy temp+2
_nextkill2  dey
            bpl _killloop
            
            
            ;$9c47 show bonus
            jsr waitframe
            ;the original uses sprites, i use the screen
            lda temp
            pha
            lda temp+1
            pha
            jsr numconvtemp
            ldx g_curenemy
            lda e_y,x
            lsr
            lsr
            lsr
            tay
            lda e_x,x
            lsr
            lsr
            lsr
            clc
            adc #+(FIRSTCOL-7)
            adc linetbllo-1,y
            sta temp+2
            sta temp+4
            lda linetblhi-1,y
            sta temp+3
            eor #(>screen) ^ $d8
            sta temp+5
            
            ;the highest possible bonus is 1200 * 7 = 8400
            ldy #3
-           lda (temp+2),y
            sta bonusscreensave,y
            dey
            bpl -
            
            iny
-           lda numconvresult+2,y
            cmp #$d8
            bne +
            iny
            cpy #3
            bcc -
            gcs _bonusprintdone
-           lda numconvresult+2,y
+           sta (temp+2),y
            lda #1
            sta (temp+4),y
            iny
            cpy #3
            bcc -
_bonusprintdone
            lda #$d8
            sta (temp+2),y
            lda #1
            sta (temp+4),y
            
            ;$9c4a update score
            pla
            tay
            pla
            jsr addscore
            lda #$3e
            jsr waitgames
            
            ;$9c78 hide bonus
            ldy #3
-           lda bonusscreensave,y
            sta (temp+2),y
            lda #4
            sta (temp+4),y
            dey
            bpl -
            
            
            ;$9c87, check if all enemies are gone
            lda e_flags+0
            .for i = 1, i < ENEMIES, i=i+1
                ora e_flags+i
            .next
            bmi _afterenemy
            lda #0
            rts
            
            
_afterenemy 
            
_noenemy    
            
            
            ; ............ CUSTOM, pause game
            bit key+7
            bpl _nopause
            lda #1
            sta pauseflag
-           bit key+7
            bmi -
            
-           jsr waitframe
            lda gamecnt
            and #$10
            cmp #$10
            ldx #size(pausetext)-1
-           lda pausetext,x
            bcc +
            lda #0
+           sta line(3)+FIRSTCOL+((32-size(pausetext))/2)+1,x
            dex
            bpl -
            bit key+7
            bpl --
            
            lda #0
            ldx #size(pausetext)-1
-           sta line(3)+FIRSTCOL+((32-size(pausetext))/2)+1,x
            dex
            bpl -
-           bit key+7
            bmi -
            sta pauseflag
_nopause    
            
            
            jmp game_main
            
            .enc "pause"
            .cdef "  ",0
            .cdef "AZ",$e2
pausetext   .text "PAUSE"
            .enc "none"
            
            
bonusscreensave
            .fill 4
            
            
enemyscoretbl
            ;bonus points are awarded based on how many holes the enemy fell
        .byte $0a,$14,$1e,$32 ;enemy type 1
        .byte $1e,$1e,$32,$50 ;enemy type 2
        .byte $50,$50,$50,$78 ;enemy type 3
            
            
            ;this routine should ONLY be called when player is on ground
            ;takes joy input in X
            ;returns carry set if player can grab ladder
checkplayerladder   ;$97c2
            stx _joy+1
            lda p_y
            ldx #0
            cmp #$b0
            beq +
            inx
            cmp #$90
            beq +
            inx
            cmp #$70
            beq +
            inx
            cmp #$50
            beq +
            inx
+           lda g_laddertbllo,x
            sta temp
            lda g_laddertblhi,x
            sta temp+1
            ldy #0
            lax (temp),y
            iny
            
_loop       lda (temp),y
            cmp p_x
            beq _found
            sec
            sbc #4
            cmp p_x
            beq _found
            clc
            adc #8
            cmp p_x
            beq _found
            iny
            iny
            dex
            bne _loop
_clcret     clc
            rts
            
_found      lax (temp),y ;save x-pos for later saving
            
_joy        lda #0
            iny
            ;warning: may need to switch the up/down bits around first?
            and (temp),y
            beq _clcret
            
            stx p_x ;snap player to ladder position
            
            sec
_ret        rts
            
            
            
            ;$a5ef - check if ladder at xpos in X and ypos in Y
            ;carry clear if not, otherwise ladder pointer in (temp),y
            ;   ___unlike original game___, which flips carry
checkladderhere
            stx _x+1
            ldx #0
            cpy #$b0
            beq +
            inx
            cpy #$90
            beq +
            inx
            cpy #$70
            beq +
            inx
            cpy #$50
            beq +
            cpy #$30
            bne _clcret
            inx
+           lda g_laddertbllo,x
            sta temp
            lda g_laddertblhi,x
            sta temp+1
            ldy #0
            lax (temp),y
            iny
_x          lda #0
-           cmp (temp),y
            beq _ret
            iny
            iny
            dex
            bne -
_clcret     clc
_ret        rts
            



            ;$a4f0 - get hole table index for y position in Y
            ;carry set if valid, ___unlike the original game___
gethole     cpy #$30
            beq _3
            cpy #$50
            beq _2
            cpy #$70
            beq _1
            cpy #$90
            beq _0
            clc
            rts
_0          ldy #0
            rts
_1          ldy #(MAX_HOLES*HOLE_SIZE)*1
            rts
_2          ldy #(MAX_HOLES*HOLE_SIZE)*2
            rts
_3          ldy #(MAX_HOLES*HOLE_SIZE)*3
            rts
            
            
            ;$a318
            ;carry set if there is no hole where the player would dig
            ;           ___unlike the original game___, which flips carry
            ;also expects the index of the found hole to be in Y
checkplayerfacinghole
            ldy p_y
            jsr gethole
            
            lda #$0c
            ldx p_dir
            beq +
            lda #-$0c
+           clc
            adc p_x
            tax
            
            lda #MAX_HOLES
            sta temp
            
-           lda holetable,y
            bpl _next
            txa
            cmp holetable+2,y
            beq _no
_next       .rept HOLE_SIZE
                iny
            .next
            dec temp
            bne -
            sec
            rts
_no         clc
            rts
            
            
            ;$a52a - check if hole at xpos in X and ypos in Y
            ;carry set if so, hole index in Y
checkholehere
            stx _x+1
            jsr gethole
            bcc _ret
            
            ldx #MAX_HOLES
-           lda holetable,y
            bpl _next
_x          lda #0
            cmp holetable+2,y
            beq _ret
_next       .rept HOLE_SIZE
                iny
            .next
            dex
            bne -
            clc
_ret        rts



            ;enemy id in X
            ;carry clear = no collision
            ;carry set = collision, with new direction in A
checkintraenemycollision
            stx _this+1
            ldy #ENEMIES-1
_loop       
_this       cpy #0
            beq _skip
            lda e_flags,y
            bpl _skip
            lda e_y,x
            clc
            adc #$0c
            cmp e_y,y
            bcc _skip
            lda e_y,y
            clc
            adc #$0c
            cmp e_y,x
            bcc _skip
            lda e_x,x
            clc
            adc #$0c
            cmp e_x,y
            bcc _skip
            lda e_x,y
            clc
            adc #$0c
            cmp e_x,x
            bcs _found
_skip       dey
            bpl _loop
_clcret     clc
_ret        rts

_found      lda e_dir,x
            cmp #2
            bcs +
            lda e_x,y
            cmp e_x,x
            lda #0
            bcc _secret
            lda #1
            gcs _ret
+           lda e_y,y
            cmp e_y,x
            lda #2
            bcs _ret
            lda #3
_secret     sec
            rts
            



            ;$a68e
            ;enemies to compare in X and Y, carry set if ok
checkfallcollision
            lda e_flags,y
            bpl _clcret
            lda e_y,y
            ;hotpatch at $bb00
            cmp e_y,x
            beq +
            sec
            sbc #4
            cmp e_y,x
            bne _clcret
+           ;and back to $a69d
            lda e_x,y
            clc
            adc #4
            cmp e_x,x
            bcc _ret
            ;sec
            sbc #8
            cmp e_x,x
            beq _ret
            bcc _secret
_clcret     clc
_ret        rts
_secret     sec
            rts
            
            
            
            
oxybartbl   .byte $00,$76,$75,$74,$73,$72,$71,$70
            
            
            
            
            
            
            ;;;;;;;;;;;;;;;;;;;;;; $a00e - level complete or dead
game_end    ldx #$1f
            stx soundmute
            
            tax
            bne _nolevelcomplete
            ; ------- $a028 - do level complete scene
            ldy #2
            jsr initsong
            
            lda #$12
            sta temp+5
-           lda temp+5
            lsr
            lda #1
            bcs +
            ldy #5
            jsr copystring
            ;lda g_oxybonus
            ;ora g_oxybonus+1
            ;beq _next
            ldy #1
            jsr displayoxybonus
            jmp _next
+           ldy #$0e
            jsr copystring
_next       lda #$10
            jsr waitgames
            dec temp+5
            bne -
            
            lda g_flags
            and #1
            tax
            inc g_round,x
            lda g_oxybonus
            ldy g_oxybonus+1
            jsr addscore
            
            lda #1
            rts
            
_nolevelcomplete
            cmp #2
            bne _nooxydeath
            ; ------ $a097 - do out of oxygen death animation
            ;first, see if we need to fall before the main animation
            ;ladder-wise
            lda p_dir
            cmp #2
            bcc +
            ;$a0d7
_fallloop   lda p_y
            cmp #$b0
            beq _startmainanim
            cmp #$90
            beq +
            cmp #$70
            beq +
            cmp #$50
            beq +
            cmp #$30
            bne _startfall
+           ;$a09e
            ldx p_x
            ldy p_y
            jsr checkladderhere
            bcc _ladderfalldone
            iny
            lda (temp),y
            and #2
            beq _startmainanim
            ldy #4
            jsr initsong
_startfall  ;$a0b6
            inc p_y
            lda #PL_CLIMB1
            sta p_frame
            jsr displayplayer
            jsr waitgame
            jmp _fallloop
            
_ladderfalldone
            ;$a0e1 - see if the player was already falling
            lda p_flags
            and #4
            beq _startmainanim
-           lda p_y
            cmp #$b0
            beq _startmainanim
            cmp #$90
            beq +
            cmp #$70
            beq +
            cmp #$50
            beq +
            cmp #$30
            bne _keepfalling
+           ldx p_x
            ldy p_y
            jsr checkholehere
            bcc _startmainanim
            lda holetable+1,y
            cmp #3
            bne _startmainanim
_keepfalling
            ;$a104
            lda p_y
            clc
            adc #4
            sta p_y
            lda #PL_FALL
            sta p_frame
            jsr displayplayer
            lda #6
            jsr waitgames
            jmp -
            
            ;$a12b - main animation
_startmainanim
            lda p_dir
            and #1
            sta p_dir
            ldx #size(deathanimtbl)-1
-           lda deathanimtbl,x
            bpl +
            lda p_dir
            eor #1
            sta p_dir
            dex
            lda deathanimtbl,x
+           clc
            adc #PL_OXYOUT0
            sta p_frame
            jsr displayplayer
            lda #$1e
            jsr waitgames
            dex
            bpl -
            ldy #$0d
            jsr initsong
            lda #$b4
            jsr waitgames
            
            
_nooxydeath 
            ; ------- $a16a - take a life, see if it's game over
            lda #0
            sta spriteen
            lda g_flags
            and #1
            tax
            dec g_lives,x
            bne _notgameover
            ;$a17d - game over!
            eor #1 ;have all players lost?
            tax
            lda g_lives,x
            beq _finalgameover
            lda g_flags
            lsr
            lda #$0b
            adc #$00
            tay
            lda #1
            jsr copystring
            lda #$bb
            jsr waitgames
_notgameover
            ;$a1bc - not game over, see if we can switch player
            eor #1
            tax
            lda g_lives,x
            beq +
            lda g_flags
            eor #1
            sta g_flags
+           lda #1
            rts
            
_finalgameover
            ldx #1 ;update high score
-           lda g_scorelo,x
            cmp g_hiscorelo
            lda g_scorehi,x
            sbc g_hiscorehi
            bcc +
            lda g_scorelo,x
            sta g_hiscorelo
            lda g_scorehi,x
            sta g_hiscorehi
+           dex
            bpl -
            ldy #0
            jsr displayscore
            
            lda g_flags
            lsr
            lda #$0b
            adc #$00
            tay
            lda #1
            jsr copystring
            ldy #3
            jsr initsong
            lda #$be
            jsr waitgames
            ldx #0
-           lda #4
            jsr waitgames
            lda joy
            ora joy+1
            and #$10
            bne +
            dex
            bne -
+           lda #2
            rts
            
            
deathanimtbl .byte [0, 1, 2, 3, 4, 5, 4, $ff, 5, 6][::-1]
            
            
            .if * < $2000
                * = $2000
                .warn "wasting space for sprites"
            .endif
            .align $40
PLAYER_SPRITE = (* & $3fc0) / $40
PL_WALK0    = PLAYER_SPRITE+$00
PL_WALK1    = PLAYER_SPRITE+$01
PL_WALK2    = PLAYER_SPRITE+$02
PL_WALK3    = PLAYER_SPRITE+$03
PL_CLIMB0   = PLAYER_SPRITE+$04
PL_CLIMB1   = PLAYER_SPRITE+$05
PL_FALL     = PLAYER_SPRITE+$06
PL_DIG0     = PLAYER_SPRITE+$07
PL_DIG1     = PLAYER_SPRITE+$08
PL_CAUGHT   = PLAYER_SPRITE+$09
PL_OXYOUT0  = PLAYER_SPRITE+$0a
PL_OXYOUT1  = PLAYER_SPRITE+$0b
PL_OXYOUT2  = PLAYER_SPRITE+$0c
PL_OXYOUT3  = PLAYER_SPRITE+$0d
PL_OXYFALL0 = PLAYER_SPRITE+$0e
PL_OXYFALL1 = PLAYER_SPRITE+$0f
PL_OXYFALL2 = PLAYER_SPRITE+$10
PL_FLIPADD  = $11
            .binary "player-sprites.bin"
            .align $40
ENEMY_SPRITE = (* & $3fc0) / $40
EN_WALK0    = ENEMY_SPRITE+$00
EN_WALK1    = ENEMY_SPRITE+$01
EN_ESCAPE0  = ENEMY_SPRITE+$02
EN_ESCAPE1  = ENEMY_SPRITE+$03
EN_CATCH    = ENEMY_SPRITE+$04
EN_TYPE0 = 0
EN_TYPE1 = 5
EN_TYPE2 = 10
            .binary "enemy-sprites.bin"
            
            
            .cerror * > $4000, "sprites go out of vic bank range"
            
            
            
ascii_charset   .binary "ascii-charset"

collogo_charset .binary "collogo-charset"
collogo_screen  .binary "collogo-screen"
collogo_meta    .text binary("collogo-meta")[::-1]
collogo_colors  .fill 2,$04 ;c
                .fill 2,$02 ;o
                .fill 2,$0a ;l
                .fill 2,$07 ;e
                .fill 2,$05 ;c
                .fill 2,$06 ;o
                .fill 2,$04 ;v
                .fill 1,$02 ;i
                .fill 2,$0a ;s
                .fill 1,$07 ;i
                .fill 2,$05 ;o
                .fill 2,$06 ;n
                
copyright_1 .text "PRESENTS UNIVERSAL'S"
copyright_2 .text "SPACE PANIC",$1e,$1f
copyright_3 .text $1d," 1983 COLECO"


skillmenu_1 .text "TO SELECT GAME OPTION,"
skillmenu_2 .text "PRESS BUTTON ON KEYPAD."
skillmenu_m .text "= SKILL  /ONE PLAYER"




c_8301  .binary SRCROM, $301, $0d*8
c_8369  .binary SRCROM, $369, $02*8
c_8379  .binary SRCROM, $379, $02*8
c_8389  .binary SRCROM, $389, $0a*8
c_83d9  .binary SRCROM, $3d9, $02*8
c_83e9  .binary SRCROM, $3e9, $02*8
    .eor $ff ;flip around the brick gfx
c_83f9  .binary SRCROM, $3f9, $1b*8
    .eor $00
c_84d1  .binary SRCROM, $4d1, $08*8
            
            
            ;
            ;
            ; ------- generic game routines
            ;
            ;
            
            
            ;add YA to current player's score, and update lives and display
addscore    pha
            lda g_flags
            and #1
            tax
            pla
            clc
            adc g_scorelo,x
            sta g_scorelo,x
            tya
            adc g_scorehi,x
            sta g_scorehi,x
            
            ;$afb1 - see if we should award an extra life
            ldy g_extralives,x
            cpy #len(extralifetbl)
            bcs _dodisplay
            lda g_scorelo,x
            cmp extralifelo,y
            lda g_scorehi,x
            sbc extralifehi,y
            bcc _dodisplay
            inc g_lives,x
            inc g_extralives,x
            jsr displaylives
_dodisplay  lda g_flags
            and #1
            tay
            iny
            ; ...... fall through ......
displayscore
            lda scorecoltbl,y
            pha
            lda g_hiscorelo,y
            ldx g_hiscorehi,y
            jsr numconv
            pla
            clc
            adc #<line(0)+FIRSTCOL
            sta temp
            lda #0
            adc #>line(0)+FIRSTCOL
            sta temp+1
            ldy #0
-           lda numconvresult,y
            cmp #$d8
            bne +
            lda #0
            sta (temp),y
            iny
            cpy #4
            bcc -
-           lda numconvresult,y
+           sta (temp),y
            iny
            cpy #5
            bcc -
            lda #$d8
            sta (temp),y
            rts
            
extralifetbl = [500,6500]
extralifelo .byte <extralifetbl
extralifehi .byte >extralifetbl
            
scorecoltbl .byte $0d,$05,$18


displayoxybonus
            sty temp+2
            lda g_oxybonus
            ldx g_oxybonus+1
            jsr numconv
            ldy temp+2
            lda oxybonusscreentbllo,y
            sta temp
            lda oxybonusscreentblhi,y
            sta temp+1
            ldy #0
-           lda numconvresult+2,y
            cmp #$d8
            bne +
            lda #0
            sta (temp),y
            iny
            cpy #2
            bcc -
-           lda numconvresult+2,y
+           sta (temp),y
            iny
            cpy #3
            bcc -
            lda #$d8
            sta (temp),y
            rts
            
oxybonusscreentbl = [c64screen($02cb),c64screen($0071),c64screen($00b1)]
oxybonusscreentbllo .byte <oxybonusscreentbl
oxybonusscreentblhi .byte >oxybonusscreentbl
            
            
            
            
numconv     sta temp
            stx temp+1
numconvtemp ldx #4
            lda #$d8
-           sta numconvresult,x
            dex
            bpl -
            
            ldx #0
            ldy #4
-           lda temp
            cmp digittbllo,y
            lda temp+1
            sbc digittblhi,y
            bcc _next
            lda temp
            sbc digittbllo,y
            sta temp
            lda temp+1
            sbc digittblhi,y
            sta temp+1
            inc numconvresult,x
            bne -
_next       inx
            dey
            bpl -
            
            rts
            
digittbl = [1,10,100,1000,10000]
digittbllo  .byte <digittbl
digittblhi  .byte >digittbl

numconvresult   .fill 5



displaylives
            lda g_flags
            and #1
            tax
            ldy g_lives,x
            dey
            sty temp
            
            ldx #6
-           lda #$10
            ldy #$06
            cpx temp
            bcs +
            lda #$19
            ldy #$07
+           sta c64screen($02c3),x
            tya
            sta c64color($02c3),x
            dex
            bpl -
            rts
            
            
            
displayround
            lda g_flags
            and #1
            tax
            lda g_round,x
            
            ldx #0
-           cmp #10
            bcc +
            sbc #10
            inx
            bne -
+           
            adc #$d8
            sta c64screen($02da+1)
            txa
            beq _nohi
            adc #$d8
            sta c64screen($02da)
            rts
            
_nohi       lda #$10
            sta c64screen($02da)
            lda #$06
            sta c64color($02da)
            rts
            
            
            
            
displayplayer
            
            lda p_x
            clc
            adc #$2c
            sei
            sta spritex+7
            lda spritemsb
            and #$7f
            bcc +
            ora #$80
+           sta spritemsb
            lda p_y
            clc
            adc #34
            sta spritey+7
            lda p_frame
            ldy p_dir
            dey
            bne +
            clc
            adc #PL_FLIPADD
+           sta spriteptr+7
            
            lda #$80
            ora spriteen
            sta spriteen
            
            cli
            rts
            
            
            ;enemy ID in X
displayenemy
            lda e_flags,x
            bpl _dead
            lda e_x,x
            clc
            adc #$2c
            sei
            sta spritex,x
            lda spritemsb
            and notbitmasktbl,x
            bcc +
            ora bitmasktbl,x
+           sta spritemsb
            lda e_y,x
            clc
            adc #34
            sta spritey,x
            
            ldy e_type,x
            dey
            sty _add+1
            lda enemycoltbl,y
            sta spritecol,x
            tya
            asl
            asl
_add        adc #0
            adc e_frame,x
            sta spriteptr,x
            
            lda bitmasktbl,x
            ora spriteen
            sta spriteen
            
            cli
            rts
            
_dead       lda notbitmasktbl,x
            and spriteen
            sta spriteen
            rts
            
enemycoltbl .byte 2,2,$e
            
bitmasktbl  .byte $01,$02,$04,$08,$10,$20,$40,$80
notbitmasktbl .byte $fe,$fd,$fb,$f7,$ef,$df,$bf,$7f
            
            
            
            ;$aedb
            ; hole index in Y
displayhole tya
            ldx #6 + (4*3)
            bne +
-           sbc #MAX_HOLES*HOLE_SIZE
            .rept 4
                dex
            .next
+           cmp #MAX_HOLES*HOLE_SIZE
            bcs -
            lda linetbllo,x
            sta temp
            lda linetblhi,x
            sta temp+1
            tya
            tax
            
            ;get x-position
            lda holetable+2,x
            sbc #6-1
            lsr
            lsr
            lsr
            tay
            lda holetable+2,x
            and #$0c
            ora holetable+1,x
            tax
            
            lda _gfx0,x
            sta (temp),y
            iny
            lda _gfx1,x
            sta (temp),y
            lda _gfx2,x
            beq +
            iny
            sta (temp),y
+           rts
            ;$af59
holegfx =  [$20,$21, $00,
            $5f,$60, $00,
            $61,$62, $00,
            $55,$56, $00,
            $20,$21,$20,
            $48,$49,$4a,
            $4b,$4c,$4d,
            $4e,$4f,$50,
            $21,$20, $00,
            $51,$52, $00,
            $53,$54, $00,
            $55,$56, $00,
            $21,$20,$21,
            $57,$58,$59,
            $5a,$5b,$5c,
            $5d,$4f,$5e,
            ]
_gfx0   .byte holegfx[::3]
_gfx1   .byte holegfx[1::3]
_gfx2   .byte holegfx[2::3]
            
            
            
initsong    ldx #size(_priotbl)-1
-           lda soundqueue
            cmp _priotbl,x
            beq ++
            tya
            cmp _priotbl,x
            beq +
            dex
            bpl -
+           sta soundqueue
+           rts
            
_priotbl    .byte [$01,$11,$02,$03,$08,$0A,$0D,$10,$04,$12,$07,$0B,$0C,$0E,$05,$06,$09,$0F][::-1]






copystring  sta _color+1
            ldx stringtblrow-1,y
            lda linetbllo,x
            sta temp
            sta temp+2
            lda linetblhi,x
            sta temp+1
            eor #(>screen) ^ $d8
            sta temp+3
            ldx stringtblindex-1,y
            lda stringtblcol-1,y
            tay
            
_loop       lda stringtbl,x
            cmp #$ff
            beq _ret
            inx
            cmp #$fe
            beq _stepmul
            cmp #$fd
            bne _print
_rle        lda stringtbl+1,x
            sta temp+4
-           lda stringtbl,x
            jsr _write
            dec temp+4
            bne -
            inx
            inx
            gne _loop
            
_print      jsr _write
            jmp _loop
            
_stepmul    lda stringtbl,x
            sta temp+4
            inx
-           jsr _step
            dec temp+4
            bne -
            geq _loop
            
            
_write      sta (temp),y
_color      lda #0
            cmp #$ff
            beq _step
            sta (temp+2),y
_step       iny
            cpy #32
            bcc +
            ldy #0
            lda temp
            adc #40-1
            sta temp
            sta temp+2
            bcc +
            inc temp+1
            inc temp+3
+           
_ret        rts
            
            
linetbllo   .for i = 0, i < 24, i=i+1
                .byte <(line(i)+FIRSTCOL)
            .next
linetblhi   .for i = 0, i < 24, i=i+1
                .byte >(line(i)+FIRSTCOL)
            .next
            
            ;$ad5f
stringtblindex
            .for i = 0, i < $1c, i=i+2
                .byte (srcromdat[$2d5f+i] | (srcromdat[$2d5f+i+1] << 8)) - $ad7b
            .next
stringtblrow
            .for i = 0, i < $1c, i=i+2
                ptr := srcromdat[$2e71+i] | (srcromdat[$2e71+i+1] << 8)
                .byte ptr/$20
            .next
stringtblcol
            .for i = 0, i < $1c, i=i+2
                ptr := srcromdat[$2e71+i] | (srcromdat[$2e71+i+1] << 8)
                .byte ptr&$1f
            .next
stringtbl   .binary SRCROM, $2d7b,$f6
            
            
            
            
            
            
            ;
            ;
            ; ------ math routines
            ;
            ;
            
            
            ;A * X -> XA
mul         sta mathtemp
            dex
            stx _n+1
            lda #$80
            sta mathresult
            asl
-           lsr mathtemp
            bcc +
_n          adc #0
+           ror
            ror mathresult
            bcc -
            sta mathresult+1
            tax
            lda mathresult
            rts
            
            ;XA / Y -> XA, remainder in Y
div         sta mathresult
            stx mathresult+1
            sty _n+1
            lda #0
            sta mathtemp
            ldx #16
-           asl mathresult
            rol mathresult+1
            rol mathtemp
            lda mathtemp
            sec
_n          sbc #0
            bcc +
            sta mathtemp
            inc mathresult
+           dex
            bne -
            lda mathresult
            ldx mathresult+1
            ldy mathtemp
            rts
            
            
            ;$a44f
mulaxdiv100 jsr mul
            ldy #100
            jmp div
            
            ;$a46c
mula100divy sty _n+1
            ldx #100
            jsr mul
_n          ldy #0
            jmp div
            
            
            
            
            ;
            ;
            ; ------- system subroutines
            ;
            ;
            
            
screenon    lda #$17
            bne screenset
screenoff   lda #$07
screenset   sta d011_mir
waitframe   lda framecnt
-           cmp framecnt
            beq -
            rts
            
waitframes  clc
            adc framecnt
-           cmp framecnt
            bne -
            rts
            
            
            
waitgame    lda gamecnt
-           cmp gamecnt
            beq -
            rts
            
waitgames   clc
            adc gamecnt
-           cmp gamecnt
            bne -
            rts
            
            
loadascii   #copyx ascii_charset, char($1d)
            rts
            
clearscreen_0
            lda #0
            beq +
clearscreen lda #' '
+           sta _c+1
            ldx #0
-           
_c          lda #' '
            sta screen+$000,x
            sta screen+$100,x
            sta screen+$200,x
            sta screen+$2e8,x
            lda #$01
            sta $d800,x
            sta $d900,x
            sta $da00,x
            sta $db00,x
            inx
            bne -
            rts
            
            
cleargamescreen
            ldx #0
-           lda #0
            sta line(3),x
            sta line(3)+$100,x
            lda #1
            sta colline(3),x
            sta colline(3)+$100,x
            inx
            bne -
            ldx #$f8
-           lda #0
            sta line(3)+$200-1,x
            lda #1
            sta colline(3)+$200-1,x
            dex
            bne -
            rts
            
            
rand    ldy r_seed
        dec r_rept
        bne ++
        dey
        bpl +
        ldy #len(_seedtbl)-1
+       sty r_seed
+       lda r_val
        beq +
        asl
        beq ++
        bcc ++
+       eor _seedtbl,y
+       sta r_val
        rts
_seedtbl .byte $f5,$e7,$cf,$c3,$a9,$8d,$87,$71,$69,$65,$63,$5f,$4d,$2f,$2b,$1d
            
            
            
            
            
ciatbl = [(1022727.0/60.0)-1,(985248.0/60.0)-1]
ciatbllo    .byte <ciatbl
ciatblhi    .byte >ciatbl
            
            
            
irq         pha
            lda $dc0d
            bpl +
            jmp _cia
+           inc $d019
            lda bordercol
            sta $d020
            lda bgcol
            sta $d021
            lda d011_mir
            sta $d011
            
            lda spriteen
            sta $d015
            lda spritemsb
            sta $d010
            .for i = 0, i < 8, i=i+1
                lda spritex+i
                sta $d000+(i*2)
                lda spritey+i
                sta $d001+(i*2)
                lda spritecol+i
                sta $d027+i
                lda spriteptr+i
                sta screen+$3f8+i
            .next
            
            inc framecnt
            pla
            rti
            
_cia        cli
            txa
            pha
            tya
            pha
            
            
            ; -- joystick
            lda #$ff
            sta $dc00
            lda $dc01
            and #$1f
            eor #$1f
            sta joy
            lda $dc00
            and #$1f
            eor #$1f
            sta joy+1
            
            ldx #$07
            lda #$7f
-           sta $dc00
            tay
            lda $dc01
            ora joy
            eor #$ff
            sta key,x
            tya
            sec
            ror
            dex
            bpl -
            
            
            
            ; -- soundmute
            ldx #7
_soundmuteloop
            lsr soundmute
            bcc _nextsoundmute
            
            ldy soundmutetbl,x
            lda songtbl,y
            and #3
            sta m_zp
            lda songtbl,y
            lsr
            lsr
            tay
            stx m_zp+1
-           ldx song_tbl_chn,y
            lda m_flags,x
            bpl +
            tya
            cmp m_song,x
            bne +
            lda #M_FLAG_REST
            sta m_flags,x
+           iny
            dec m_zp
            bpl -
            ldx m_zp+1
            
_nextsoundmute
            dex
            bpl _soundmuteloop
            
            
            ; -- sound queue
            ldx soundqueue
            beq _nosoundinit
            
            ;check prio
            ldy #size(songprio1)+size(songprio2)-1
            lda songpriomode-1,x
            bmi _dosoundq
            bne +
            ldy #size(songprio2)-1
+           
-           ldx songprio1,y
            stx _priosongid+1
            lda song_tbl_chn,x
            tax
            lda m_flags,x
            bpl _nextprio
_priosongid lda #0
            cmp m_song,x
            beq _aftersoundinit
_nextprio   dey
            bpl -
            
_dosoundq2  ldx soundqueue
_dosoundq   cpx #size(songtbl)+1
            bcs +
            lda songtbl-1,x
            and #$03
            sta m_zp
            lda songtbl-1,x
            lsr
            lsr
            tay
-           jsr safe_m_init
            iny
            dec m_zp
            bpl -
            bmi _aftersoundinit
            
+           ldy #$1d-1
            jsr safe_m_init
            ldy #$23-1
            jsr safe_m_init
            
_aftersoundinit
            lda #$00
            sta soundqueue
_nosoundinit
            lda pauseflag
            beq +
            lda #8
            sta $d404
            sta $d404+7
            sta $d404+$e
            gne _pauseskip
+           jsr m_play
            
            
            ;decrement timers
dtimer      .macro
            lda \1
            beq +
            dec \1
+           .endm
            #dtimer g_oxybonustimer
            #dtimer g_oxybartimer
            #dtimer p_timer
            .for i = 0, i < ENEMIES, i=i+1
                #dtimer e_timer+i
            .next
            
_pauseskip  
            
            
            inc gamecnt
            pla
            tay
            pla
            tax
            pla
nmi         rti


safe_m_init ldx song_tbl_chn,y
            lda m_flags,x
            bpl +
            tya
            cmp m_song,x
            beq ++
+           jmp m_init
+           rts
            
            ;$a8a7
songprio1   .byte [$01,$04,$07,$12,$1a,$20]-1
songprio2   .byte [$0b,$1f,$10,$17,$18,$1d]-1
            ;$a83b
songlist = [$00, $01,$03,
            $00, $04,$03,
            $00, $07,$03, ;actually 4 but noise channel is useless
            $01, $0b,$01,
            $02, $0c,$02,
            $02, $0e,$02,
            $01, $10,$02,
            $00, $12,$02,
            $02, $14,$02,
            $00, $16,$01,
            $01, $17,$01,
            $01, $18,$02,
            $00, $1a,$03,
            $01, $1d,$01,
            $02, $1e,$01,
            $01, $1f,$01,
            $00, $20,$03,
            $01]
songpriomode
            .char songlist[::3]-1
songtbl     .for i = 0, i < len(songlist)/3, i=i+1
                .byte (songlist[i*3 + 2]-1) | ((songlist[i*3 + 1]-1) << 2)
            .next
            
soundmutetbl .byte [$00,$00,$00,$1E,$1C,$12,$16,$0C]/2
            
            
            
            
            .align $100
            .include "music/player.asm"
            .include "music/spacepan.asm"
            
            