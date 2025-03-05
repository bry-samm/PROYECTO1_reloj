;
; Proyecto1_reloj.asm
;
; Created: 3/03/2025 16:51:29
; Author : Bryan Samuel Morales Paredes

; El programa funciona como un reloj en donde por modos se puede seleccionar si se desea ver la hora
; fecha, alarma o modificar alguno de estos 

//============================================================== LABORATORIO 3 ===============================================================
.include "M328PDEF.inc"
.equ	T1VALOR		= 0xC2F7
.equ	MODO_CANT	= 8
.def	MODO		= R18
.def	CONTADOR	= R19
.def	ACTION		= R20
.def	UNI_MIN		= R21
.def	DEC_MIN		= R22
.def	UNI_HORA	= R23
.def	DEC_HORA	= R24

.cseg
.org	0x0000
	JMP	START
	
.org	PCI0addr
	JMP	ISR_BOTON

.org	OVF2addr
	JMP	ISR_TIMER2

.org	OVF1addr
	JMP	ISR_TIMER1

.org	OVF0addr
	JMP	ISR_TIMER0
	
//==============================================================================
START:
//Configuración de la pila
	LDI		R16, LOW(RAMEND)
	OUT		SPL, R16		// SPL 
	LDI		R16, HIGH(RAMEND)
	OUT		SPH, R16		// SPH 

//=================================================================================
//Configurar el microcontrolador (MCU)
SETUP:
	CLI					//Deshabilito interrupciones globales
	
	//Prescaler del oscilador
	LDI		R16, (1 << CLKPCE)	//Habilita la escritura en CLKPR
	STS		CLKPR, R16
	LDI		R16, (1 << CLKPS2)	//Configura prescaler a 16 (16 MHz / 16 = 1 MHz)
	STS		CLKPR, R16
//#########################################
	// Inicializar timer0
	LDI		R16, (1<<CS01) | (1<<CS00)	//Configuración para el prescaler de 64 (ver datasheet)
	OUT		TCCR0B, R16			// Setear prescaler del TIMER 0 a 64
	LDI		R16, 100			//Poner a 100
	OUT		TCNT0, R16			// Cargar valor inicial en TCNT0
//######################################

	//Inicializar timer1
	LDI		R16, LOW(T1VALOR)
	STS		TCNT1L, R16
	LDI		R16, HIGH(T1VALOR)
	STS		TCNT1H, R16

	LDI		R16, 0x00
	STS		TCCR1A, R16
	LDI		R16, (1<<CS11) | (1<<CS10)
	STS		TCCR1B, R16
	
	//PORTD y PORTC como salida e inicialmente apagado 
	LDI		R16, 0xFF
	OUT		DDRD, R16			//Setear puerto D como salida
	OUT		DDRC, R16
	LDI		R16, 0x00
	OUT		PORTD, R16			//Apagar puerto D
	OUT		PORTC, R16

	//PORTB parcial
	//Como entrada
	CBI		DDRB, PB0
	CBI		DDRB, PB1
	CBI		DDRB, PB2
	SBI		PORTB, PB0
	SBI		PORTB, PB1
	SBI		PORTB, PB2
	//Como salida
	SBI		DDRB, PB3
	SBI		DDRB, PB4
	SBI		DDRB, PB5
	CBI		PORTB, PB3
	CBI		PORTB, PB4
	CBI		PORTB, PB5

	//Configuración del display

	DISPLAY_VAL:	.db		0x7D, 0x48,	0x3E, 0x6E, 0x4B, 0x67, 0x77, 0x4C, 0x7F, 0x6F
	//						 0	    1	  2		3	 4     5	  6     7     8		9
	CALL SET_INICIO

//===================== CONFIGURACIÓN INTERRUPCIONES =======================
//Para el timer2
	LDI		R16, (1 << TOIE2)
	STS		TIMSK2, R16

