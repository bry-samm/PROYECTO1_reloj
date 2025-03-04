;
; Proyecto1_reloj.asm
;
; Created: 3/03/2025 16:51:29
; Author : Bryan Samuel Morales Paredes

; El programa funciona como un reloj en donde por modos se puede seleccionar si se desea ver la hora
; fecha, alarma o modificar alguno de estos 

//============================================================== LABORATORIO 3 ===============================================================
.include "M328PDEF.inc"
.equ	T1VALOR		= 0x00
.equ	MODO		= 8
.def	MODO_ACTUAL	= R17
.def	CONTADOR	= R18
.def	ACTION		= R19

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
	CLR		MODO_ACTUAL			//R19
	CLR		CONTADOR			//R18
	CLR		ACTION				//R17
	LDI		R16, 0x00
	
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
	RJMP	MAIN
HORA:
	RJMP	MAIN
CONF_MIN:
	RJMP	MAIN
CONF_HORA:
	RJMP	MAIN
CONF_DIA:
	RJMP	MAIN
CONF_MES:
	RJMP	MAIN
CONF_ALARMA:
	RJMP	MAIN
ALARMA_OFF:
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

	SBI		

    POP		R16
    OUT		SREG, R16
    POP		R16
    RETI

ISR_TIMER0:
	PUSH	R16
	IN		R16,  SREG
	PUSH	R16

	LDI		R16, 100			//Poner a 100
	OUT		TCNT0, R16			// Cargar valor inicial en TCNT0

	INC		R1
	MOV		R16, R1
	ANDI	R16, 0x04
	CPI		R16, 0x01
	BREQ	DISPLAY1
	CPI		R16, 0x02
	BREQ	DISPLAY2
	CPI		R16, 0x03
	BREQ	DISPLAY3
	CPI		R16, 0x04
	BREQ	DISPLAY4

DISPLAY1:
	RJMP	FIN_TMR0

	

FIN_TMR0:
	POP		R16
	OUT		SREG, R16
	POP		R16
	RETI

ISR_TIMER1:
	PUSH	R16
	IN		R16,  SREG
	PUSH	R16


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
