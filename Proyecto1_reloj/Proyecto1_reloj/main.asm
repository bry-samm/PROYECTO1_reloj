;
; Proyecto1_reloj.asm
;
; Created: 3/03/2025 16:51:29
; Author : Bryan Samuel Morales Paredes

; El programa funciona como un reloj en donde por modos se puede seleccionar si se desea ver la hora
; fecha, alarma o modificar alguno de estos 

//============================================================== LABORATORIO 3 ===============================================================
.include "M328PDEF.inc"  
.equ	T2VALOR		= 100
.equ	T1VALOR		= 0x1B1E 
.equ	T0VALOR		= 251
.equ	MODO_CANT	= 9

.def	MODO		= R18
.def	CONTADOR	= R19
.def	ACTION		= R20
.def	ACTION_DIS	= R21

.def	UNI_MIN		= R3
.def	DEC_MIN		= R4
.def	UNI_HORA	= R5
.def	DEC_HORA	= R6

.def	UNI_DIA		= R7
.def	DEC_DIA		= R8
.def	UNI_MES		= R9
.def	DEC_MES		= R10

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

	LDI		R16, 0x00
	STS		UCSR0B, R16			// Desabilito el serial
	
	//Prescaler del oscilador CPU
	LDI		R16, (1 << CLKPCE)	//Habilita la escritura en CLKPR
	STS		CLKPR, R16
	LDI		R16, (1 << CLKPS2)	//Configura prescaler a 16 (16 MHz / 16 = 1 MHz)
	STS		CLKPR, R16

	// Inicializar timer0
	LDI		R16, (1<<CS02) | (1<<CS00)	//Configuración para el prescaler de 1024 (ver datasheet)
	OUT		TCCR0B, R16			// Setear prescaler del TIMER 0 a 1024
	LDI		R16, T0VALOR		//Poner a T0VALOR previamente definido
	OUT		TCNT0, R16			// Cargar valor inicial en TCNT0

	//LDI		R16, (1 << TOV0)
	//OUT		TIFR0, R16			// Limpiar la bandera de desbordamiento

	//Inicializar timer1
	//LDI		R16, 0x00
	//STS		TCCR1A, R16			// Modo normal
	LDI		R16, (1<<CS12) | (1<<CS10)
	STS		TCCR1B, R16

	LDI     R16, LOW(T1VALOR)  // Recarga Timer1
    STS     TCNT1L, R16
    LDI     R16, HIGH(T1VALOR)
    STS     TCNT1H, R16

	//LDI		R16, (1 << TOV1)
	//STS		TIFR1, R16			// Limpiar la bandera de desbordamiento 

	//Inicializar timer2
	LDI		R16, (1<<CS22)		// Configurar prescaler en 256
	STS		TCCR2B, R16			// Setear prescaler del TIMER 2 a 256
	LDI		R16, T2VALOR		// Poner a T2VALOR
	STS		TCNT2, R16			// Cargar valor inicial en TCNT2

	//LDI		R16, (1 << TOV2)
	//STS		TIFR2, R16			// Limpiar el flag de desbordamiento

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

	//Tabla para tener la cantidad de días en los meses del año 
	TABLA_DIAS:		.db		31, 28 , 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
	//				   		1	2    3	 4   5	 6   7   8	 9   10  11  12

	//Configuración display para mostrar ON/OFF alarma
	ALARMA_LETRA:	.db		0x7D, 0x5F, 0x17, 0x00
	//				   		 O     N     F

	CALL SET_INICIO
	LDI		ZL, LOW(DISPLAY_VAL <<1)	//Coloca el direccionador indirecto en la posición inicial
	LDI		ZH, HIGH(DISPLAY_VAL <<1)

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
//No usar R0 y R1

	CLR		R20					//Contador del timer0 para poder cambiar entre transistores de display
	CLR		MODO				//R18
	CLR		CONTADOR			//R19
	CLR		ACTION				//R20
	CLR		R21
