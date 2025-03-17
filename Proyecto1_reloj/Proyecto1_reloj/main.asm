;
; Proyecto1_reloj.asm
;
; Created: 3/03/2025 16:51:29
; Author : Bryan Samuel Morales Paredes

; El programa funciona como un reloj en donde por modos se puede seleccionar si se desea ver la hora
; fecha, alarma o modificar alguno de estos 

//============================================================== PROYECTO 1: RELOJ  ===============================================================
.include "M328PDEF.inc"  
.equ	T2VALOR			= 100		// Valor para el timer2 para interrupmir cada 10ms
.equ	T1VALOR			= 0x1B1E	// Valor para el timer1 para interrumpir cada 60s
.equ	T0VALOR			= 251		// Valor para el timer0 para interrumpir cada 100ms
.equ	MODO_CANT		= 9			// Se establecen la cantidad de modos 

.def	MODO			= R20		// Registro el cual indica el modo actual
.def	CONTADOR		= R21		// Registro para llevar conteo de la cantidad de veces que se entra a ISR_TIMER2
.def	ACTION			= R22		// Registro que se utiliza como bandera y se modifica dependiendo del botón que se presionó
.def	ACTION_DIS		= R23		// Registro que se utiliza como bandera y se modifica dependiendo de que valor se desea mostrar en el display

.def	UNI_MIN			= R3
.def	DEC_MIN			= R4
.def	UNI_HORA		= R5
.def	DEC_HORA		= R6

.def	UNI_DIA			= R7
.def	DEC_DIA			= R8
.def	UNI_MES			= R9
.def	DEC_MES			= R10

.def	UNI_MIN_ALARM	= R11
.def	DEC_MIN_ALARM	= R12
.def	UNI_HORA_ALARM	= R13
.def	DEC_HORA_ALARM	= R14

.cseg
.org	0x0000
	JMP	START
	
.org	PCI0addr
	JMP	ISR_BOTON					// Se establece el vector de interrupción

.org	OVF2addr
	JMP	ISR_TIMER2					// Se establece el vector de interrupción
	
.org	OVF1addr
	JMP	ISR_TIMER1					// Se establece el vector de interrupción

.org	OVF0addr
	JMP	ISR_TIMER0					// Se establece el vector de interrupción
//==============================================================================
START:
//Configuración de la pila
	LDI		R16, LOW(RAMEND)
	OUT		SPL, R16				// SPL 
	LDI		R16, HIGH(RAMEND)
	OUT		SPH, R16				// SPH 
//=================================================================================
//Configurar el microcontrolador (MCU)
SETUP:
	CLI								//Deshabilito interrupciones globales

	LDI		R16, 0x00
	STS		UCSR0B, R16				// Desabilito el serial
	
	//Prescaler del oscilador CPU
	LDI		R16, (1 << CLKPCE)		//Habilita la escritura en CLKPR
	STS		CLKPR, R16
	LDI		R16, (1 << CLKPS2)		//Configura prescaler a 16 (16 MHz / 16 = 1 MHz)
	STS		CLKPR, R16

	// Inicializar timer0
	LDI		R16, (1<<CS02) | (1<<CS00)	//Configuración para el prescaler de 1024 (ver datasheet)
	OUT		TCCR0B, R16				// Setear prescaler del TIMER0 a 1024
	LDI		R16, T0VALOR			// Poner a T0VALOR previamente definido
	OUT		TCNT0, R16				// Cargar valor inicial en TCNT0

	//Inicializar timer1
	//LDI		R16, 0x00
	//STS		TCCR1A, R16			// Modo normal
	LDI		R16, (1<<CS12) | (1<<CS10)	//Configuración para el prescaler de 1024 (igual que el TIMER0)
	STS		TCCR1B, R16				// Setear prescaler del TIMER1 a 1024

	LDI     R16, LOW(T1VALOR)		// Recarga Timer1 LOW
    STS     TCNT1L, R16
    LDI     R16, HIGH(T1VALOR)		// Recarga Timer1 HIGH
    STS     TCNT1H, R16

	//Inicializar timer2
	LDI		R16, (1<<CS22)			// Configurar prescaler en 64
	STS		TCCR2B, R16				// Setear prescaler del TIMER 2 a 64
	LDI		R16, T2VALOR			// Poner a T2VALOR
	STS		TCNT2, R16				// Cargar valor inicial en TCNT2

	//PORTD y PORTC como salida e inicialmente apagado 
	LDI		R16, 0xFF
	OUT		DDRD, R16			//Setear puerto D como salida
	OUT		DDRC, R16			//Setear puerto C como salida
	LDI		R16, 0x00
	OUT		PORTD, R16			//Apagar puerto D
	OUT		PORTC, R16			//Apagar puerto C

	//PORTB parcial
	//Como entrada
	CBI		DDRB, PB0
	CBI		DDRB, PB1
	CBI		DDRB, PB2
	SBI		PORTB, PB0			// Activar pullup
	SBI		PORTB, PB1
	SBI		PORTB, PB2
	//Como salida
	SBI		DDRB, PB3
	SBI		DDRB, PB4
	SBI		DDRB, PB5
	CBI		PORTB, PB3			// Inicialmente apagado
	CBI		PORTB, PB4
	CBI		PORTB, PB5

	//Configuración del display
	DISPLAY_VAL:	.db		0x7D, 0x48,	0x3E, 0x6E, 0x4B, 0x67, 0x77, 0x4C, 0x7F, 0x6F
	//						 0	    1	  2		3	 4     5	  6     7     8		9

	//Tabla para tener la cantidad de días en los meses del año 
	TABLA_DIAS:		.db		31, 28 , 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
	//				   		1	2    3	 4   5	 6   7   8	 9   10  11  12

	//Configuración display para mostrar ON/OFF alarma
	ALARMA_LETRA:	.db		0x00, 0x7D, 0x5D, 0x17
	//				   		        O     N     F

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
//No usar registro 30 y 31 por que son respectivos del puntero Z
//No usar R0 y R1

	CLR		MODO				//R20
	CLR		CONTADOR			//R21
	CLR		ACTION				//R22
	CLR		ACTION_DIS			//R23

	CLR		R1
	CLR		R2
	CLR		R3
	CLR		R4
	CLR		R5
	CLR		R6
	CLR		R8
	LDI		R16, 0x01
	MOV		R9, R16				// UNIDAD MES (R9) inicialmente como 1 (enero)
	MOV		R7, R16				// Unidad dia (R7) inicialmetnte como 1 (día uno)
	CLR		R10
	CLR		R11	
	CLR		R12
	CLR		R13
	CLR		R14
	LDI		R16, 0x03
	MOV		R15, R16			// Coloca el puntero en "F"
	LDI		R17, 0x03			// Coloca el puntero en "F"
	LDI		R18, 0x01			// Coloca el puntero en "O"
	CLR		R19
	CLR		R20
	CLR		R21
	CLR		R22
	CLR		R24
	CLR		R25
	CLR		R26
	CLR		R27
	CLR		R28

	CLR		R16	
	SEI
//============================================================================
//En el main se encuentra las instrucciones a realizar para cada modo del reloj
MAIN:
	CPI		MODO, 0
	BREQ	HORA_RJMP
	CPI		MODO, 1
	BREQ	FECHA_RJMP
	CPI		MODO, 2
	BREQ	CONF_MIN_RJMP
	CPI		MODO, 3
	BREQ	CONF_HORA_RJMP
	CPI		MODO, 4
	BREQ	CONF_MES_RJMP
	CPI		MODO, 5
	BREQ	CONF_DIA_RJMP
	CPI		MODO, 6
	BREQ	CONF_ALARMA_MIN_RJMP
	CPI		MODO, 7
	BREQ	CONF_ALARMA_HORA_RJMP
	CPI		MODO, 8
	BREQ	ON_OFF_RJMP
	RJMP	MAIN

//Esta parte es para evitar el error out of range
HORA_RJMP:
	RJMP	HORA
FECHA_RJMP:
	RJMP	FECHA
CONF_MIN_RJMP:
	RJMP	CONF_MIN
