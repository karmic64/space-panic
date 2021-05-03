#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>


#define get16(p) ((uint16_t)((*(uint8_t*)(p)) | ((*(((uint8_t*)(p))+1)) << 8)))

/*
"New" music data format:
$a1 - repeat
$a0 - stop
$80-$9f - rest (lower 5 bits is length)
$00-$7f - note
    Note control byte:
        bits 5-6: channel (0-2: tones, 3: noise)
        bit 4: volume sweep flag
        bit 3: freq sweep flag
        bits 0-2: lower 3 bits of frequency
    (Tones only) upper 7 bits of frequency
    upper 4 bits - initial volume
    (if no freq sweep) note length
    if volume sweep:
        upper 4 bits - step size, lower 4 bits - number of steps
        upper 4 bits - step length, lower 4 bits - first length
    if freq sweep:
        number of steps
        upper 4 bits - step length, lower 4 bits - first length
        step size
*/


typedef struct
{
    uint16_t data;
    uint16_t ram;
} song_t;


int main(int argc, char *argv[])
{
    if (argc < 4)
    {
        printf("Usage: %s romname outname songtbladdr...\n", argv[0]);
        return EXIT_FAILURE;
    }
    
    uint16_t *songtblbasetbl = malloc((argc-3)*sizeof(uint16_t));
    int songtables = argc - 3;
    for (int i = 0; i < songtables; i++)
    {
        songtblbasetbl[i] = strtol(argv[3+i], NULL, 16);
        if (songtblbasetbl[i] < 0x8000)
        {
            printf("Invalid song table base %s\n", argv[i+3]);
            return EXIT_FAILURE;
        }
    }
    
    FILE *f = fopen(argv[1], "rb");
    if (!f)
    {
        printf("Couldn't open %s: %s\n", argv[1], strerror(errno));
        return EXIT_FAILURE;
    }
    fseek(f, 0, SEEK_END);
    size_t fsize = ftell(f);
    rewind(f);
    uint8_t *buf = malloc(fsize > 0x8000 ? 0x8000 : fsize);
    fread(buf, 1, fsize > 0x8000 ? 0x8000 : fsize, f);
    fclose(f);
    
    if (get16(buf) != 0x55aa && get16(buf) != 0xaa55)
    {
        puts("File is not a Colecovision ROM");
        return EXIT_FAILURE;
    }
    
    song_t *songtbl = malloc(songtables*0x80*sizeof(song_t));
    unsigned int songs = 0;
    uint16_t minchn = -1;
    uint16_t maxchn = 0;
    unsigned int firstsong = 0;
    for (int tbl = 0; tbl < songtables; tbl++)
    {
        unsigned int thissongs = 0;
        uint8_t *p = buf + songtblbasetbl[tbl]-0x8000;
        while (get16(p) >= 0x8000 && get16(p+2) >= 0x7000 && get16(p+2) < 0x7400)
        {
            if (get16(p+2) < minchn) minchn = get16(p+2);
            if (get16(p+2) > maxchn) maxchn = get16(p+2);
            songtbl[songs].data = get16(p);
            songtbl[songs].ram = get16(p+2);
            songs++;
            thissongs++;
            p += 4;
        }
        printf("Song table %i has %u songs", tbl, thissongs);
        if (thissongs) printf(", ids $%02X-$%02X", firstsong, firstsong+thissongs-1);
        fputc('\n', stdout);
        firstsong += thissongs;
    }
    unsigned int channels = (maxchn-minchn)/10 + 1;
    free(songtblbasetbl);
    
    if (!songs)
    {
        puts("No valid song entries in tables");
        return EXIT_FAILURE;
    }
    
    f = fopen(argv[2], "w");
    fprintf(f, "CHANNELS = %u\n\nsong_tbl_chn: .byte ", channels);
    for (unsigned int i = 0; i < songs; i++)
    {
        fprintf(f, "%u%s", (songtbl[i].ram-minchn) / 10, i==songs-1 ? "" : ",");
    }
    fprintf(f, "\nsong_tbl_lo: .byte ");
    for (unsigned int i = 0; i < songs; i++)
    {
        fprintf(f, "<song%u%s", i, i==songs-1 ? "" : ",");
    }
    fprintf(f, "\nsong_tbl_hi: .byte ");
    for (unsigned int i = 0; i < songs; i++)
    {
        fprintf(f, ">song%u%s", i, i==songs-1 ? "" : ",");
    }
    fputc('\n', f);
    
    for (unsigned int i = 0; i < songs; i++)
    {
        fprintf(f, "\nsong%u: .byte ", i);
        
        uint8_t *p = songtbl[i].data - 0x8000 + buf;
        
        while (1)
        {
            uint8_t ctrl = *(p++);
            if ((ctrl & 0b110111) == 0b010000)
            { /* repeat/end */
                if (ctrl & 0b1000)
                    fprintf(f, "$a1");
                else
                    fprintf(f, "$a0");
                break;
            }
            else if (ctrl & 0x20)
            { /* rest */
                fprintf(f, "$%02x,", (ctrl & 0x1f) | 0x80);
            }
            else if (!(ctrl & 0b111100))
            { /* regular note */
                uint8_t chn = ctrl >> 6;
                uint8_t volflag = ctrl & 2;
                uint8_t freqflag = ctrl & 1;
                
                if (!chn && freqflag)
                {
                    printf("Noise note with frequency sweep encountered at $%04X\n", (unsigned int)((p-1)-buf+0x8000));
                    return EXIT_FAILURE;
                }
                
                uint16_t freq = (chn || !volflag) ? *(p++) : 0;
                freq |= ((*p) & 7) << 8;
                
                uint8_t noisefreq = freq >> 8;
                noisefreq = ((noisefreq + 1) & 3) | (noisefreq & 4);
                
                uint8_t vol = ((*(p++)) >> 4) ^ 0xf;
                
                uint8_t len = freqflag ? 0 : *(p++);
                
                fprintf(f, "$%02x,", (chn << 5) | (volflag << 3) | (freqflag << 3) | (chn ? (freq & 7) : (noisefreq)));
                if (chn) fprintf(f, "$%02x,", freq >> 3);
                fprintf(f, "$%02x,", vol << 4);
                if (!freqflag) fprintf(f, "$%02x,", len);
                
                if (freqflag)
                {
                    fprintf(f, "$%02x,$%02x,$%02x,", *(p),*(p+1),*(p+2));
                    p += 3;
                }
                if (volflag)
                {
                    fprintf(f, "$%02x,$%02x,", *(p),*(p+1));
                    p += 2;
                }
            }
            else
            {
                printf("Bad music command byte $%02X encountered at $%04X\n", ctrl, (unsigned int)((p-1)-buf+0x8000));
                return EXIT_FAILURE;
            }
            fputc(' ', f);
        }
    }
    
    
    
    
    fclose(f);
    
    
    return EXIT_SUCCESS;
}