//Propósito general 
	LDI		R17, 0x00
	CLR		R1
	CLR		R2
	CLR		R3
	CLR		R4
	CLR		R5
	CLR		R6
	CLR		R7
	CLR		R8
	LDI		R16, 0x01
	MOV		R9, R16
	CLR		R10
	CLR		R11	
	CLR		R12
	CLR		R16		
	CLR		R25
	CLR		R28

	SEI
//============================================================================
MAIN:
	CPI		MODO, 0
	BREQ	HORA
	CPI		MODO, 1
	BREQ	FECHA
	CPI		MODO, 2
	BREQ	CONF_MIN
	CPI		MODO, 3
	BREQ	CONF_HORA
	CPI		MODO, 4
	BREQ	CONF_DIA
	CPI		MODO, 5
	BREQ	CONF_MES
	CPI		MODO, 6
	BREQ	CONF_ALARMA_MIN
	CPI		MODO, 7
	BREQ	CONF_ALARMA_HORA
	CPI		MODO, 8
	BREQ	ON_OFF
	RJMP	MAIN

CONF_ALARMA_MIN:
	RJMP	CONF_ALARMA_MIN_F
CONF_ALARMA_HORA:
	RJMP	CONF_ALARMA_HORA_F
ON_OFF:
	RJMP	ON_OFF_1
//==================================================== RUTINAS DEL MAIN ======================================================================
HORA:
	LDI		ACTION_DIS, 0x01
	CBI		PORTB, PB3			// LEDS que muestran el modo 000
	CBI		PORTB, PB4
	CBI		PORTB, PB5

//Para el timer1
	LDI		R16, (1 << TOIE1)
	STS		TIMSK1, R16

	RJMP	MAIN
FECHA:
	LDI		ACTION_DIS, 0x02
	SBI		PORTB, PB3			// Leds	que muestran el modo 001
	CBI		PORTB, PB4
	CBI		PORTB, PB5

	////Para el timer1
	//LDI		R16, (1 << TOIE1)
	//STS		TIMSK1, R16

	RJMP	MAIN

CONF_MIN:
	//Parar interrupción del timer1
	CLR		R16
	STS		TIMSK1, R16


	LDI		ACTION_DIS, 0x01
	CBI		PORTB, PB3			// LEDS que muestran el modo 010
	SBI		PORTB, PB4
	CBI		PORTB, PB5
	//STS		TCCR1B, R16
	/*
	CPI		ACTION, 0x01
	CALL	SUMA
	CPI		ACTION, 0x02
	CALL	RESTA
	CLR		ACTION*/
	RJMP	MAIN
	
CONF_HORA:
	LDI		ACTION_DIS, 0x01
	SBI		PORTB, PB3			// LEDS que muestran el modo 011
	SBI		PORTB, PB4
	CBI		PORTB, PB5
	 
	////Para el timer1
	//CLR		R16
	//STS		TIMSK1, R16

	RJMP	MAIN
CONF_DIA:
	LDI		ACTION_DIS, 0x02
	CBI		PORTB, PB3			// LEDS que muestran el modo 100
	CBI		PORTB, PB4
	SBI		PORTB, PB5

	////Para el timer1
	//CLR		R16
	//STS		TIMSK1, R16
	
	CPI		ACTION, 0x01
	BRNE	EXIT_DIA
	LDI		ACTION, 0
	CALL	SUMA_DIA
EXIT_DIA:
	RJMP	MAIN

CONF_MES:
	LDI		ACTION_DIS, 0x02
	SBI		PORTB, PB3			// LEDS que muestran el modo 101
	CBI		PORTB, PB4
	SBI		PORTB, PB5

	////Para el timer1
	//CLR		R16
	//STS		TIMSK1, R16

	CPI		ACTION, 0x01
	BRNE	EXIT_MES
	LDI		ACTION, 0
	CALL	SUMA_MES		
EXIT_MES:
	RJMP	MAIN