CONF_HORA_RJMP:
	RJMP	CONF_HORA
CONF_DIA_RJMP:
	RJMP	CONF_DIA
CONF_MES_RJMP:
	RJMP	CONF_MES
CONF_ALARMA_MIN_RJMP:
	RJMP	CONF_ALARMA_MIN
CONF_ALARMA_HORA_RJMP:
	RJMP	CONF_ALARMA_HORA
ON_OFF_RJMP:
	RJMP	ON_OFF
//======================================================================= RUTINAS DEL MAIN ======================================================================
HORA:
	LDI		ACTION_DIS, 0x01	// Bandera para mostrar la hora en displays
	CBI		PORTB, PB3			// LEDS que muestran el modo 000
	CBI		PORTB, PB4
	CBI		PORTB, PB5
	//Habilitar interrupciones del timer1
	LDI		R16, (1 << TOIE1)
	STS		TIMSK1, R16

	CALL	SONAR_ALARMA
	RJMP	MAIN
//---------------------------------------------------------------------------------------------------------------
FECHA:
	LDI		ACTION_DIS, 0x02	// Bandera para mostrar la fecha en displays
	SBI		PORTB, PB3			// Leds	que muestran el modo 001
	CBI		PORTB, PB4
	CBI		PORTB, PB5
	//Habilitar interrupciones del timer1
	LDI		R16, (1 << TOIE1)
	STS		TIMSK1, R16

	CALL	SONAR_ALARMA

	RJMP	MAIN
//--------------------------------------------------------------------------------------------------------------
CONF_MIN:
	//Parar interrupción del timer1
	CLR		R16
	STS		TIMSK1, R16

	LDI		ACTION_DIS, 0x01	// Bandera para mostrar la hora en displays
	CBI		PORTB, PB3			// LEDS que muestran el modo 010
	SBI		PORTB, PB4
	CBI		PORTB, PB5

    CPI     ACTION, 0x01       // Compara ACTION con 0x01
    BREQ    DO_SUMA            // Si ACTION == 0x01, salta a DO_SUMA
    CPI     ACTION, 0x02       // Compara ACTION con 0x02
    BREQ    DO_RESTA           // Si ACTION == 0x02, salta a DO_RESTA
    CLR     ACTION             // Limpia ACTION para que no entre en un bucle
    RJMP    MAIN               // Vuelve al inicio del bucle

DO_SUMA:
    CALL    SUMA_MIN           // Llama a la subrutina SUMA
    CLR     ACTION             // Limpia ACTION después de la operación
    RJMP    MAIN               // Vuelve al inicio del bucle

DO_RESTA:
    CALL    RESTA_MIN          // Llama a la subrutina RESTA
    CLR     ACTION             // Limpia ACTION después de la operación
    RJMP    MAIN               // Vuelve al inicio del bucle
//-----------------------------------------------------------------------------------------------------------
CONF_HORA:
	//Parar interrupción del timer1
	CLR		R16
	STS		TIMSK1, R16

	LDI		ACTION_DIS, 0x01
	SBI		PORTB, PB3			// LEDS que muestran el modo 011
	SBI		PORTB, PB4
	CBI		PORTB, PB5
	
	CPI     ACTION, 0x01       // Compara ACTION con 0x01
    BREQ    DO_SUMA_HORA       // Si ACTION == 0x01, salta a DO_SUMA_HORA
    CPI     ACTION, 0x02       // Compara ACTION con 0x02
    BREQ    DO_RESTA_HORA      // Si ACTION == 0x02, salta a DO_RESTA_HORA
    CLR     ACTION             // Limpia ACTION 
    RJMP    MAIN               // Vuelve al inicio del bucle

DO_SUMA_HORA:
    CALL    SUMA_HORA          // Llama a la subrutina SUMA_HORA
    CLR     ACTION             // Limpia ACTION después de la operación
    RJMP    MAIN               // Vuelve al inicio del bucle

DO_RESTA_HORA:
    CALL    RESTA_HORA         // Llama a la subrutina RESTA
    CLR     ACTION             // Limpia ACTION después de la operación
    RJMP    MAIN               // Vuelve al inicio del bucle
//-------------------------------------------------------------------------------------------------------------
CONF_DIA:
	LDI		ACTION_DIS, 0x02	// Bandera para mostrar la fecha en displays
	CBI		PORTB, PB3			// LEDS que muestran el modo 100
	CBI		PORTB, PB4
	SBI		PORTB, PB5

	//Parar interrupción del timer1
	CLR		R16
	STS		TIMSK1, R16			// Para esto limpio la mascara el cual habilita interrupciones
	
	CPI     ACTION, 0x01       // Compara ACTION con 0x01
    BREQ    DO_SUMA_DIA        // Si ACTION == 0x01, salta a DO_SUMA_DIA
    CPI     ACTION, 0x02       // Compara ACTION con 0x02
    BREQ    DO_RESTA_DIA       // Si ACTION == 0x02, salta a DO_RESTA_DIA
    CLR     ACTION             // Limpia ACTION 
    RJMP    MAIN               // Vuelve al inicio del bucle

DO_SUMA_DIA:
    CALL    SUMA_DIA           // Llama a la subrutina SUMA_DIA
    CLR     ACTION             // Limpia ACTION después de la operación
    RJMP    MAIN               // Vuelve al inicio del bucle

DO_RESTA_DIA:
    CALL    RESTA_DIA          // Llama a la subrutina RESTA_DIA
    CLR     ACTION             // Limpia ACTION después de la operación
    RJMP    MAIN               // Vuelve al inicio del bucle

//--------------------------------------------------------------------------------------------------------------
CONF_MES:
	LDI		ACTION_DIS, 0x02	// Bandera para mostrar la fecha en displays
	SBI		PORTB, PB3			// LEDS que muestran el modo 101
	CBI		PORTB, PB4
	SBI		PORTB, PB5

	//Parar interrupción del timer1
	CLR		R16
	STS		TIMSK1, R16
	
	CPI     ACTION, 0x01       // Compara ACTION con 0x01
    BREQ    DO_SUMA_MES        // Si ACTION == 0x01, salta a DO_SUMA_MES
    CPI     ACTION, 0x02       // Compara ACTION con 0x02
    BREQ    DO_RESTA_MES       // Si ACTION == 0x02, salta a DO_RESTA_MES
    CLR     ACTION             // Limpia ACTION 
    RJMP    MAIN               // Vuelve al inicio del bucle

DO_SUMA_MES:
    CALL    SUMA_MES           // Llama a la subrutina SUMA_MES
    CLR     ACTION             // Limpia ACTION después de la operación
    RJMP    MAIN               // Vuelve al inicio del bucle

DO_RESTA_MES:
    CALL    RESTA_MES          // Llama a la subrutina RESTA_MES
    CLR     ACTION             // Limpia ACTION después de la operación
    RJMP    MAIN               // Vuelve al inicio del bucle
//-------------------------------------------------------------------------------------------------------------------
CONF_ALARMA_MIN:
	LDI		ACTION_DIS, 0x03	// Bandera para mostrar la alarma en displays
	CBI		PORTB, PB3			// LEDS que muestran el modo 110
	SBI		PORTB, PB4
	SBI		PORTB, PB5


	//Parar interrupción del timer1
	CLR		R16
	STS		TIMSK1, R16

    CPI     ACTION, 0x01       // Compara ACTION con 0x01
    BREQ    DO_SUMA_MIN_ALARMA // Si ACTION == 0x01, salta a DO_SUMA_MIN_ALARMA
    CPI     ACTION, 0x02       // Compara ACTION con 0x02
    BREQ    DO_RESTA_MIN_ALARMA// Si ACTION == 0x02, salta a DO_RESTA_MIN_ALARMA
    CLR     ACTION             // Limpia ACTION 
    RJMP    MAIN               // Vuelve al inicio del bucle

DO_SUMA_MIN_ALARMA:
    CALL    SUMA_MIN_ALARMA    // Llama a la subrutina SUMA_MIN_ALARMA
    CLR     ACTION             // Limpia ACTION después de la operación
    RJMP    MAIN               // Vuelve al inicio del bucle

