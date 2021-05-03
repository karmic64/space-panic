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


bioschar .function ch
.endf ascii_charset + (ch-$1d)*8



temp = $20



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
            sta $0318
            lda #>nmi
            sta $0319
            lda #$36
            sta $01
            
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
            
            lda #$ff
            sta $02
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
            sta $0314
            lda #>irq
            sta $0315
            lda $dc0d
            lda #$81
            sta $dc0d
            
            
            
            ; -------------------- title screen
title       lda #0
            sta $d020
            sta $d021
            sta $d015
            
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
            
            
            
            #copyx copyright_2, line(16)+FIRSTCOL+$07
            #copyx copyright_3, line(21)+FIRSTCOL+$0a
            
            lda #$1b
            sta $d011
            
            ldx #7
-           lda #60
            clc
            adc $08
-           cmp $08
            bne -
            dex
            bne --
            
            
page = $10
digit = $11
song = $12
            lda #$0b
            sta $d011
            jsr loadascii
            ldx #0
            stx page
-           lda #7
            sta $d800,x
            sta $d900,x
            sta $da00,x
            sta $db00,x
            lda #' '
            sta screen+0,x
            sta screen+$100,x
            sta screen+$200,x
            sta screen+$300,x
            inx
            bne -
            lda #$1b
            sta $d011
stop        lda #0
            sta digit
            lda #$7f
            sta $02
            lda #'-'
            sta song
            sta song+1
            
refreshpage lda #<page1
            sta temp
            lda #FIRSTCOL
            sta temp+2
            lda #>page1
            ldx page
            beq +
            lda #>page2
+           sta temp+1
            lda #>screen
            sta temp+3
            
            ldx #24
-           ldy #31
-           lda (temp),y
            sta (temp+2),y
            dey
            bpl -
            lda temp
            clc
            adc #32
            sta temp
            bcc +
            inc temp+1
+           lda temp+2
            clc
            adc #40
            sta temp+2
            bcc +
            inc temp+3
+           dex
            bne --
            lda song
            sta screen+FIRSTCOL+$18
            lda song+1
            sta screen+FIRSTCOL+$19
            
            
loop        jsr $ffe4
            cmp #'*'
            bne +
            lda page
            eor #1
            sta page
            jmp refreshpage
+           cmp #'-'
            beq stop
            cmp #'0'
            bcc loop
            cmp #'9'+1
            bcs loop
            ldx digit
            sta song,x
            sta screen+FIRSTCOL+$18,x
            inx
            stx digit
            cpx #2
            bcs +
            lda #'-'
            sta song+1
            sta screen+FIRSTCOL+$18+1
            gne loop
            
+           lda song
            and #$0f
            tax
            beq +
            lda #0
-           clc
            adc #10
            dex
            bne -
+           sta temp
            lda song+1
            and #$0f
            clc
            adc temp
            beq +
            cmp #35
            bcs +
            tax
            dex
            stx $02
            
            
+           lda #0
            sta digit
            
            geq loop
            
            
            
            
            ; system subroutines
loadascii   #copyx ascii_charset, char($1d)
            rts
            
clearscreen ldx #0
-           lda #' '
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
            
ciatbl = [(1022727.0/60.0)-1,(985248.0/60.0)-1]
ciatbllo    .byte <ciatbl
ciatblhi    .byte >ciatbl


irq         
            ldx $02
            bmi _skip
            jsr m_reset
            ldx $02
            lda #$ff
            sta $02
            cpx #size(songindextbl)
            bcs _skip
            ldy #0
            cpx #($22-2)/2
            bcc +
            iny
            cpx #($42-2)/2
            bcc +
            iny
+           lda songaddtbl,y
            sta $04
            
            ldy songindextbl,x
            lda songtbl,y
-           sty $03
            clc
            adc $04
            tay
            jsr m_init
            ldy $03
            iny
            lda songtbl,y
            bpl -
            cmp #$ff
            beq _skip
            and #$7f
            clc
            adc $04
            sta m_song,x
            iny
            lda songtbl,y
            gpl -
            
_skip       jsr m_play
            
            
            inc $08
            jmp $ea7b
            
nmi         rti
            
            
            
            
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
                
copyright_2 .text "ADAM'S MUSICBOX DEMO"
copyright_3 .text $1d," FOR  COLECO"