CONF_ALARMA_MIN_F:
	LDI		ACTION_DIS, 0x01
	CBI		PORTB, PB3			// LEDS que muestran el modo 110
	SBI		PORTB, PB4
	SBI		PORTB, PB5

	RJMP	MAIN
CONF_ALARMA_HORA_F:
	LDI		ACTION_DIS, 0x01
	SBI		PORTB, PB3			// LEDS que muestran el modo 111
	SBI		PORTB, PB4
	SBI		PORTB, PB5

	RJMP	MAIN
ON_OFF_1:
	LDI		ZL, LOW(ALARMA_LETRA <<1)	//Coloca el direccionador indirecto en la posición inicial
	LDI		ZH, HIGH(ALARMA_LETRA <<1)

	RJMP	MAIN

//================================================= RUTINAS NO INTERRUPCIÓN ==================================================================
SET_INICIO:
	LDI		ZL, LOW(DISPLAY_VAL <<1)	//Coloca el direccionador indirecto en la posición inicial
	LDI		ZH, HIGH(DISPLAY_VAL <<1)
	RET

//++++++++++++++++++++++++++++++++++++++++++++++++++
SUMA:
	MOV		R16, R3
	INC		R16
	CPI		R16, 10
	BRNE	UPDATE_SUM_UNI_MIN
	CLR		R16
	CLR		R3
UPDATE_SUM_UNI_MIN:
	MOV		R3, R16
	CPI		R16, 0
	RET
	MOV		R16, R4
	INC		R16
	CPI		R16, 6
	BRNE	UPDATE_SUM_DEC_MIN
	CLR		R16
	CLR		R4
UPDATE_SUM_DEC_MIN:
	MOV		R4, R16
	RET
//+++++++++++++++++++++++++++++++++++++++++++++++++++
RESTA:
	MOV		R16, R3
	DEC		R16
	CPI		R16, 0
	BRNE	UPDATE_RES_UNI_MIN
	LDI		R16, 9

UPDATE_RES_UNI_MIN:
	MOV		R3, R16
	CPI		R16, 9
	RET

	MOV		R16, R4
	DEC		R16
	CPI		R16, 0
	BRNE	UPDATE_RES_DEC_MIN
	LDI		R16, 5
UPDATE_RES_DEC_MIN:
	MOV		R4, R16
	RET

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SUMA_DIA:
	MOV		R11, R8
    MOV     R17, R11     ; Copiar R16 en R17 para hacer los cálculos separados
    LSL     R11          ; R16 = R16 * 2  (Multiplicar por 2)
    LSL     R17          ; R17 = R17 * 2  (Multiplicar por 2)
    LSL     R17          ; R17 = R17 * 4  (Multiplicar por 4)
    LSL     R17          ; R17 = R17 * 8  (Multiplicar por 8)
    ADD     R11, R17     ; R16 = (R16 * 2) + (R17 * 8) = R16 * 10
	ADD		R11, R7

	LDI		ZL, LOW(TABLA_DIAS << 1)
	LDI		ZH, HIGH(TABLA_DIAS << 1)
	ADD		ZL, R12
	ADC		ZH, R1
	LPM		R17, Z			//############################

	MOV		R16, R11
	CP		R16, R17
	BRNE    CONTINUAR_SUMA_DIA
    CLR     R7
    CLR     R8
    CLR     R11
    RET

CONTINUAR_SUMA_DIA:
    MOV     R16, R7
    INC     R16
    CPI     R16, 10
    BRNE    UPDATE_SUM_UNI_DIA
    CLR     R16
    CLR     R7
    INC     R8              ; Incrementar R8 cuando R7 llega a 10
    RET

UPDATE_SUM_UNI_DIA:
    MOV     R7, R16
    RET
//++++++++++++++++++++++++++++++++++++++++++++++++++++
SUMA_MES:
	MOV		R16, R10
	CPI		R16, 1
	BRNE	CONT_NORMAL_MES
	MOV		R16, R9
	INC		R16
	CPI		R16, 3
	BRNE    UPDATE_UNI_MES
    CLR     R16
	RJMP	UPDATE_UNI_MES