DO_RESTA_MIN_ALARMA:
    CALL    RESTA_MIN_ALARMA   // Llama a la subrutina RESTA_MIN_ALARMA
    CLR     ACTION             // Limpia ACTION después de la operación
    RJMP    MAIN               // Vuelve al inicio del bucle

//-------------------------------------------------------------------------------------------------------------------
CONF_ALARMA_HORA:
	LDI		ACTION_DIS, 0x03	// Bandera para mostrar la alarma en displays
	SBI		PORTB, PB3			// LEDS que muestran el modo 111
	SBI		PORTB, PB4
	SBI		PORTB, PB5

	//Parar interrupción del timer1
	CLR		R16
	STS		TIMSK1, R16

    CPI     ACTION, 0x01       // Compara ACTION con 0x01
    BREQ    DO_SUMA_HORA_ALARMA// Si ACTION == 0x01, salta a DO_SUMA_HORA_ALARMA
    CPI     ACTION, 0x02       // Compara ACTION con 0x02
    BREQ    DO_RESTA_HORA_ALARMA// Si ACTION == 0x02, salta a DO_RESTA_HORA_ALARMA
    CLR     ACTION             // Limpia ACTION 
    RJMP    MAIN               // Vuelve al inicio del bucle

DO_SUMA_HORA_ALARMA:
    CALL    SUMA_HORA_ALARMA   // Llama a la subrutina SUMA_HORA_ALARMA
    CLR     ACTION             // Limpia ACTION después de la operación
    RJMP    MAIN               // Vuelve al inicio del bucle

DO_RESTA_HORA_ALARMA:
    CALL    RESTA_HORA_ALARMA  // Llama a la subrutina RESTA_HORA_ALARMA
    CLR     ACTION             // Limpia ACTION después de la operación
    RJMP    MAIN               // Vuelve al inicio del bucle

//---------------------------------------------------------------------------------------------------------------------
ON_OFF:
	LDI		ACTION_DIS, 0x04	// Bandera para mostrar la alarma en displays
	
	//Parar interrupción del timer1
	CLR		R16
	STS		TIMSK1, R16

    CPI     ACTION, 0x01       // Compara ACTION con 0x01
    BREQ    DO_ON				// Si ACTION == 0x01, salta a DO_ON
    CPI     ACTION, 0x02       // Compara ACTION con 0x02
    BREQ    DO_OFF				// Si ACTION == 0x02, salta a DO_OFF
    CLR     ACTION             // Limpia ACTION 
    RJMP    MAIN               // Vuelve al inicio del bucle

DO_ON:
	LDI		R19, 0x01			//Activo la bandera de acción para que suene la alarma
	CLR		R15					// Coloco el valor correspondiente para que su muestre "nada"
	LDI		R17, 0x02			// Coloco el valor correspondiente para que se muestre "N"
	LDI		R18, 0x01			// Coloco el valor correspondiente para que se muestre "O"
    CALL    SONAR_ALARMA        // Llama a la subrutina SONAR_ALARMA
    CLR     ACTION             // Limpia ACTION después de la operación
    RJMP    MAIN               // Vuelve al inicio del bucle

DO_OFF:
	LDI		R19, 0x00			// DEsactivo la badera de acción para apagar la alarma
	LDI		R16, 0x03
	MOV		R15, R16			// Coloco el valor correspondiente para que su muestre "F"
	LDI		R17, 0x03			// Coloco el valor correspondiente para que se muestre "F"
	LDI		R18, 0x01			// Coloco el valor correspondiente para que se muestre "O"
    CALL    SONAR_ALARMA        // Llama a la subrutina SONAR_ALARMA
    CLR     ACTION             // Limpia ACTION después de la operación
    RJMP    MAIN               // Vuelve al inicio del bucle

//========================================================================== RUTINAS NO INTERRUPCIÓN ====================================================================================
SET_INICIO:
	LDI		ZL, LOW(DISPLAY_VAL <<1)	//Coloca el direccionador indirecto en la posición inicial
	LDI		ZH, HIGH(DISPLAY_VAL <<1)
	RET
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SUMA_MIN:
    // Incrementa las unidades de minutos (R3)
    MOV     R16, R3            // Carga R3 en R16
    INC     R16                // Incrementa R16
    CPI     R16, 10            // Compara R16 con 10
    BRNE    UPDATE_SUM_UNI_MIN // Si R16 no es igual a 10, salta a UPDATE_SUM_UNI_MIN

    // Si R16 == 10, reinicia las unidades de minutos e incrementa las decenas
    CLR     R16                // Reinicia R16 a 0
    MOV     R3, R16            // Guarda 0 en R3 (unidades de minutos)
    MOV     R16, R4            // Carga R4 en R16
    INC     R16                // Incrementa R16 (decenas de minutos)
    CPI     R16, 6             // Compara R16 con 6
    BRNE    UPDATE_SUM_DEC_MIN // Si R16 no es igual a 6, salta a UPDATE_SUM_DEC_MIN

    // Si R16 == 6, reinicia las decenas de minutos
    CLR     R16                // Reinicia R16 a 0
    MOV     R4, R16            // Guarda 0 en R4 (decenas de minutos)
    RET                        // Sale de la subrutina

UPDATE_SUM_UNI_MIN:
    // Actualiza las unidades de minutos
    MOV     R3, R16            // Guarda R16 en R3
    RET                        // Sale de la subrutina

UPDATE_SUM_DEC_MIN:
    // Actualiza las decenas de minutos
    MOV     R4, R16            // Guarda R16 en R4
    RET                        // Sale de la subrutina
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
RESTA_MIN:
    // Resta las unidades de minutos (R3)
    MOV     R16, R3            // Carga R3 en R16
    DEC     R16                // Decrementa R16
    CPI     R16, 0xFF          // Compara R16 tuvo overflow 
    BRNE    UPDATE_RES_UNI_MIN  // Si R16 no es igual al 0xFF, salta a UPDATE_RES_UNI_MIN

    // Si hizo overflow, ajusta las unidades a 9 y decrementa las decenas
    LDI     R16, 9             // Carga 9 en R16 (unidades de minutos)
    MOV     R3, R16            // Guarda 9 en R3
    MOV     R16, R4            // Carga R4 en R16
    DEC     R16                // Decrementa R16 (decenas de minutos)
    CPI     R16, 0xFF          // Compara R16 hizo overflow
    BRNE    UPDATE_RES_DEC_MIN  // Si R16 no es igual al 0xFF, salta a UPDATE_RES_DEC_MIN

    // Si hizo overflow, ajusta las decenas a 5 (para volver a 59)
    LDI     R16, 5             // Carga 5 en R16 (decenas de minutos)
    MOV     R4, R16            // Guarda 5 en R4
    RET                        // Sale de la subrutina

UPDATE_RES_UNI_MIN:
    // Actualiza las unidades de minutos
    MOV     R3, R16            // Guarda R16 en R3
    RET                        // Sale de la subrutina

UPDATE_RES_DEC_MIN:
    // Actualiza las decenas de minutos
    MOV     R4, R16            // Guarda R16 en R4
    RET                        // Sale de la subrutina
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SUMA_HORA:
	MOV		R16, R6				// Carga R6 a R16
	CPI		R16, 2				// Compara si la decena de hora es 2 para que las unidades no lleguen a 9
	BRNE	CONTINUAR_NORMAL_HORA // Si no es igual a 2 continuar normal (aumentar hasta 9 las unidades)

	MOV		R16, R5				// Carga el valor de R5 a R16
	INC		R16					// Incremento R16
	CPI		R16, 4				// Comparo si ya llegó a 4 (unidad de hora)
	BRNE	UPDATE_SUM_UNI_HORA	// Si no es igual a 4 saltar a UPDATE_SUM_UNI_HORA
	RJMP	RESET_HORAS			// Salta a RESET_HORAS

