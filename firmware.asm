; 
; Project name: sleep-mode-example
; Description: Example of using sleep mode in power-down mode on avr microcontroller
; Source code: https://github.com/sergeyyarkov/attiny2313a_sleep-mode-example
; Device: ATtiny2313A
; Package: 20-pin-PDIP_SOIC
; Assembler: AVR macro assembler 2.2.7
; Clock frequency: 8MHz with CKDIV8
; Fuses: lfuse: 0x64, hfuse: 0x9F, efuse: 0xFF, lock:0xFF
;
; Written by Sergey Yarkov 29.05.2022
    
.list
    
.def temp_r      = r16
.def wdt_counter = r10
    
.dseg                               ; Data segment
.org SRAM_START

.cseg                               ; Code segment
.org 0x00
 
rjmp    RESET_vect                  ; External Pin, Power-on Reset, Brown-out Reset, and Watchdog Reset
reti                                ; External Interrupt Request 0
reti                                ; External Interrupt Request 1
reti                                ; Timer/Counter1 Capture Event
reti                                ; Timer/Counter1 Compare Match A
reti                                ; Timer/Counter1 Overflow
reti                                ; Timer/Counter0 Overflow
reti                                ; USART0, Rx Complete
reti                                ; USART0 Data Register Empty
reti                                ; USART0, Tx Complete
reti                                ; Analog Comparator
reti                                ; Change Interrupt Request 0
reti                                ; Timer/Counter1 Compare Match B
reti                                ; Timer/Counter0 Compare Match A
reti                                ; Timer/Counter0 Compare Match B
reti                                ; USI Start Condition
reti                                ; USI Overflow
reti                                ; EEPROM Ready
rjmp    WDT_vect                    ; Watchdog Timer Overflow
reti                                ; Change Interrupt Request 1
reti                                ; Change Interrupt Request 2
    
WDT_vect:
    inc     wdt_counter
    rcall   toggle_led
    in      temp_r, WDTCSR
    ori     temp_r, (1<<WDIE)
    out     WDTCSR, temp_r
reti
        
RESET_vect:
    ldi     temp_r, low(RAMEND)
    ; setup stack pointer
    out     SPL, temp_r
       
    rcall   init_ports
    rcall   init_sm
    rcall   init_wdt
    
    ; go to main loop
    rjmp    loop

; config sleep mode to power-down
init_sm:
    in      temp_r, MCUCR
    ori     temp_r, (1<<SM0)
    out     MCUCR, temp_r
    ret

; config watchdog to interrupt mode
init_wdt:
    cli
    wdr
    
    in      temp_r, WDTCSR
    ori     temp_r, (1<<WDCE) | (1<<WDE)
    ; allow changing the watchdog bits and enable watchdog
    out     WDTCSR, temp_r

    ldi     temp_r, (1<<WDE) | (1<<WDIE) | (1<<WDP2) | (1<<WDP1)
    ; config watchdog to interrupt mode and setup prescaler 512K cycles (4 sec)
    out     WDTCSR, temp_r
    sei
    ret

init_ports:
    ldi     temp_r, 0xff
    out     DDRA, temp_r
    clr     temp_r
    out     PORTA, temp_r
    ret

; main program loop
loop:
    rcall   wdt_sleep_check
    rjmp    loop
    
toggle_led:
    sbi     PORTA, PA0
    rcall   delay_100ms
    cbi     PORTA, PA0
    rcall   delay_100ms
    ret

wdt_sleep_check:
    ; how many seconds should elapse before entering sleep mode, 
    ; subject to a prescaler of 128K cycles (1 sec)
    .equ    delay_seconds = 10
    push    r16
    ldi     r16, delay_seconds
    cp      wdt_counter, r16
    brsh    _mcu_sleep
    rjmp    _sleep_exit
    _mcu_sleep:
        clr     wdt_counter
        rcall   WDT_off
        in      temp_r, MCUCR
        ori     temp_r, (1<<SE)
        out     MCUCR, temp_r
        pop     r16
        cli
        sleep
    _sleep_exit:
        pop     r16
    ret
    
WDT_off:
    wdr
    ; clear WDRF in MCUSR
    ldi     temp_r, (0<<WDRF)
    out     MCUSR, r16
    ; write logical one to WDCE and WDE
    ; keep old prescaler setting to prevent unintentional Watchdog Reset
    in      temp_r, WDTCSR
    ori     temp_r, (1<<WDCE) | (1<<WDE)
    out     WDTCSR, temp_r
    ; turn off WDT
    ldi     temp_r, (0<<WDE)
    out     WDTCSR, temp_r
    ret
    
delay_100ms:                        ; For 1MHz frequency
    
    ldi     r18, 130    
    ldi     r19, 220   
_loop_d_100ms: 
    dec     r19          
    brne    _loop_d_100ms 
    dec     r18          
    brne    _loop_d_100ms 
    nop 
        
    ret





