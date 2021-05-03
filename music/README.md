# ColecoPlay sound driver

This is a C64 music routine and converter for standard Colecovision-format sound.

## How to convert song data

Search through the Coleco ROM for calls to SOUND_INIT ($1FEE), and take note of any address passed in HL. Once you have the addresses, run the converter like so:

`convert srcrom outname addresses...`

...where `addresses...` is a list of all the values that you logged. Use `0x` as the hexadecimal prefix.

## How to use the routine

In your source code, include the player and data like so:

```
.align $100  ;frequency table must be aligned to page boundary!
.include "music/player.asm"
.include CONVERTED_OUTNAME
```

By default, the NTSC frequency table is the one loaded in. If you detect a PAL machine, you must copy the PAL table over the old table (use the label `freqtbl`).

At the start of your program, ensure you `jsr m_reset` before the play routine can ever get a chance to execute. You can also call that routine at any point you want to kill the sound.

To initialize a song:

```
ldy #songnum
jsr m_init
```

This is equivalent to the following in Coleco code:

```
ld b,songnum+1
call PLAY_IT  ;($1ff1)
```

Although, the Coleco routine will not re-initialize a song that is already playing. If you want this behavior, use the following routine instead:

```
safe_m_init ldx song_tbl_chn,y
            lda m_flags,x
            bpl +
            tya
            cmp m_song,x
            beq ++
+           jmp m_init
+           rts
```

To actually drive the music, `jsr m_play` at a 60Hz rate.