CONTINUAR_NORMAL_HORA:
    MOV     R16, R5            // Carga R5 en R16
    INC     R16                // Incrementa R16
    CPI     R16, 10            // Compara R16 con 10
    BRNE    UPDATE_SUM_UNI_HORA // Si R16 no es igual a 10, salta a UPDATE_SUM_UNI_HORA

    // Si R16 == 10, reinicia las unidades de minutos e incrementa las decenas
    CLR     R16                // Reinicia R16 a 0
    MOV     R5, R16            // Guarda 0 en R5 (unidades de hora)
    MOV     R16, R6            // Carga R6 en R16
    INC     R16                // Incrementa R16 (decenas de hora)
    CPI     R16, 6             // Compara R16 con 6
    BRNE    UPDATE_SUM_DEC_HORA // Si R16 no es igual a 6, salta a UPDATE_SUM_DEC_HORA

RESET_HORAS:
    // Si R16 == 6, reinicia las decenas de minutos
    CLR     R16                // Reinicia R16 a 0
    MOV     R6, R16            // Guarda 0 en R6 (decenas de minutos)
	MOV		R5, R16				// Guarda 0 en R5 (unidades de minutos)
    RET                        // Sale de la subrutina

UPDATE_SUM_UNI_HORA:
    // Actualiza las unidades de hora
    MOV     R5, R16            // Guarda R16 en R5
    RET                        // Sale de la subrutina

UPDATE_SUM_DEC_HORA:
    // Actualiza las decenas de hora
    MOV     R6 , R16           // Guarda R16 en R6
    RET                        // Sale de la subrutina

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
RESTA_HORA:
    // Resta las unidades de hora (R5)
    MOV     R16, R5            // Carga R5 en R16
    DEC     R16                // Decrementa R16
    CPI     R16, 0xFF          // Compara R16 con 0xFF (verifica si es overflow)
    BRNE    UPDATE_RES_UNI_HORA// Si R16 no hubo overflow, salta a UPDATE_RES_UNI_HORA

    ; Si R16 == 0xFF, ajusta las unidades a 9 y decrementa las decenas
    LDI     R16, 9             // Carga 9 en R16 (unidades de hora)
    MOV     R5, R16            // Guarda 9 en R5
    MOV     R16, R6           // Carga R6 en R16
    DEC     R16                // Decrementa R16 (decenas de hora)
    CPI     R16, 0xFF          // Compara R16 con 0xFF ( ver si hay overflow)
    BRNE    UPDATE_RES_DEC_HORA // Si R16 no es igual a 0xFF, salta a UPDATE_RES_DEC_HORA

RESET_HORA_DEC:
    // Si R16 == 0xFF, ajusta las decenas a 2 
    LDI     R16, 2             // Carga 2 en R16 
    MOV     R6, R16            // Guarda 5 en R6
	LDI		R16, 3				// Carga 3 en R16
	MOV		R5, R16				// Guarda 3 en R5
    RET                        // Sale de la subrutina

UPDATE_RES_UNI_HORA:
    // Actualiza las unidades de hora
    MOV     R5, R16            // Guarda R16 en R3
    RET                        // Sale de la subrutina

UPDATE_RES_DEC_HORA:
    ; Actualiza las decenas de hora
    MOV     R6, R16            // Guarda R16 en R4
    RET                        // Sale de la subrutina
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SUMA_DIA:
    // Calcular el día actual en formato decimal (R24 = R8 * 10 + R7)
    MOV     R24, R8		// Copia R8 para trabajar lbremente con R24
    MOV     R27, R24	// Copia R24 a R27 para tener dos registros con el mismo número 
    LSL     R24          // R24 = R8 * 2
    LSL     R27          // R27 = R8 * 2
    LSL     R27          // R27 = R8 * 4
    LSL     R27          // R27 = R8 * 8
    ADD     R24, R27     // R24 = (R8 * 2) + (R8 * 8) = R8 * 10
    ADD     R24, R7      // R24 = R8 * 10 + R7
	// De esta forma tengo el valor del mes en decimal para poder comparar

    // Obtener el número de días del mes actual (en decimal)
    LDI     ZL, LOW(TABLA_DIAS << 1)  // Cargar la dirección baja de la tabla
    LDI     ZH, HIGH(TABLA_DIAS << 1) // Cargar la dirección alta de la tabla
    MOV     R16, R25                  // Cargar el mes actual en R16
    DEC     R16                       // Ajustar el índice (R16 = R25 - 1) ya que por ejemplo enero es R25 = 1 pero el índice en la tabla es 0
    ADD     ZL, R16                   // Sumar el índice del mes a la dirección
    ADC     ZH, R1                    // Añadir el acarreo si es necesario
    LPM     R27, Z                    // Cargar el número de días del mes en R27 (decimal)

    // Comparar el día actual con el número máximo de días del mes
    CP      R24, R27                  // Comparar R24 con R27
    BRLO    CONTINUAR_SUMA_DIA        // Si R24 < R27, salta a CONTINUAR_SUMA_DIA

    // Si R24 >= R27, reiniciar el día a 1
    LDI     R16, 1                    // Cargar 1 en R16
    MOV     R7, R16                   // Guardar 1 en R7 (unidades del día)
    CLR     R8                        // Limpiar R8 (decenas del día)
    RET                               // Salir de la subrutina

CONTINUAR_SUMA_DIA:
    // Incrementar las unidades del día
    MOV     R16, R7                   // Cargar R7 en R16
    INC     R16                       // Incrementar R16
    CPI     R16, 10                   // Comparar R16 con 10
    BRNE    UPDATE_SUM_UNI_DIA        // Si no es 10, actualizar las unidades

    // Si las unidades son 10, reiniciar a 0 e incrementar las decenas
    CLR     R16                       // Limpiar R16
    MOV     R7, R16                   // Guardar 0 en R7 (unidades del día)
    INC     R8                        // Incrementar R8 (decenas del día)
    RET                               // Retornar de la subrutina

UPDATE_SUM_UNI_DIA:
    // Actualizar las unidades del día
    MOV     R7, R16                   // Guardar R16 en R7
    RET                               // Retornar de la subrutina


//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
RESTA_DIA:
    ; Calcular el día actual en formato decimal (R24 = R8 * 10 + R7)
    MOV     R24, R8
    MOV     R27, R24
    LSL     R24          ; R24 = R8 * 2
    LSL     R27          ; R27 = R8 * 2
    LSL     R27          ; R27 = R8 * 4
    LSL     R27          ; R27 = R8 * 8
    ADD     R24, R27     ; R24 = (R8 * 2) + (R8 * 8) = R8 * 10
    ADD     R24, R7      ; R24 = R8 * 10 + R7

    ; Obtener el número de días del mes actual (en decimal)
    LDI     ZL, LOW(TABLA_DIAS << 1)  ; Cargar la dirección baja de la tabla
    LDI     ZH, HIGH(TABLA_DIAS << 1) ; Cargar la dirección alta de la tabla
    MOV     R16, R25                  ; Cargar el mes actual en R16
    DEC     R16                       ; Ajustar el índice (R16 = R25 - 1)
    ADD     ZL, R16                   ; Sumar el índice del mes a la dirección
    ADC     ZH, R1                    ; Añadir el acarreo si es necesario
    LPM     R27, Z                    ; Cargar el número de días del mes en R27 (decimal)

    ; Verificar si el día actual es 1 (R7 = 1 y R8 = 0)
    MOV     R16, R7                   ; Cargar R7 en R16
    CPI     R16, 1                    ; Comparar R16 con 1
    BRNE    DECREMENTAR_NORMAL        ; Si R16 no es 1, decrementar normalmente
    MOV     R16, R8                   ; Cargar R8 en R16
    CPI     R16, 0                    ; Comparar R16 con 0
    BRNE    DECREMENTAR_NORMAL        ; Si R16 no es 0, decrementar normalmente

    ; Si el día actual es 1, ajustar al último día del mes actual (en decimal)
    MOV     R24, R27                  ; Cargar el número de días del mes en R24
    RJMP    CONVERTIR_A_BCD           ; Convertir a BCD y actualizar R7 y R8