page1 .text "    GAME  SONG/SOUND NO --  (1)   -----------------------------                                   SPACE PAN. Panic songs.....01   LAS VEGAS  Vegas songs.....        ....banjo simulation....02   SPACE FURY Start song......03   CAT-N-HAT  Game song.......04   OMEGA RACE Start song......05   OMEGA RACE Elim. songs.....06   OMEGA RACE Pause music.....07   OMEGA RACE Time out/end....        ...four-part harmony....08   D.KONG,JR. Intro/bckrnd2...09   D.KONG,JR. Lev.ov.songs....10   D.KONG,JR. Helicopter......11   SLITHER    Pause music.....12   XTERMINATOR Songs..........13   MR.DO!     Start song......14   MR.DO!     Ball/apple fall.15   MR.DO!     Game songs......16   SWORD/SORC Gun and bolt....17                                    ( - = Off   * = turn page )  "

page2 .text "    GAME  SONG/SOUND NO --  (2)   -----------------------------                                   SWORD/SORC Snake/bubbles...18   SUPER KONG Intro/screen1...19   SUPER KONG Game sounds.....20   SUPER KONG Vanity song.....21   VICTORY    Start/Lev.over..22   VICTORY    End song........23   PEPPER II  Game sounds.....24   SUP.BK.ROG Game songs......25   SUP.BK.ROG Pause music.....26   ROCKY      Game songs......27   ROCKY      Pause music.....28   JUNGLE KING Song...........29   TIME PILOT Pause music.....30   SUBROC     Pause music.....31   FRONT LINE Songs...........32   FRONT LINE Pause music.....33   SUP.ZAXXON Pause music.....        ....harmonica effect....34                                                                    ( - = Off   * = turn page )  "


T0 = $00
T1 = $38
T2 = $75

songaddtbl  .byte T0,T1,T2

songindextbl .block
            .byte s455,s446,s437,s469,s478,s492,s4a1,s4b0
            .byte s4c4,s4d9,s4e8,s4f2,s506,s576,s595,s59f
            .byte s5ae,s5c2,s5d2,s5e6,s40a,s5f5,s623,s632
            .byte s646,s65a,s3ce,s543,s3f6,s419,s428,s3e2
            .byte s669,s69c
            .bend

songtbl     .logical 0
;note: a code of $8x means "change the repeat pointer of the prv channel
;to song $xx-$80
s3ce .byte [$22,$23,$24,$25 ,$100]-1
s3e2 .byte [$3a,$3b,$3c,$3d ,$100]-1
s3f6 .byte [$2d,$2e,$2f,$30 ,$100]-1
s40a .byte [$37,$38,$39 ,$100]-1
s419 .byte [$31,$32,$33 ,$100]-1
s428 .byte [$34,$35,$36 ,$100]-1
s437 .byte [$08,$09,$0a ,$100]-1
s446 .byte [$05,$06,$07 ,$100]-1
s455 .byte [$01,$02,$03,$04 ,$100]-1
s469 .byte [$0b,$0c,$38 ,$100]-1
s478 .byte [$0d,$8e,$0f,$10 ,$100]-1
s492 .byte [$11,$12,$13 ,$100]-1
s4a1 .byte [$14,$15,$16 ,$100]-1
s4b0 .byte [$17,$18,$19,$1a ,$100]-1
s4c4 .byte [$1b,$9c,$1d ,$100]-1
s4d9 .byte [$1e,$1f,$20 ,$100]-1
s4e8 .byte [$21,$22 ,$100]-1
s4f2 .byte [$23,$24,$25,$37 ,$100]-1
s506 .byte [$26,$a7,$28,$a9,$2a,$ab,$2c,$ad ,$100]-1
s543 .byte [$26,$a7,$28,$a9,$2a,$ab,$2c ,$100]-1
s576 .byte [$2e,$af,$30,$b1 ,$100]-1
s595 .byte [$32,$33 ,$100]-1
s59f .byte [$34,$35,$36 ,$100]-1
s5ae .byte [$01,$02,$03,$04 ,$100]-1
s5c2 .byte [$05,$86 ,$100]-1
s5d2 .byte [$07,$08,$09,$0a ,$100]-1
s5e6 .byte [$0b,$0c,$0d ,$100]-1
s5f5 .byte [$0e,$8f,$10,$91,$12,$93 ,$100]-1
s623 .byte [$14,$15,$16 ,$100]-1
s632 .byte [$17,$18,$19,$1a ,$100]-1
s646 .byte [$1b,$1c,$1d,$1e ,$100]-1
s65a .byte [$1f,$20,$21 ,$100]-1
s669 .byte [$01,$85,$02,$86,$03,$87,$04 ,$100]-1
s69c .byte [$08,$89,$0a,$0b ,$100]-1
            .here
            
            
            .align $100
            .include "music/player.asm"
            .include "music/musicbox.asm"
            