CONT_NORMAL_MES:
	MOV		R16, R9
	INC		R16
	CPI		R16, 10
	BRNE    UPDATE_UNI_MES
    CLR     R16
UPDATE_UNI_MES:
    MOV     R9, R16
	CPI		R16, 0
	BRNE	ACTUALIZAR_SUM_MES
	MOV		R16, R10
    INC     R16
    CPI     R16, 2
    BRNE    UPDATE_DEC_MES
    CLR     R16
UPDATE_DEC_MES:
    MOV     R10, R16
ACTUALIZAR_SUM_MES:
	MOV		R16, R12
	INC		R16
	CPI		R16, 13
	BRNE	EXIT_SUM_MES
	CLR		R16
EXIT_SUM_MES:
	MOV		R12, R16
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
	CPI		MODO, 8
	BREQ	MODO8_ISR
//Comienza verificación y ejecución de modos
MODO0_ISR:
	RJMP	EXIT_MODO_ISR
MODO1_ISR:
	RJMP	EXIT_MODO_ISR
MODO2_ISR:
/*
	SBIS	PINB, PB1
	LDI		ACTION, 0x01
	SBIS	PINB, PB0
	LDI		ACTION, 0x02*/
	RJMP	EXIT_MODO_ISR
MODO3_ISR:
	RJMP	EXIT_MODO_ISR
MODO4_ISR:
	SBIS	PINB, PB1
	LDI		ACTION, 0x01
	SBIS	PINB, PB0
	LDI		ACTION, 0x02
	RJMP	EXIT_MODO_ISR
MODO5_ISR:
	SBIS	PINB, PB1
	LDI		ACTION, 0x01
	SBIS	PINB, PB0
	LDI		ACTION, 0x02
	RJMP	EXIT_MODO_ISR
MODO6_ISR:
	RJMP	EXIT_MODO_ISR
MODO7_ISR:
	RJMP	EXIT_MODO_ISR
MODO8_ISR:
	RJMP	EXIT_MODO_ISR

EXIT_MODO_ISR:

    POP		R16
    OUT		SREG, R16
    POP		R16
    RETI

//.......................................................................................................................
ISR_TIMER0:
	PUSH	R16
	IN		R16,  SREG
	PUSH	R16

	LDI		R16, T0VALOR		//Cargar a R16 el valor de T0VALOR definido al inicio
	OUT		TCNT0, R16			// Cargar valor inicial en TCNT0

	INC		R2
	MOV		R16, R2
	CPI		R16, 0x01
	BREQ	DISPLAY1
	CPI		R16, 0x02
	BREQ	DISPLAY2
	CPI		R16, 0x03
	BREQ	DISPLAY3
	CPI		R16, 0x04
	BREQ	DISPLAY4
//++++++++++++++++++++++++++++++++
DISPLAY1:
	CBI		PORTC, PC0
	CBI		PORTC, PC1
	CBI		PORTC, PC2

	OUT		PORTD, R1
//Verificar el modo actual para mostrar hora o fecha
	CPI		ACTION_DIS, 0x01
	BREQ	DISPLAY1_HORA
	CPI		ACTION_DIS, 0x02
	BREQ	DISPLAY1_FECHA
DISPLAY1_HORA:
	MOV		R16, R3
	RJMP	FLUJO_DISPLAY1
DISPLAY1_FECHA:
	MOV		R16, R7

FLUJO_DISPLAY1:
	//MOV		R16, R3
	LDI		ZL, LOW(DISPLAY_VAL <<1)	//Coloca el direccionador indirecto en la posición inicial
	LDI		ZH, HIGH(DISPLAY_VAL <<1)
	ADD		ZL, R16
	ADC		ZH, R1
	LPM		R16, Z
	SBI		PORTC, PC3
	OUT		PORTD, R16
	RJMP	FIN_TMR0