DECREMENTAR_NORMAL:
    ; Decrementar las unidades del día
    MOV     R16, R7                   ; Cargar R7 en R16
    DEC     R16                       ; Decrementar R16
    MOV     R7, R16                   ; Guardar R16 en R7
    CPI     R16, 0xFF                 ; Verificar si R16 es -1 (0xFF)
    BRNE    EXIT_RESTA_DIA            ; Si no es -1, salir

    ; Si las unidades son -1, ajustar las decenas y las unidades
    MOV     R16, R8                   ; Cargar R8 en R16
    DEC     R16                       ; Decrementar R16
    MOV     R8, R16                   ; Guardar R16 en R8
    CPI     R16, 0xFF                 ; Verificar si R16 es -1 (0xFF)
    BRNE    AJUSTAR_DECENAS           ; Si no es -1, ajustar las decenas

    ; Si las decenas son -1, ajustar al último día del mes actual (en decimal)
    MOV     R24, R27                  ; Cargar el número de días del mes en R24
    RJMP    CONVERTIR_A_BCD           ; Convertir a BCD y actualizar R7 y R8

AJUSTAR_DECENAS:
    ; Ajustar las decenas
    LDI     R16, 9                    ; Cargar 9 en R16
    MOV     R7, R16                   ; Guardar R16 en R7
    RET                               ; Retornar de la subrutina

CONVERTIR_A_BCD:
    ; Convertir el valor decimal de la tabla a BCD
    MOV     R16, R24                  ; Cargar el número de días en R16
    CLR     R26                       ; Limpiar R17 para las decenas
CONVERTIR_LOOP:
    CPI     R16, 10                   ; Comparar con 10
    BRLO    CONVERSION_COMPLETA       ; Si es menor que 10, la conversión está completa
    INC     R26                       ; Incrementar las decenas
    SUBI    R16, 10                   ; Restar 10 a las unidades
    RJMP    CONVERTIR_LOOP            ; Repetir hasta que R16 < 10
CONVERSION_COMPLETA:
    ; R17 = decenas, R16 = unidades (en BCD)
    MOV     R7, R16                   ; Guardar las unidades del día en R7
    MOV     R8, R26                   ; Guardar las decenas del día en R8
    RET                               ; Retornar de la subrutina

EXIT_RESTA_DIA:
    RET                               ; Retornar de la subrutina

//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SUMA_MES:
	//Esta sección la realizo para tener en 1 los meses cuando se configuran
	LDI		R16, 0x01				// Cargar 1 en R16
	MOV		R7, R16					// Cargar R16 rn R7
	CLR		R8						// Limpiar R8

    MOV     R16, R10				// Cargar R10 a R16
    CPI     R16, 1					// Compara si R16 == 1 para saber si se puede aumentar a 9 unidades de mes o no
    BRNE    CONT_NORMAL_MES			// SI no es igual, saltar
    MOV     R16, R9					// Cargar R9 a R16
    INC     R16						// incrementar R16
    CPI     R16, 3					// Compara si R16 es igual a 3 esto para que no se pase de 12 meses
    BRNE    UPDATE_UNI_MES			// Si no es igual, salta
    RJMP    RESET_MES				// Saltar a reseteat mes

CONT_NORMAL_MES:
    MOV     R16, R9					// Cargar R9 a R16
    INC     R16						// Incrementar R16
    CPI     R16, 10					// Comparar si es igual a 10
    BRNE    UPDATE_UNI_MES			// Si no es igual, salta
    CLR     R16						// Limpiar R16

UPDATE_UNI_MES:
    MOV     R9, R16					// 
    CPI     R16, 0					// Compara si R16 es igual a 0, si se reseteo 
    BRNE    ACTUALIZAR_SUM_MES		// Si no es igual salta
    MOV     R16, R10
    INC     R16						// Incrementar R16
    CPI     R16, 2					// COmparar si llegó a 2, para no pasarse de 12 meses
    BRNE    UPDATE_DEC_MES	
    CLR     R16

// Actualizar valor de decenas de mes
UPDATE_DEC_MES:
    MOV     R10, R16
    RJMP    ACTUALIZAR_SUM_MES

//Resetear mes si se aumentó luego de estar en 12
RESET_MES:
    LDI     R16, 0x01
    MOV     R9, R16
    CLR     R16
    MOV     R10, R16

// Acualizar el mes (R25) para poder colocar correctamente el puntero 
ACTUALIZAR_SUM_MES:
    MOV     R16, R25
    INC     R16
    CPI     R16, 13
    BRNE    EXIT_SUM_MES
    LDI     R16, 0x01

EXIT_SUM_MES:
    MOV     R25, R16
    RET

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
RESTA_MES:
	LDI		R16, 0x01
	MOV		R7, R16
	CLR		R8

    // Decrementar el mes
    MOV     R16, R25                  // Cargar el mes actual en R16
    DEC     R16                       // Decrementar R16
    CPI     R16, 0                    // Verificar si el mes es 0
    BRNE    UPDATE_MES                // Si no es 0, actualizar el mes

    // Si el mes es 0, ajustar a 12
    LDI     R16, 12                   // Cargar 12 en R16
    MOV     R25, R16                  // Guardar 12 en R25 (mes actual)

UPDATE_MES:
    // Actualizar el mes
    MOV     R25, R16                  // Guardar R16 en R25

    // Convertir el mes a unidades (R9) y decenas (R10)
    CLR     R10                       // Limpiar R10 (decenas)
    CLR     R9                        // Limpiar R9 (unidades)

CONVERTIR_MES_A_BCD:

//BCD (Binary-Coded Decimal) almacena cada dígito de un número decimal en 4 bits.
//Por ejemplo:
//12 en decimal ? 0001 0010 en BCD (1 en las decenas, 2 en las unidades).
//9 en decimal ? 0000 1001 en BCD (0 en las decenas, 9 en las unidades).

    CPI     R16, 10                   // Comparar con 10
    BRLO    CONVERSION_COMPLETA_MES   // Si es menor que 10, la conversión está completa
    INC     R10                       // Incrementar las decenas
    SUBI    R16, 10                   // Restar 10 a las unidades
    RJMP    CONVERTIR_MES_A_BCD       // Repetir hasta que R16 < 10

CONVERSION_COMPLETA_MES:
    // Guardar las unidades en R9
    MOV     R9, R16                   // Guardar R16 en R9 (unidades)

    // Verificar si el mes es 12
    CPI     R25, 12                   // Comparar R25 con 12
    BRNE    EXIT_RESTA_MES            // Si no es 12, salir

    // Si el mes es 12, ajustar R10 y R9
    LDI     R16, 1                    // Cargar 1 en R16 (decenas)
    MOV     R10, R16                  // Guardar R16 en R10
    LDI     R16, 2                    // Cargar 2 en R16 (unidades)
    MOV     R9, R16                   // Guardar R16 en R9

EXIT_RESTA_MES:
    RET                               // Retornar de la subrutina

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SUMA_MIN_ALARMA:
	//Esta lógica es igual a la de configuración hora
    // Incrementa las unidades de minutos para la alarma (R11)
    MOV     R16, R11           // Carga R11 en R16
    INC     R16                // Incrementa R16
    CPI     R16, 10            // Compara R16 con 10
    BRNE    UPDATE_SUM_UNI_MIN_ALARMA // Si R16 no es igual a  10, salta a UPDATE_SUM_UNI_MIN_ALARMA

    // Si R16 == 10, reinicia las unidades de minutos e incrementa las decenas
    CLR     R16                // Reinicia R16 a 0
    MOV     R11, R16           // Guarda 0 en R11 (unidades de minutos)
    MOV     R16, R12           // Carga R12 en R16
    INC     R16                // Incrementa R16 (decenas de minutos)
    CPI     R16, 6             // Compara R16 con 6
    BRNE    UPDATE_SUM_DEC_MIN_ALARMA // Si R16 no es igual a 6, salta a UPDATE_SUM_DEC_MIN

    // Si R16 == 6, reinicia las decenas de minutos
    CLR     R16                // Reinicia R16 a 0
    MOV     R12, R16           // Guarda 0 en R12 (decenas de minutos)
    RET                        // Sale de la subrutina

