#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>

int main()
{
    FILE *ntscf = fopen("ntscfreq", "wb");
    FILE *palf = fopen("palfreq", "wb");
    
    /* tone part */
    for (uint16_t base = 0; base < 0x400; base++)
    {
        double freq = 3579000.0 / (32.0 * base);
        uint32_t ntsc = (16777216.0 / 1022727.0 * freq);
        uint32_t pal = (16777216.0 / 985248.0 * freq);
        
        if (ntsc > 0xffff) ntsc = 0xffff;
        if (pal > 0xffff) pal = 0xffff;
        
        fputc(ntsc & 0xff, ntscf);
        fputc((ntsc >> 8) & 0xff, ntscf);
        
        fputc(pal & 0xff, palf);
        fputc((pal >> 8) & 0xff, palf);
    }
    
    /* noise part */
    for (uint16_t base = 0; base < 0x400; base++)
    {
        double freq = 3579000.0 / (32.0 * base);
        uint32_t ntsc = (16777216.0 / 1022727.0 * freq) / 16.0;
        uint32_t pal = (16777216.0 / 985248.0 * freq) / 16.0;
        
        if (ntsc > 0xffff) ntsc = 0xffff;
        if (pal > 0xffff) pal = 0xffff;
        
        fputc(ntsc & 0xff, ntscf);
        fputc((ntsc >> 8) & 0xff, ntscf);
        
        fputc(pal & 0xff, palf);
        fputc((pal >> 8) & 0xff, palf);
    }
    
    fclose(ntscf);
    fclose(palf);
}