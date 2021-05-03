            
M_C_NOISE = 0
M_C_TONE0 = 1
M_C_TONE1 = 2
M_C_TONE2 = 3
            
            
M_FLAG_ENABLED = $80
M_FLAG_VOLUME = $10
M_FLAG_FREQ = $08
M_FLAG_REST = $01

m_zp = $fd
            
            
freqtbl     .binary "ntscfreq"


m_reset     ldx #$17
            lda #$00
-           sta $d400,x
            dex
            bpl -
            
            ldx #CHANNELS-1
-           sta m_flags,x
            dex
            bpl -
            
            sta m_prvvol+0
            sta m_prvvol+7
            sta m_prvvol+$e
            
            lda #$0f
            sta $d418
            
            rts
            
            
            
m_init      tya
            ldx song_tbl_chn,y
            sta m_song,x
            lda song_tbl_lo,y
            sta m_ptrlo,x
            lda song_tbl_hi,y
            sta m_ptrhi,x
            lda #M_FLAG_ENABLED | M_FLAG_REST
            sta m_flags,x
            lda #$01
            sta m_timer,x
            rts
            
            
            
m_play      lda #$ff
            sta m_chns
            sta m_chns+1
            sta m_chns+2
            sta m_chns+3
            sta m_chnt2freq
            
            ldx #CHANNELS
_chnexec_return
            dex
            bmi +
            lda m_flags,x
            bpl _chnexec_return
            jmp m_chnexec
+           
            
            ; ---- output to sid
            
            ;try SN noise -> SID 3
            ldx m_chns+M_C_NOISE
            bmi _nonoise
            lda m_freqlo,x ;test frequency mode
            and #$03
            beq +
            tax
            lda noisetbl-1,x
            sta m_zp
            lda #(>freqtbl)+8
            bne ++
+           ldx m_chnt2freq
            lda m_freqlo,x
            asl
            sta m_zp
            lda m_freqhi,x
            and #$03
            rol
            adc #(>freqtbl)+8
+           ldx m_chns+M_C_NOISE
            sta m_zp+1
            
            lda m_freqlo,x ;test periodic/noise
            and #$04
            cmp #$04 ;to put it in carry
            ldy #0
            lda (m_zp),y
            sta $d400 + $0e
            iny
            lda (m_zp),y
            sta $d401 + $0e
            ldy m_volume,x
            bcs + ;carry set if white, clear if periodic
            lda #$01
            sta $d403 + $0e
            ldx #$41
            bne ++
+           ldx #$81
+           
            cpy m_prvvol+$0e
            beq +
            sty m_prvvol+$0e
            bcc +
            lda #$00
            sta $d406 + $0e
            lda #$02
            sta $d404 + $0e
+           sty $d406 + $0e
            stx $d404 + $0e
            
            ;now try the tone channels, going from 0->2
            ldy #$07
            bne +
_nonoise    ldy #$0e
+           
            ldx #1
_toneloop   lda m_chns,x
            bmi _skiptone
            stx m_zp+2
            tax
            
            lda #$08
            sta $d403,y
            
            lda m_volume,x
            pha
            
            lda m_freqlo,x
            asl
            sta m_zp
            lda m_freqhi,x
            and #$03
            rol
            adc #>freqtbl
            sta m_zp+1
            ldx #0
            lda (m_zp,x)
            sta $d400,y
            inc m_zp
            lda (m_zp,x)
            sta $d401,y
            
            pla
            cmp m_prvvol,y
            beq _lowervol
            sta m_prvvol,y
            bcc _lowervol
            tax
            lda #$00
            sta $d406,y
            lda #$02
            sta $d404,y
            txa
_lowervol   sta $d406,y
            lda #$41
            sta $d404,y
            
            tya
            beq _outofchns
            sec
            sbc #7
            tay

            ldx m_zp+2
_skiptone   inx
            cpx #M_C_TONE2+1
            bcc _toneloop
            
            ;kill off any unused channels
            ;sec
-           lda #$08
            sta $d404,y
            tya
            sbc #7
            tay
            bpl -
            
_outofchns  rts
            
            
            
            
            ; ----- channel execution routine
m_chnexec   ;lda m_flags,x
            and #M_FLAG_FREQ
            beq _nofreq
            dec m_freqtimer,x
            bne _skipfreq
            dec m_timer,x
            beq _readdata
            lda m_freqlength,x
            sta m_freqtimer,x
            ldy #0
            lda m_freqsize,x
            bpl +
            dey