UPDATE_SUM_UNI_MIN_ALARMA:
    // Actualiza las unidades de minutos
    MOV     R11, R16           // Guarda R16 en R11
    RET                        // Sale de la subrutina

UPDATE_SUM_DEC_MIN_ALARMA:
    // Actualiza las decenas de minutos
    MOV     R12, R16           // Guarda R16 en R12
    RET                        // Sale de la subrutina
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
RESTA_MIN_ALARMA:
	// Esta lógica es igual a la lógica de configuración hora resta
    // Resta las unidades de minutos 
    MOV     R16, R11           // Carga R11 en R16
    DEC     R16                // Decrementa R16
    CPI     R16, 0xFF          // Compara R16 con 0xFF para ver si hay overflow
    BRNE    UPDATE_RES_UNI_MIN_ALARMA  // Si R16 no hay overflow, salta a UPDATE_RES_UNI_MIN_ALARMA

    // Si R16 == overflow, ajusta las unidades a 9 y decrementa las decenas
    LDI     R16, 9             // Carga 9 en R16 (unidades de minutos)
    MOV     R11, R16           // Guarda 9 en R11
    MOV     R16, R12           // Carga R12 en R16
    DEC     R16                // Decrementa R16 (decenas de minutos)
    CPI     R16, 0xFF          // Compara R16 con 0xFF para saber si hubo overflow
    BRNE    UPDATE_RES_DEC_MIN_ALARMA  // Si R16 no es igual a 0xFF, salta a UPDATE_RES_DEC_MIN_ALARMA

    // Si R16 == 0xFF, ajusta las decenas a 5 (para volver a 59)
    LDI     R16, 5             // Carga 5 en R16 (decenas de minutos)
    MOV     R12, R16           // Guarda 5 en R12
    RET                        // Retorna de la subrutina

UPDATE_RES_UNI_MIN_ALARMA:
    // Actualiza las unidades de minutos
    MOV     R11, R16           // Guarda R16 en R11
    RET                        // Salir de la subrutina

UPDATE_RES_DEC_MIN_ALARMA:
    ; Actualiza las decenas de minutos
    MOV     R12, R16           // Guarda R16 en R12
    RET                        // Salir de la subrutina
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SUMA_HORA_ALARMA:
	// Esta lógica es la misma de configuración hora
    // Incrementa las unidades de hora 
	MOV		R16, R14			// Carga R14 a R16
	CPI		R16, 2				// Compara si es igual a 2 la decena de hora para saber hasta donde contar las unidades
	BRNE	CONTINUAR_NORMAL_HORA_ALARMA	// Si no es igual a 2 saltar 

	MOV		R16, R13			// Carga R13 a R16
	INC		R16					// Incrementar R16
	CPI		R16, 4				// Comparar con 4
	BRNE	UPDATE_SUM_UNI_HORA_ALARMA	// Si no es igual a 4 saltar
	RJMP	RESET_HORAS_ALARMA	// Saltar a resetar horas alarma

CONTINUAR_NORMAL_HORA_ALARMA:
    MOV     R16, R13           // Carga R13 en R16
    INC     R16                // Incrementa R16
    CPI     R16, 10            // Compara R16 con 10
    BRNE    UPDATE_SUM_UNI_HORA_ALARMA // Si R16 no es igual a 10 saltar

    // Si R16 == 10, reinicia las unidades de hora e incrementa las decenas
    CLR     R16                // Reinicia R16 a 0
    MOV     R13, R16           // Guarda 0 en R13 
    MOV     R16, R14           // Carga R14 en R16
    INC     R16                // Incrementa R16 
    CPI     R16, 6             // Compara R16 con 6
    BRNE    UPDATE_SUM_DEC_HORA_ALARMA // Si R16 no es igual a 6 saltar

RESET_HORAS_ALARMA:
    // Si R16 == 6, reinicia las decenas de hora
    CLR     R16                // Reinicia R16 a 0
    MOV     R14, R16           // Guarda 0 en R14 
	MOV		R13, R16			// Guarda 0 en R13
    RET                        // Salir de la subrutina

UPDATE_SUM_UNI_HORA_ALARMA:
    // Actualiza las unidades de hora
    MOV     R13, R16            // Guarda R16 en R13
    RET                        // Salir de la subrutina

UPDATE_SUM_DEC_HORA_ALARMA:
    // Actualiza las decenas de hora
    MOV     R14 , R16           // Guarda R16 en R4
    RET                        // Retorna de la subrutina
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
RESTA_HORA_ALARMA:
	// Esta lógica es igual a la lógica de configuración hora
    // Resta las unidades de minutos 
    MOV     R16, R13           // Carga R13 en R16
    DEC     R16                // Decrementa R16
    CPI     R16, 0xFF          // Compara R16 con 0xFF
    BRNE    UPDATE_RES_UNI_HORA_ALARMA  // Si R16 no es 0xFF, salta 

    // Si R16 == 0xFF, ajusta las unidades a 9 y decrementa las decenas
    LDI     R16, 9             // Carga 9 en R16 
    MOV     R13, R16           // Guarda 9 en R13
    MOV     R16, R14           // Carga R14 en R16
    DEC     R16                // Decrementa R16 
    CPI     R16, 0xFF          // Compara R16 con 0xFF
    BRNE    UPDATE_RES_DEC_HORA_ALARMA  // Si R16 0xFF, salta 

RESET_HORA_DEC_ALARMA:
    // Si R16 == 0xFF, ajusta las decenas a 2
    LDI     R16, 2             // Carga 2 en R16
    MOV     R14, R16           // Guarda 2 en R14
	LDI		R16, 3
	MOV		R13, R16
    RET                        // Salir de la subrutina

UPDATE_RES_UNI_HORA_ALARMA:
    // Actualiza las unidades de hora
    MOV     R13, R16           // Guarda R16 en R13
    RET                        // Salir de la subrutina

UPDATE_RES_DEC_HORA_ALARMA:
    // Actualiza las decenas de hora
    MOV     R14, R16            // Guarda R16 en R4
    RET                        // Salir de la subrutina
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SONAR_ALARMA:
	CPI		R19, 0x01			// Comparo si la bandera de acción para la alarma esta en 1 indicando que está encendida 
	BRNE	NO_SONAR			// Si no está en 1 saltar
	CP		R3, R11				// Compara si unidad minuto de alarma = unidad minuto de hora
	BRNE	NO_SONAR			// Si no es igual no sonar
	CP		R4, R12				// Compara si decena minuto de alarma = decena minuto de hora
	BRNE	NO_SONAR			// Si no es igual no sonar
	CP		R5, R13				// Compara si unidad hora de alarma = unidad hora de hora
	BRNE	NO_SONAR			// Si no es igual no sonar
	CP		R6, R14				// Compara si decena hora de alarma = decena hora de hora
	BRNE	NO_SONAR			// Si no es igual no sonar
	SBI		PORTC, PC4			// Activar pin donde está el buzzer
	RJMP	EXIT_ALARMA			
NO_SONAR:
	CBI		PORTC, PC4			// Apaga el pin donde se encuentra el buzzer
EXIT_ALARMA:
	RET							// Salir de la subrutina
//================================================== RUTINAS DE INTERRUPCIÓN =====================================================================
ISR_BOTON:						// Rutina de interrupción de los botones
    PUSH	R16
    IN		R16, SREG
    PUSH	R16

	SBIS	PINB, PB2			// Verifica si se presionó el botón de modo
	INC		MODO				// Incrementa el modo
	LDI		R16, MODO_CANT		// Carga la cantidad de modo a R16
	CP		MODO, R16			// Verifica si ya se sobrepasó la cantidad de modos
	BRNE	CONTINUAR_BOTON		// Saltar si no es igual
	CLR		MODO				// Si es igual, limpiar modo

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
	SBIS	PINB, PB1			// Verifica si se presionó el botón 2 en PB1
	LDI		ACTION, 0x01		// Si se presionó, coloca en 1 la bandera de acción
	SBIS	PINB, PB0			// Verifica si se presionó el botón 1 en PB0
	LDI		ACTION, 0x02		// Si se preionó, coloca en 2 la bandera de acción
	RJMP	EXIT_MODO_ISR		// Sale de la rutina de interrupción

	// Este proceso se repite en cada modo de configuración

