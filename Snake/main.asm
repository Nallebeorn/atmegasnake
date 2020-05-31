// We should consider renaming some of these and changing the comments to a different structure. -Sebastian

//////////////////////////////      
//       LEDJOY SNAKE       //        ########
//////////////////////////////      ##__####__##
//                          //      #|  |##|  |#
//       Created  by:       //      #####uu#####
//  Christoffer Cederfeldt  //        ########
//	 Sebastian  Alkstrand   //         |||| |
//	   Amanda Lindqvist     //         ######
//							//
//////////////////////////////

// Interrupt registers
.DEF rStatus       = r3  // Lagra statusregister så de kan återställas efter avbrottet
.DEF rITemp         = r16
.DEF rRow          = r17 // Vilken led-rad som ska tändas härnäst
.DEF rUpdate       = r18 // Räknar upp (till TICK_RATE) tills det är dags att uppdatera spellogiken
// Not interrupt registers
.DEF rJoyX         = r19 // Joystick x-axel
.DEF rJoyY         = r20 // Joystick y-axel
.DEF rMask         = r21 // Används i setPixel, värdet på en matrisrad för att tända en viss pixel i raden
.DEF rTemp        = r22
.DEF rX            = r23 // Argument till setPixel + temporär huvudposition
.DEF rY            = r24 // -||-

.EQU SNAKE_LENGTH  = 4
.EQU TICK_RATE	   = 128


.DSEG

matrix:   .BYTE 8            // Varje byte representerar en rad. MSB är kolumn längst till höger och LSB är kolumn längst till vänster.
snakeX:   .BYTE SNAKE_LENGTH // Array av x-positioner (första är huvudets x)
snakeY:   .BYTE SNAKE_LENGTH // Array av y-positioner (första är huvudets y)

.CSEG
.ORG 0x0000
     jmp init 
     jmp 0
     jmp 0
     jmp 0
     jmp 0
     jmp 0
     jmp 0
     jmp 0
     jmp 0
     jmp 0
     jmp 0
     jmp 0
     jmp 0
     jmp 0
     jmp 0
     jmp 0
     jmp timer

init:
     // Sätt stackpekaren till högsta minnesadressen
     ldi	rITemp, HIGH(RAMEND)
     out	SPH, rITemp
     ldi	rITemp, LOW(RAMEND)
     out	SPL, rITemp

     // Sätt lamppins till output
     ldi    rITemp, 0x0f
     out    DDRC, rITemp
     ldi    rITemp, 0xfc
     out    DDRD, rITemp
     ldi    rITemp, 0x3f
     out    DDRB, rITemp

     // Initialisera variabler
     ldi    rRow, 0x00

	      // Big Smile
     ldi    rITemp, 0x00 
     sts    matrix + 0, rITemp 
     ldi    rITemp, 0x24 
     sts    matrix + 1, rITemp 
     ldi    rITemp, 0x24 
     sts    matrix + 2, rITemp 
     ldi    rITemp, 0x00 
     sts    matrix + 3, rITemp 
 
     ldi    rITemp, 0x42 
     sts    matrix + 4, rITemp 
     ldi    rITemp, 0x3C 
     sts    matrix + 5, rITemp 
     ldi    rITemp, 0x0 
     sts    matrix + 6, rITemp 
     ldi    rITemp, 0x0 
     sts    matrix + 7, rITemp 

	  // sätt alla snake-segment till position (3, 3) "Bättre än Benjamins grupp (4, 4)" -Christoffer
     ldi    rITemp, 0x03        
     sts    snakeX + 0, rITemp
     sts    snakeY + 0, rITemp
     sts    snakeX + 1, rITemp
     sts    snakeY + 1, rITemp
     sts    snakeX + 2, rITemp
     sts    snakeY + 2, rITemp
     sts    snakeX + 3, rITemp
     sts    snakeY + 3, rITemp

	 // Sätt joystickens neutral position (hälften av 256)
	 ldi    rJoyX, 0x80     
     ldi    rJoyY, 0x80

	 // Aktivera och konfigurera A/D-omvandling for joystickavläsning
     ldi    rITemp, 0x60
     sts    ADMUX, rITemp
     ldi    rITemp, 0x87
     sts    ADCSRA, rITemp

     // Aktivera och konfigurera timern
     lds    rITemp, TCCR0B
     ori    rITemp, 0x02
     out    TCCR0B, rITemp
     sei
     lds    rITemp, TIMSK0
     ori    rITemp, 0x01
     sts    TIMSK0, rITemp

	  //nollställ räknaren
	 ldi    rUpdate, 0x00
	 
	// This part waits for 1 second. Based on "http://www.bretmulvey.com/avrdelay.html"
	ldi  r16, 41 //16
    ldi  r22, 150 //22
    ldi  r25, 128 //26
L1: dec  r25 //26
    brne L1
    dec  r22 //22
    brne L1
    dec  r16 //16
    brne L1