//Para el timer1
	LDI		R16, (1 << TOIE1)
	STS		TIMSK1, R16

//Para el timer0
	LDI		R16, (1 << TOIE0)
	STS		TIMSK0, R16

//Para los botones
	LDI		R16, (1 << PCINT0) | (1 << PCINT1) | (1 << PCINT2) //Habilito los pines en específico que causan la interrupción 
	STS		PCMSK0, R16
	
	LDI		R16, (1 << PCIE0)	//Habilito las interrupciones en el PORTB
	STS		PCICR, R16

//======================================= DEFINIR Y SETEAR EN 0 ALGUNOS REGISTROS ========================================================
//No usar registro 30 y 31

	CLR		R20					//Contador del timer0 para poder cambiar entre transistores de display
	CLR		MODO				//R18
	CLR		CONTADOR			//R19
	CLR		ACTION				//R20
//Propósito general 
	LDI		R17, 0x00
	LDI		R16, 0x00
	CLR		R1
	
	LPM		R23, Z				// Mostrar en el display1 0
	LPM		R25, Z				// Mostrar en el display2 0

	SEI
//============================================================================
MAIN:

	OUT		PORTD, R17  //###############################
	
	CPI		MODO, 0
	BREQ	FECHA
	CPI		MODO, 1
	BREQ	HORA
	CPI		MODO, 2
	BREQ	CONF_MIN
	CPI		MODO, 3
	BREQ	CONF_HORA
	CPI		MODO, 4
	BREQ	CONF_DIA
	CPI		MODO, 5
	BREQ	CONF_MES
	CPI		MODO, 6
	BREQ	CONF_ALARMA
	CPI		MODO, 7
	BREQ	ALARMA_OFF
	RJMP	MAIN


//==================================================== RUTINAS DEL MAIN ======================================================================

FECHA:
	CBI		PORTB, PB3			// LEDS que muestran el modo 000
	CBI		PORTB, PB4
	CBI		PORTB, PB5

	RJMP	MAIN
HORA:
	SBI		PORTB, PB3			// Leds	que muestran el modo 001
	CBI		PORTB, PB4
	CBI		PORTB, PB5

	RJMP	MAIN
CONF_MIN:
	CBI		PORTB, PB3			// LEDS que muestran el modo 010
	SBI		PORTB, PB4
	CBI		PORTB, PB5

	RJMP	MAIN
CONF_HORA:
	SBI		PORTB, PB3			// LEDS que muestran el modo 011
	SBI		PORTB, PB4
	CBI		PORTB, PB5

	RJMP	MAIN
CONF_DIA:
	CBI		PORTB, PB3			// LEDS que muestran el modo 100
	CBI		PORTB, PB4
	SBI		PORTB, PB5

	RJMP	MAIN
CONF_MES:
	SBI		PORTB, PB3			// LEDS que muestran el modo 101
	CBI		PORTB, PB4
	SBI		PORTB, PB5

	RJMP	MAIN
CONF_ALARMA:
	CBI		PORTB, PB3			// LEDS que muestran el modo 110
	SBI		PORTB, PB4
	SBI		PORTB, PB5

	RJMP	MAIN
ALARMA_OFF:
	SBI		PORTB, PB3			// LEDS que muestran el modo 111
	SBI		PORTB, PB4
	SBI		PORTB, PB5

	RJMP	MAIN

//================================================= RUTINAS NO INTERRUPCIÓN ==================================================================
SET_INICIO:
	LDI		ZL, LOW(DISPLAY_VAL <<1)	//Coloca el direccionador indirecto en la posición inicial
	LDI		ZH, HIGH(DISPLAY_VAL <<1)
	RET

//================================================== RUTINAS DE INTERRUPCIÓN =====================================================================
ISR_BOTON:
    PUSH	R16
    IN		R16, SREG
    PUSH	R16

	SBIS	PINB, PB2			// Verifica si se presionó el botón de modo
	INC		MODO
	LDI		R16, MODO_CANT
	CP		MODO, R16			// Verifica si ya se sobrepasó la cantidad de modos
	BRNE	CONTINUAR_BOTON		
	CLR		MODO