//++++++++++++++++++++++++++++++++
DISPLAY2:
	CBI		PORTC, PC0
	CBI		PORTC, PC1
	CBI		PORTC, PC3

	OUT		PORTD, R1

//Verificar el modo actual para mostrar hora o fecha
	CPI		ACTION_DIS, 0x01
	BREQ	DISPLAY2_HORA
	CPI		ACTION_DIS, 0x02
	BREQ	DISPLAY2_FECHA
DISPLAY2_HORA:
	MOV		R16, R4
	RJMP	FLUJO_DISPLAY2
DISPLAY2_FECHA:
	MOV		R16, R8

FLUJO_DISPLAY2:
	//MOV		R16, R4
	LDI		ZL, LOW(DISPLAY_VAL <<1)	//Coloca el direccionador indirecto en la posición inicial
	LDI		ZH, HIGH(DISPLAY_VAL <<1)
	ADD		ZL, R16
	ADC		ZH, R1
	LPM		R16, Z
	SBI		PORTC, PC2
	OUT		PORTD, R16

	RJMP	FIN_TMR0

DISPLAY3:
	CBI		PORTC, PC0
	CBI		PORTC, PC2
	CBI		PORTC, PC3
    OUT     PORTD, R1

//Verificar el modo actual para mostrar hora o fecha
	CPI		ACTION_DIS, 0x01
	BREQ	DISPLAY3_HORA
	CPI		ACTION_DIS, 0x02
	BREQ	DISPLAY3_FECHA
DISPLAY3_HORA:
	MOV		R16, R5
	RJMP	FLUJO_DISPLAY3
DISPLAY3_FECHA:
	MOV		R16, R9

FLUJO_DISPLAY3:
    //MOV     R16, R5						// Cargar unidades de hora
    LDI     ZL, LOW(DISPLAY_VAL <<1)
    LDI     ZH, HIGH(DISPLAY_VAL <<1)
    ADD     ZL, R16
    ADC     ZH, R1
    LPM     R16, Z
	SBI     PORTC, PC1

    OUT     PORTD, R16

    RJMP    FIN_TMR0

DISPLAY4:
	CBI		PORTC, PC1
	CBI		PORTC, PC2
	CBI		PORTC, PC3

    OUT     PORTD, R1
//Verificar el modo actual para mostrar hora o fecha
	CPI		ACTION_DIS, 0x01
	BREQ	DISPLAY4_HORA
	CPI		ACTION_DIS, 0x02
	BREQ	DISPLAY4_FECHA
DISPLAY4_HORA:
	MOV		R16, R6
	RJMP	FLUJO_DISPLAY4
DISPLAY4_FECHA:
	MOV		R16, R10

FLUJO_DISPLAY4:
   // MOV     R16, R6						// Cargar decenas de hora
    LDI     ZL, LOW(DISPLAY_VAL <<1)
    LDI     ZH, HIGH(DISPLAY_VAL <<1)
    ADD     ZL, R16
    ADC     ZH, R1
    LPM     R16, Z
	SBI     PORTC, PC0
    OUT     PORTD, R16

    RJMP    FIN_TMR0

FIN_TMR0:
	MOV		R16, R2
	CPI		R16, 0x04
	BRNE	RESET_END_ISR
	CLR		R16
	MOV		R2, R16

RESET_END_ISR:
	POP		R16
	OUT		SREG, R16
	POP		R16
	RETI
//...........................................................................................................
ISR_TIMER1:
    PUSH    R16
    IN      R16, SREG
    PUSH    R16

    LDI     R16, LOW(T1VALOR)  // Recarga Timer1
    STS     TCNT1L, R16
    LDI     R16, HIGH(T1VALOR)
    STS     TCNT1H, R16

    // Incrementar minutos (unidades)
    MOV     R16, R3            // Mover unidades de minutos a R16
    INC     R16                // Incrementar unidades de minutos
    CPI     R16, 10            // Comparar si unidades de minutos llegan a 10
    BRNE    UPDATE_UNI_MIN     // Si no, actualizar R3 y salir
    CLR     R16                // Si sí, resetear unidades de minutos