loop:
// A/D-omvandling
// X-axel
	lds     rTemp, ADMUX   // ADMUX använd för att välja rätt analogingång
    andi    rTemp, 0xf0    // Sätt bit 0-3 till 0
    ori     rTemp, 0x05    // Sätt bit 0-3 till rätt värde för x-axelns analogingång
    sts     ADMUX, rTemp
    lds     rTemp, ADCSRA
    ori     rTemp, 1 << ADSC
    sts     ADCSRA, rTemp      // Sätt bit "ADSC" i ADCSRA till 1 för att starta A/D-omvandlaren
waitJoyX:                   // Vänta tills A/D-omvandlare är klar (= bit "ADSC" i ADCSRA är 0)
    lds     rTemp, ADCSRA
    sbrc    rTemp, ADSC    // Hoppa över nästa instruktion om bit "ADSC" i ADCSRA är noll
    jmp     waitJoyX // Ovillkorligt hopp till waitJoyX

// Uppdatera inte variabeln om joysticken är i neutralt läge (gör att det känns bättre att spela med piltangenterna)
    lds     rTemp, ADCH
    cpi     rTemp, 0xe0 // Jämnför rTemp med konstanten 224
    brsh    loadJoyX // Hoppar till loadJoyX om rTemp är högre eller lika med 224
    cpi     rTemp, 0x20
    brsh    readjoyY
loadJoyX:
    mov     rJoyX, rTemp
    ldi     rJoyY, 0x80

// Y-axel (samma process som för y)
readJoyY:
	lds     rTemp, ADMUX
    andi    rTemp, 0xf0
    ori     rTemp, 0x04    // Ny analogingång
    sts     ADMUX, rTemp
    lds     rTemp, ADCSRA
    ori     rTemp, 1 << ADSC
    sts     ADCSRA, rTemp
waitJoyY:
    lds     rTemp, ADCSRA
    sbrc    rTemp, ADSC
    jmp     waitJoyY

// Uppdatera inte variabeln om joysticken är i neutralt läge (gör att det känns bättre att spela med piltangenterna)
    lds     rTemp, ADCH
    cpi     rTemp, 0xe0
    brsh    loadJoyY
    cpi     rTemp, 0x20
    brsh    readJoyDone
loadJoyY:
    mov     rJoyY, rTemp
    ldi     rJoyX, 0x80
readJoyDone:

// Kolla om det är dags att uppdatera
    cpi     rUpdate, TICK_RATE
    brlo    loop                        // Om nej, loopa för att fortsätta vänta
    ldi     rUpdate, 0x00               // Om ja, nollställ räknaren

// Flytta huvud
    lds     rX, snakeX
testLeft:
    cpi     rJoyX, 0xe0
    brlo    testRight
    cpi     rX, 0x01    // Flytta inte utanför kanten på banan
    brlo    testRight
    subi    rX, 1
    jmp     testXDone
testRight:
    cpi     rJoyX, 0x20
    brsh    testXDone
    cpi     rX, 0x07    // Flytta inte utanför kanten på banan
    brsh    testXDone
    subi    rX, -1
testXDone:

    lds     rY, snakeY
testUp:
    cpi     rJoyY, 0xe0
    brlo    testDown
    cpi     rY, 0x01    // Flytta inte utanför kanten på banan
    brlo    testDown
    subi    rY, 1
    jmp     testYDone
testDown:
    cpi     rJoyY, 0x20
    brsh    testYDone
    cpi     rY, 0x07    // Flytta inte utanför kanten på banan
    brsh    testYDone
    subi    rY, -1
testYDone:

// Flytta inte svans om inte huvudet rört på sig
    lds     rTemp, snakeX
    cp      rTemp, rX  // Jämnför rTemp (huvudets gamla x) med rX (huvudets nya x)
    brne    moveTail // Hoppar till moveTail om rTemp inte är lika med rX
    lds     rTemp, snakeY
    cp      rTemp, rY
    breq    moveTailDone // Hoppar till moveTailDone om rTemp är lika med rY (om Z bit:en i statusregistret är 1)

// Flytta svans
// Gå igenom snake-arrayerna bakifrån och flytta ned varje element ett steg
moveTail:
    ldi     YL, LOW( snakeX + SNAKE_LENGTH - 2)
    ldi     YH, HIGH(snakeX + SNAKE_LENGTH - 2)
    ldi     ZL, LOW( snakeY + SNAKE_LENGTH - 2)
    ldi     ZH, HIGH(snakeY + SNAKE_LENGTH - 2)
    ldi     rITemp, 0x00
tailLoop:
    ld      rTemp, Y
    std     Y + 1, rTemp
    ld      rTemp, Z
    std     Z + 1, rTemp

    dec     YL
    dec     ZL
    inc     rITemp
    cpi     rITemp, SNAKE_LENGTH - 1
    brlo    tailLoop

moveTailDone:
// Skriv huvudets nya position till RAM
    sts     snakeX, rX
    sts     snakeY, rY

// Töm matris
    ldi     rTemp, 0x00
    sts     matrix + 0, rTemp
    sts     matrix + 1, rTemp
    sts     matrix + 2, rTemp
    sts     matrix + 3, rTemp
    sts     matrix + 4, rTemp
    sts     matrix + 5, rTemp
    sts     matrix + 6, rTemp
    sts     matrix + 7, rTemp