+           clc
            adc m_freqlo,x
            sta m_freqlo,x
            tya
            adc m_freqhi,x
            sta m_freqhi,x
            jmp _skipfreq
            
_nofreq     dec m_timer,x
            beq _readdata
            
_skipfreq   
            lda m_flags,x
            and #M_FLAG_VOLUME
            beq _novol
            dec m_voltimer,x
            bne _novol
            lda m_vollength,x
            sta m_voltimer,x
            dec m_volsteps,x
            bne +
            lda m_flags,x
            and #M_FLAG_VOLUME ^ $ff
            sta m_flags,x
            gmi _novol
+           lda m_volume,x
            sec
            sbc m_volsize,x
            sta m_volume,x
_novol      
_jfinal     jmp _final
            
            
            
_datacmd    cmp #$a0
            bcc _initrest
            beq _stop
            ldy m_song,x
            lda song_tbl_lo,y
            sta m_zp
            lda song_tbl_hi,y
            gne _afterrep
            
_stop       lda #M_FLAG_REST
            sta m_flags,x
            bne _jfinal
            
_initrest   and #$1f
            sta m_timer,x
            lda #M_FLAG_ENABLED | M_FLAG_REST
            sta m_flags,x
            gmi _updateptr
            
            
            ; ---- read song data
_readdata   lda m_ptrlo,x
            sta m_zp
            lda m_ptrhi,x
_afterrep   sta m_zp+1
            ldy #$00
            lda (m_zp),y
            bmi _datacmd
            
            sta m_zp+2
            and #%00011000
            ora #M_FLAG_ENABLED
            sta m_flags,x
            lda m_zp+2
            asl
            asl
            rol
            rol
            and #$03
            sta m_channel,x
            cmp #M_C_TONE0 ;carry clear if noise
            lda m_zp+2
            and #%00000111
            bcc +
            sta m_zp+2
            iny
            lda (m_zp),y
            asl
            rol m_freqhi,x
            asl
            rol m_freqhi,x
            asl
            rol m_freqhi,x
            ora m_zp+2
+           sta m_freqlo,x
            iny
            lda (m_zp),y
            and #$f0
            sta m_volume,x
            iny
            lda (m_zp),y
            sta m_timer,x
            
            lda m_flags,x
            and #M_FLAG_FREQ
            beq +
            iny
            lda (m_zp),y
            and #$0f
            sta m_freqtimer,x
            lda (m_zp),y
            lsr
            lsr
            lsr
            lsr
            sta m_freqlength,x
            iny
            lda (m_zp),y
            sta m_freqsize,x
+           
            lda m_flags,x
            and #M_FLAG_VOLUME
            beq +
            iny
            lda (m_zp),y
            and #$0f
            sta m_volsteps,x
            ora (m_zp),y
            and #$f0
            sta m_volsize,x
            iny
            lda (m_zp),y
            and #$0f
            sta m_voltimer,x
            lda (m_zp),y
            lsr
            lsr
            lsr
            lsr
            sta m_vollength,x
+           
            
_updateptr  tya
            sec
            adc m_zp
            sta m_ptrlo,x
            lda #0
            adc m_zp+1
            sta m_ptrhi,x
            
_final      ldy m_channel,x
            cpy #M_C_TONE2
            bne +
            lda m_chnt2freq
            bpl +
            stx m_chnt2freq
+           lda m_flags,x
            lsr
            bcs +
            lda m_volume,x
            beq +
            lda m_chns,y
            bpl +
            txa
            sta m_chns,y
+           
            jmp m_play._chnexec_return
            
            
noisetbl    .byte [$10,$20,$40]*2
            
            
            
            
m_flags     .fill CHANNELS
m_song      .fill CHANNELS
m_channel   .fill CHANNELS

m_timer     .fill CHANNELS
m_ptrlo     .fill CHANNELS
m_ptrhi     .fill CHANNELS

m_freqlo    .fill CHANNELS
m_freqhi    .fill CHANNELS
m_freqsize  .fill CHANNELS
m_freqtimer .fill CHANNELS
m_freqlength .fill CHANNELS

m_volume    .fill CHANNELS
m_volsize   .fill CHANNELS
m_volsteps  .fill CHANNELS
m_voltimer  .fill CHANNELS
m_vollength .fill CHANNELS



m_prvvol    .byte 0

m_chns      .fill 4,$ff

;this is the channel which has control over noise tone2 freq
m_chnt2freq .byte $ff
            * = m_prvvol+$0f
            
            
            