MODO3_ISR:

	SBIS	PINB, PB1
	LDI		ACTION, 0x01
	SBIS	PINB, PB0
	LDI		ACTION, 0x02
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
	SBIS	PINB, PB1
	LDI		ACTION, 0x01
	SBIS	PINB, PB0
	LDI		ACTION, 0x02
	RJMP	EXIT_MODO_ISR
MODO7_ISR:
	SBIS	PINB, PB1
	LDI		ACTION, 0x01
	SBIS	PINB, PB0
	LDI		ACTION, 0x02
	RJMP	EXIT_MODO_ISR
MODO8_ISR:
	SBIS	PINB, PB1
	LDI		ACTION, 0x01
	SBIS	PINB, PB0
	LDI		ACTION, 0x02
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

	INC		R2					// Incrementar registro
	MOV		R16, R2				// Cargar R2 a R16
	CPI		R16, 0x01			// Verificar si es 1
	BREQ	DISPLAY1			// Si es igual a 1, saltar a activar y mostrar display 1
	CPI		R16, 0x02			// Verificar si es 2
	BREQ	DISPLAY2			// Si es igual a 2, saltar a activar y mostrar display 2
	CPI		R16, 0x03			// Verificar si es 3
	BREQ	DISPLAY3_RJMP		// Si es igual a 3, saltar a activar y mostrar display 3
	CPI		R16, 0x04			// Verificar si es 4
	BREQ	DISPLAY4_RJMP		// Si es igual a 4, saltar a activar y mostrar display 4

//Esto lo hago para evitar el error de out of range 
DISPLAY3_RJMP:
	RJMP	DISPLAY3
DISPLAY4_RJMP:
	RJMP	DISPLAY4
//++++++++++++++++++++++++++++++++
DISPLAY1:
	CBI		PORTC, PC0			// Desactivar el transistor de display 4
	CBI		PORTC, PC1			// Desactivar el transistor de display 3
	CBI		PORTC, PC2			// Desactivar el transistor de display 2

	OUT		PORTD, R1			// Apagar todo PORTD
//Verificar el modo actual para mostrar hora o fecha
	CPI		ACTION_DIS, 0x01	// Compara si ACTION_DIS es igual a 1 
	BREQ	DISPLAY1_HORA		// Si es igual, saltar 
	CPI		ACTION_DIS, 0x02	// Compara si ACTION_DIS es igual a 2
	BREQ	DISPLAY1_FECHA		// Si es igual, saltar 
	CPI		ACTION_DIS, 0x03	// Compara si ACTION_DIS es igual a 3
	BREQ	DISPLAY1_ALARMA		// Si es igual, saltar 
	CPI		ACTION_DIS, 0x04	// Compara si ACTION_DIS es igual a 4
	BREQ	DISPLAY1_ALARMA_ON_OFF // Si es igual, saltar 
DISPLAY1_HORA:
	MOV		R16, R3				// Mostrar unidad de hora
	RJMP	FLUJO_DISPLAY1		// Continuar con el flujo para mostrar valor
DISPLAY1_FECHA:
	MOV		R16, R7				// Mostrar unidad fecha
	RJMP	FLUJO_DISPLAY1		// Continuar con el flujo para mostrar valor
DISPLAY1_ALARMA:
	MOV		R16, R11			// Mostrar unidad hora alarma

	//FLUJO_DISPLAY es modular y así trabajar con R16 y el valor que se le cargó previamente
FLUJO_DISPLAY1:
	LDI		ZL, LOW(DISPLAY_VAL <<1)	//Coloca el direccionador indirecto en la posición inicial
	LDI		ZH, HIGH(DISPLAY_VAL <<1)
	ADD		ZL, R16						// Coloca el puntero en el valor deseado 
	ADC		ZH, R1						// Añade el acarreo para ajustar correctamente la dirección
	LPM		R16, Z						// Carga el valor del punteo a R16
	SBI		PORTC, PC3					// Activa el transistor del display 1
	OUT		PORTD, R16					// Muestra el valor en PORTD
	RJMP	FIN_TMR0	
DISPLAY1_ALARMA_ON_OFF:					// Se ejecuta para mostrar las letras de ON/OFF
	MOV		R16, R15					// Carga el valor de la primera letra a R16
	LDI		ZL, LOW(ALARMA_LETRA <<1)	//Coloca el direccionador indirecto en la posición inicial
	LDI		ZH, HIGH(ALARMA_LETRA <<1)
	ADD		ZL, R16						// Coloca el puntero en el valor actual
	ADC		ZH, R1						// Añade el acarreo apra ajustar correctamente la dirección
	LPM		R16, Z						// Carga el valor del puntero a R16
	SBI		PORTC, PC3					// Activa el transistor del display 1
	OUT		PORTD, R16					// Activa el transistor del display 1
	RJMP	FIN_TMR0

	//El código se repite, lo único que cambia son los transistores que se encienden y el valor que se muestra
	//como es modular es la misma lógica para cada display 

//+++++++++++++++++++++++++++++++++++++++++++++++++++
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
	CPI		ACTION_DIS, 0x03
	BREQ	DISPLAY2_ALARMA
	CPI		ACTION_DIS, 0x04
	BREQ	DISPLAY2_ALARMA_ON_OFF
DISPLAY2_HORA:
	MOV		R16, R4
	RJMP	FLUJO_DISPLAY2
DISPLAY2_FECHA:
	MOV		R16, R8
	RJMP	FLUJO_DISPLAY2
DISPLAY2_ALARMA:
	MOV		R16, R12

FLUJO_DISPLAY2:
	LDI		ZL, LOW(DISPLAY_VAL <<1)	//Coloca el direccionador indirecto en la posición inicial
	LDI		ZH, HIGH(DISPLAY_VAL <<1)
	ADD		ZL, R16
	ADC		ZH, R1
	LPM		R16, Z
	SBI		PORTC, PC2
	OUT		PORTD, R16

	RJMP	FIN_TMR0
DISPLAY2_ALARMA_ON_OFF:
	MOV		R16, R17
	LDI		ZL, LOW(ALARMA_LETRA <<1)	//Coloca el direccionador indirecto en la posición inicial
	LDI		ZH, HIGH(ALARMA_LETRA <<1)
	ADD		ZL, R16
	ADC		ZH, R1
	LPM		R16, Z
	SBI		PORTC, PC2
	OUT		PORTD, R16
	RJMP	FIN_TMR0
//+++++++++++++++++++++++++++++++++++++++++++++++
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
	CPI		ACTION_DIS, 0x03
	BREQ	DISPLAY3_ALARMA
	CPI		ACTION_DIS, 0x04
	BREQ	DISPLAY3_ALARMA_ON_OFF
DISPLAY3_HORA:
	MOV		R16, R5
	RJMP	FLUJO_DISPLAY3
DISPLAY3_FECHA:
	MOV		R16, R9
	RJMP	FLUJO_DISPLAY3
DISPLAY3_ALARMA:
	MOV		R16, R13

FLUJO_DISPLAY3:
    LDI     ZL, LOW(DISPLAY_VAL <<1)
    LDI     ZH, HIGH(DISPLAY_VAL <<1)
    ADD     ZL, R16
    ADC     ZH, R1
    LPM     R16, Z
	SBI     PORTC, PC1
    OUT     PORTD, R16
    RJMP    FIN_TMR0

DISPLAY3_ALARMA_ON_OFF:
	MOV		R16, R18
	LDI		ZL, LOW(ALARMA_LETRA <<1)	//Coloca el direccionador indirecto en la posición inicial
	LDI		ZH, HIGH(ALARMA_LETRA <<1)
	ADD		ZL, R16
	ADC		ZH, R1
	LPM		R16, Z
	SBI		PORTC, PC1
	OUT		PORTD, R16
	RJMP	FIN_TMR0
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
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
	CPI		ACTION_DIS, 0x03
	BREQ	DISPLAY4_ALARMA
	CPI		ACTION_DIS, 0x04
	BREQ	DISPLAY4_ALARMA_ON_OFF