// Rita snake
// (loopar är överskattade)
    lds     rX, snakeX  // rX och rY används som argument till setPixel nu
    lds     rY, snakeY
    call    setPixel

    lds     rX, snakeX + 1
    lds     rY, snakeY + 1
    call    setPixel

    lds     rX, snakeX + 2
    lds     rY, snakeY + 2
    call    setPixel

    lds     rX, snakeX + 3
    lds     rY, snakeY + 3
    call    setPixel

// Klar! Loopa och invänta nästa update
    jmp     loop

//----------------------------------------------------------------------//

setPixel:
// Sätter på en viss pixel i matrisen
// rX = x-position att rita till (förstörs)
// rY = y-position att rita till (förstörs)

// Beräkna 1 << rX
    ldi     rMask, 0x01
findXMask:
    cpi     rX, 0x00
    breq    findXMaskDone   // Loopa tills rX == 0
    lsl     rMask // Skiftar bit:arna i rMask ett steg åt vänster
    dec     rX
    jmp     findXMask
findXMaskDone:

// Hitta rätt rad (matrix + rY)
    ldi     YL, LOW(matrix)
    ldi     YH, HIGH(matrix)
    add     YL, rY

// Kombinera 1 << rX med radens gamla värde
    ld      rTemp, Y
    or      rTemp, rMask
    st      Y, rTemp

    ret

//----------------------------------------------------------------------//

timer:
    in      rStatus, SREG   // Spara statusregistret så det kan återställas senare
    push    rITemp // Sänker SP och sätter rITemp på toppen av stacken
    
// Clear all col:s
    cbi     PORTD, PORTD6
    cbi     PORTD, PORTD7
    cbi     PORTB, PORTB0
    cbi     PORTB, PORTB1
    cbi     PORTB, PORTB2
    cbi     PORTB, PORTB3
    cbi     PORTB, PORTB4
    cbi     PORTB, PORTB5

// Clear all row:s
	cbi     PORTD, PORTD5
    cbi     PORTC, PORTC0
    cbi     PORTC, PORTC1
    cbi     PORTC, PORTC2
    cbi     PORTC, PORTC3
    cbi     PORTD, PORTD2
    cbi     PORTD, PORTD3
    cbi     PORTD, PORTD4


// Läs in värdet på rätt rad (matrix + rRow)
    ldi     XL, LOW(matrix)
    ldi     XH, HIGH(matrix)
    add     XL, rRow

// Enable correct columns
    ld      rITemp, X

//Check all columns for which should be active during this frame
col0:
    bst     rITemp, 0 // Take bit 0 from rITemp and set it to bit T in the statusReg
    brtc    col1 // Go to col1 if bit 0 is 0
    sbi     PORTD, PORTD6 // else set this col active and fall down to col1 to continue
col1:
    bst     rITemp, 1 // the same as col0, repeated for all columns
    brtc    col2
    sbi     PORTD, PORTD7
col2:
    bst     rITemp, 2
    brtc    col3
    sbi     PORTB, PORTB0
col3:
    bst     rITemp, 3
    brtc    col4
    sbi     PORTB, PORTB1
col4:
    bst     rITemp, 4
    brtc    col5
    sbi     PORTB, PORTB2
col5:
    bst     rITemp, 5
    brtc    col6
    sbi     PORTB, PORTB3
col6:
    bst     rITemp, 6
    brtc    col7
    sbi     PORTB, PORTB4
col7:
    bst     rITemp, 7
    brtc    rowJmpTable
    sbi     PORTB, PORTB5

// Jump to the desired row based on rRow
rowJmpTable:
	//row0
    cpi     rRow, 0x00
    breq    row0
	//row1
    cpi     rRow, 0x01
    breq    row1
	//row2
    cpi     rRow, 0x02
    breq    row2
	//row3
	cpi     rRow, 0x03
    breq    row3
	//row4
	cpi     rRow, 0x04
    breq    row4
	//row5
	cpi     rRow, 0x05
    breq    row5
	//row6
	cpi     rRow, 0x06
    breq    row6
	//row7
	cpi     rRow, 0x07
    breq    row7

row0:
    sbi     PORTC, PORTC0   // Activate Row 0
    jmp     rowsDone
row1:
    sbi     PORTC, PORTC1   // Activate Row 1 etc...
    jmp     rowsDone
row2:
    sbi     PORTC, PORTC2
    jmp     rowsDone
row3:
    sbi     PORTC, PORTC3
    jmp     rowsDone
row4:
    sbi     PORTD, PORTD2
    jmp     rowsDone
row5:
    sbi     PORTD, PORTD3
    jmp     rowsDone
row6:
    sbi     PORTD, PORTD4
    jmp     rowsDone
row7:
    sbi     PORTD, PORTD5
    ldi     rRow, 0x00
    inc     rUpdate
    jmp     lastRow


rowsDone:
    inc     rRow

lastRow:
    
    pop     rITemp // Sätter rITemp till elementet i toppen av stacken och ökar SP
    out     SREG, rStatus // Återställ statusregistret till vad det var innan avbrottet startade
    reti