CONTINUAR_BOTON:				//Verifica que modo debe de ejecutarse
	CPI		MODO, 0
	BREQ	MODO0_ISR
	CPI		MODO, 1
	BREQ	MODO1_ISR
	CPI		MODO, 2
	BREQ	MODO2_ISR
	CPI		MODO, 3
	BREQ	MODO3_ISR
	CPI		MODO, 4
	BREQ	MODO4_ISR
	CPI		MODO, 5
	BREQ	MODO5_ISR
	CPI		MODO, 6
	BREQ	MODO6_ISR
	CPI		MODO, 7
	BREQ	MODO7_ISR
//Comienza verificación y ejecución de modos
MODO0_ISR:
	RJMP	EXIT_MODO_ISR
MODO1_ISR:
	RJMP	EXIT_MODO_ISR
MODO2_ISR:
	RJMP	EXIT_MODO_ISR
MODO3_ISR:
	RJMP	EXIT_MODO_ISR
MODO4_ISR:
	RJMP	EXIT_MODO_ISR
MODO5_ISR:
	RJMP	EXIT_MODO_ISR
MODO6_ISR:
	RJMP	EXIT_MODO_ISR
MODO7_ISR:
	RJMP	EXIT_MODO_ISR

EXIT_MODO_ISR:

    POP		R16
    OUT		SREG, R16
    POP		R16
    RETI

//..............................................................
ISR_TIMER0:
	PUSH	R17
	PUSH	R16
	IN		R16,  SREG
	PUSH	R16

	LDI		R16, 100			//Poner a 100
	OUT		TCNT0, R16			// Cargar valor inicial en TCNT0

	LDI		R17, 0x00
	INC		R1
	MOV		R16, R1
	CPI		R16, 0x01
	BREQ	DISPLAY1
	CPI		R16, 0x02
	BREQ	DISPLAY2
	CPI		R16, 0x03
	BREQ	DISPLAY3
	CPI		R16, 0x04
	BREQ	DISPLAY4

DISPLAY1:
	OUT		PORTC, R17
	OUT		PORTD, R17
	SBI		PORTC, PC0
	OUT		PORTD, UNI_MIN	
	RJMP	FIN_TMR0
DISPLAY2:
	OUT		PORTC, R17
	OUT		PORTD, R17
	SBI		PORTC, PC1
	OUT		PORTD, DEC_MIN	
	RJMP	FIN_TMR0
DISPLAY3:
	OUT		PORTC, R17
	OUT		PORTD, R17
	SBI		PORTC, PC2
	OUT		PORTD, UNI_HORA
	RJMP	FIN_TMR0
DISPLAY4:
	OUT		PORTC, R17
	OUT		PORTD, R17
	SBI		PORTC, PC3
	OUT		PORTD, DEC_HORA	
	RJMP	FIN_TMR0
	
FIN_TMR0:
	CPI		R16, 0x04
	BRNE	RESET_END_ISR
	CLR		R16
	MOV		R1, R16

RESET_END_ISR:
	POP		R16
	OUT		SREG, R16
	POP		R16
	POP		R17
	RETI
//.............................................................
ISR_TIMER1:
	PUSH	R16
	IN		R16,  SREG
	PUSH	R16

	LDI		R16, LOW(T1VALOR)
	STS		TCNT1L, R16
	LDI		R16, HIGH(T1VALOR)
	STS		TCNT1H, R16

	POP		R16
	OUT		SREG, R16
	POP		R16
	RETI

ISR_TIMER2:
	PUSH	R16
	IN		R16,  SREG
	PUSH	R16



	POP		R16
	OUT		SREG, R16
	POP		R16
	RETI