DISPLAY4_HORA:
	MOV		R16, R6
	RJMP	FLUJO_DISPLAY4
DISPLAY4_FECHA:
	MOV		R16, R10
	RJMP	FLUJO_DISPLAY4
DISPLAY4_ALARMA:
	MOV		R16, R14

FLUJO_DISPLAY4:
    LDI     ZL, LOW(DISPLAY_VAL <<1)
    LDI     ZH, HIGH(DISPLAY_VAL <<1)
    ADD     ZL, R16
    ADC     ZH, R1
    LPM     R16, Z
	SBI     PORTC, PC0
    OUT     PORTD, R16

    RJMP    FIN_TMR0
DISPLAY4_ALARMA_ON_OFF:
	MOV		R16, R1
	LDI		ZL, LOW(ALARMA_LETRA <<1)	//Coloca el direccionador indirecto en la posición inicial
	LDI		ZH, HIGH(ALARMA_LETRA <<1)
	ADD		ZL, R16
	ADC		ZH, R1
	LPM		R16, Z
	SBI		PORTC, PC0
	OUT		PORTD, R16
	RJMP	FIN_TMR0
//++++++++++++++++++++++++++++++++++++++++++++++++++++
FIN_TMR0:
	MOV		R16, R2				// Carga R2 a R16
	CPI		R16, 0x04			// Compara si es igual a 4
	BRNE	RESET_END_ISR		// Si no es igual, saltar
	CLR		R16					// Si es igual a 4 limpiar registro y así se reinicia contador R2
	MOV		R2, R16

RESET_END_ISR:					// Finalizar rutina
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

//#######################################################################################################################
// La lógica de la interrupción es igual a las subrutinas del MAIN solo que estan anidadas para poder realizar la lógica
//#######################################################################################################################

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
    BRNE    SALIR_ISR_1	   // Salir de la interrupción
	RJMP	CONTINUAR_UNI_MIN
SALIR_ISR_1:
	RJMP	EXIT_TMR1_ISR
CONTINUAR_UNI_MIN:
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
    BRNE    SALIR_ISR_2		// Salir de la interrupción
	RJMP	CONTINUAR_DEC_MIN
SALIR_ISR_2:
	RJMP	EXIT_TMR1_ISR
CONTINUAR_DEC_MIN:
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
    BRNE    SALIR_ISR_3
	RJMP	CONTINUAR_UNI_HORA
SALIR_ISR_3:
	RJMP	EXIT_TMR1_ISR
CONTINUAR_UNI_HORA:
   // Incrementar horas (decenas)
	MOV     R16, R6            // Mover decenas de horas a R16
	CPI		R16, 2				// Comparar si es igual a 2
	BRNE	CONTINUAR_DEC_HORA	// Si no es igual ir a actualizar decena hora

RESET_TOTAL:
	CLR		R6					// Reiniciar R6 (decena hora)
	CLR		R5					// Reiniciar R5 (unidad hora)
	CLR		R16					// Reiniciar registro de propósito general
	RJMP	NUEVO_DIA		// Salir de la interrupción

CONTINUAR_DEC_HORA:
	INC		R16					// Incrementar R16
	MOV		R6, R16				
	RJMP	EXIT_TMR1_ISR

NUEVO_DIA:
    ; Calcular el día actual en formato decimal (R24 = R8 * 10 + R7)
    MOV     R24, R8
    MOV     R27, R24
    LSL     R24          // R24 = R8 * 2
    LSL     R27          // R27 = R8 * 2
    LSL     R27          // R27 = R8 * 4
    LSL     R27          // R27 = R8 * 8
    ADD     R24, R27     // R24 = (R8 * 2) + (R8 * 8) = R8 * 10
    ADD     R24, R7      // R24 = R8 * 10 + R7

    ; Obtener el número de días del mes actual (en decimal)
    LDI     ZL, LOW(TABLA_DIAS << 1)  // Cargar la dirección baja de la tabla
    LDI     ZH, HIGH(TABLA_DIAS << 1) // Cargar la dirección alta de la tabla
    MOV     R16, R25                  // Cargar el mes actual en R16
    DEC     R16                       // Ajustar el índice (R16 = R25 - 1)
    ADD     ZL, R16                   // Sumar el índice del mes a la dirección
    ADC     ZH, R1                    // Añadir el acarreo si es necesario
    LPM     R27, Z                    // Cargar el número de días del mes en R27 (decimal)

    // Comparar el día actual con el número máximo de días del mes
    CP      R24, R27                
    BRLO    CONTINUAR_SUMA_DIA_ISR   

    // Si R24 >= R27, reiniciar el día a 1 y sumar un mes
    LDI     R16, 1                  
    MOV     R7, R16                
    CLR     R8                       

    // Verificar si el mes es 12 (diciembre)
    MOV     R16, R25             
    CPI     R16, 12                 
    BRNE    SUMA_MES_ISR          

    // Si el mes es 12, reiniciar a 1 de enero
    LDI     R16, 1                  
    MOV     R25, R16                  
    MOV     R9, R16                   
    CLR     R10                       
    RJMP    EXIT_TMR1_ISR             

SUMA_MES_ISR:
    LDI     R16, 0x01
    MOV     R7, R16
    CLR     R8

    MOV     R16, R10
    CPI     R16, 1
    BRNE    CONT_NORMAL_MES_ISR
    MOV     R16, R9
    INC     R16
    CPI     R16, 3
    BRNE    UPDATE_UNI_MES_ISR
    RJMP    RESET_MES_ISR

CONT_NORMAL_MES_ISR:
    MOV     R16, R9
    INC     R16
    CPI     R16, 10
    BRNE    UPDATE_UNI_MES_ISR
    CLR     R16

UPDATE_UNI_MES_ISR:
    MOV     R9, R16
    CPI     R16, 0
    BRNE    ACTUALIZAR_SUM_MES_ISR
    MOV     R16, R10
    INC     R16
    CPI     R16, 2
    BRNE    UPDATE_DEC_MES_ISR
    CLR     R16

UPDATE_DEC_MES_ISR:
    MOV     R10, R16
    RJMP    ACTUALIZAR_SUM_MES_ISR

RESET_MES_ISR:
    LDI     R16, 0x01
    MOV     R9, R16
    CLR     R16
    MOV     R10, R16

ACTUALIZAR_SUM_MES_ISR:
    MOV     R16, R25
    INC     R16
    CPI     R16, 13
    BRNE    EXIT_SUM_MES_ISR
    LDI     R16, 0x01

EXIT_SUM_MES_ISR:
    MOV     R25, R16
    RJMP    EXIT_TMR1_ISR

CONTINUAR_SUMA_DIA_ISR:
    // Incrementar las unidades del día
    MOV     R16, R7                   // Cargar R7 en R16
    INC     R16                       // Incrementar R16
    CPI     R16, 10                   // Comparar R16 con 10
    BRNE    UPDATE_SUM_UNI_DIA_ISR	 // Si no es 10, actualizar las unidades

    // Si las unidades son 10, reiniciar a 0 e incrementar las decenas
    CLR     R16                       // Limpiar R16
    MOV     R7, R16                   // Guardar 0 en R7 (unidades del día)
    INC     R8                        // Incrementar R8 (decenas del día)
    RJMP    EXIT_TMR1_ISR            

UPDATE_SUM_UNI_DIA_ISR:
    // Actualizar las unidades del día
    MOV     R7, R16                   
    RJMP    EXIT_TMR1_ISR            

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
	LDI		R16, T2VALOR		// Cargar definido al inicio T2VALOR
	STS		TCNT2, R16			// Cargar valor inicial en TCNT2
	INC		CONTADOR			// Incrementa contador
	CPI		CONTADOR, 50		// Comparar si el contador llegó a 50
	BRNE	FIN_TMR2			// Si no es igual, finalizar interrupción
	SBI		PINC, PC5			// Hacer toggle para las leds de la hora
	CLR		CONTADOR			// Limpiar contador
FIN_TMR2:
	POP		R16
	OUT		SREG, R16
	POP		R16
	RETI