UPDATE_UNI_MIN:
    MOV     R3, R16            // Actualizar R3 con el nuevo valor

    // Verificar si se debe incrementar decenas de minutos
    CPI     R16, 0             // Si unidades de minutos no son 0, no incrementar decenas
    BRNE    EXIT_TMR1_ISR	   // Salir de la interrupción

    // Incrementar minutos (decenas)
    MOV     R16, R4			   // Mover decenas de minutos a R16
    INC     R16                // Incrementar decenas de minutos
    CPI     R16, 6             // Comparar si decenas de minutos llegan a 6
    BRNE    UPDATE_DEC_MIN     // Si no, actualizar R4 y salir
    CLR     R16                // Si sí, resetear decenas de minutos

UPDATE_DEC_MIN:
    MOV     R4, R16            // Actualizar R4 con el nuevo valor

    // Verificar si se debe incrementar horas
    CPI     R16, 0             // Si decenas de minutos no son 0, no incrementar horas
    BRNE    EXIT_TMR1_ISR		// Salir de la interrupción

    // Incrementar horas (unidades)
	MOV		R16, R6				// Mover el valor de R6 (decena hora) a R16
	CPI		R16, 2				//Comparar si es 2 y así unidad de hora no cuente hasta 9
	BRNE	CONT_NORMAL			// Si no es igual continuar contando normal de 0 a 9
	MOV		R16, R5				// Si si, mover R5 (unidad hora) a R16
	INC		R16					// Incrementar R16
	CPI		R16, 4				// Comparar si es igual a 4
	BRNE	UPDATE_UNI_HORA		// Si no es igual saltar a actualizar unidad hora
	RJMP	RESET_TOTAL			// Si es igual, resetear el contador debido a que llegó a 23:59
	
CONT_NORMAL:	
    MOV     R16, R5            // Mover unidades de horas a R16
    INC     R16                // Incrementar unidades de horas
    CPI     R16, 10            // Si unidades de horas llegan a 10
    BRNE    UPDATE_UNI_HORA    // Si no, actualizar R5 y salir
    CLR     R16                // Si sí, resetear unidades de horas

UPDATE_UNI_HORA:
    MOV     R5, R16            // Actualizar R5 con el nuevo valor

    // Verificar si se debe incrementar decenas de horas
    CPI     R16, 0             // Si unidades de horas no son 0, no incrementar decenas
    BRNE    EXIT_TMR1_ISR

   // Incrementar horas (decenas)
	MOV     R16, R6            // Mover decenas de horas a R16
	CPI		R16, 2				// Comparar si es igual a 2
	BRNE	CONTINUAR_DEC_HORA	// Si no es igual ir a actualizar decena hora

RESET_TOTAL:
	CLR		R6					// Reiniciar R6 (decena hora)
	CLR		R5					// Reiniciar R5 (unidad hora)
	CLR		R16					// Reiniciar registro de propósito general
	RJMP	EXIT_TMR1_ISR		// Salir de la interrupción

CONTINUAR_DEC_HORA:
	INC		R16					// Incrementar R16
	MOV		R6, R16				

EXIT_TMR1_ISR:
    POP     R16
    OUT     SREG, R16
    POP     R16
    RETI

//.........................................................................................................

ISR_TIMER2:
	PUSH	R16
	IN		R16,  SREG
	PUSH	R16
	
	//SBI		TIFR2, TOV2

	LDI		R16, T2VALOR		// Cargar definido al inicio T2VALOR
	STS		TCNT2, R16			// Cargar valor inicial en TCNT2
	
	INC		R25
	CPI		R25, 50
	BRNE	FIN_TMR2
	SBI		PINC, PC5
	CLR		R25

	 
FIN_TMR2:
	POP		R16
	OUT		SREG, R16
	POP		R16
	RETI
