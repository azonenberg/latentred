/***********************************************************************************************************************
*                                                                                                                      *
* LATENTRED                                                                                                            *
*                                                                                                                      *
* Copyright (c) 2023-2025 Andrew D. Zonenberg and contributors                                                         *
* All rights reserved.                                                                                                 *
*                                                                                                                      *
* Redistribution and use in source and binary forms, with or without modification, are permitted provided that the     *
* following conditions are met:                                                                                        *
*                                                                                                                      *
*    * Redistributions of source code must retain the above copyright notice, this list of conditions, and the         *
*      following disclaimer.                                                                                           *
*                                                                                                                      *
*    * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the       *
*      following disclaimer in the documentation and/or other materials provided with the distribution.                *
*                                                                                                                      *
*    * Neither the name of the author nor the names of any contributors may be used to endorse or promote products     *
*      derived from this software without specific prior written permission.                                           *
*                                                                                                                      *
* THIS SOFTWARE IS PROVIDED BY THE AUTHORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED   *
* TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL *
* THE AUTHORS BE HELD LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES        *
* (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR       *
* BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT *
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE       *
* POSSIBILITY OF SUCH DAMAGE.                                                                                          *
*                                                                                                                      *
***********************************************************************************************************************/

#include "latentred.h"

typedef void(*fnptr)();

extern uint32_t __stack;
extern uint32_t __bss_start__;
extern uint32_t __bss_end__;

//prototypes
extern "C" void _start();
void MMUFault_Handler();
void UsageFault_Handler();
void BusFault_Handler();
void HardFault_Handler();
void NMI_Handler();

void defaultISR();

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Interrupt vector table

fnptr __attribute__((section(".vector"))) vectorTable[] =
{
	(fnptr)&__stack,		//stack
	_start,					//reset
	NMI_Handler,			//NMI
	HardFault_Handler,		//hardfault
	MMUFault_Handler,		//mmufault
	BusFault_Handler,		//busfault
	UsageFault_Handler,		//usagefault
	defaultISR,				//reserved_7
	defaultISR,				//reserved_8
	defaultISR,				//reserved_9
	defaultISR,				//reserved_10
	defaultISR,				//svcall
	defaultISR,				//debug
	defaultISR,				//reserved_13
	defaultISR,				//pend_sv
	defaultISR,				//systick
	defaultISR,				//irq0 WWDG
	defaultISR,				//irq1 PVD
	defaultISR,				//irq2 RTC_TAMP_STAMP_CSS_LSE
	defaultISR,				//irq3 RTC_WKUP
	defaultISR,				//irq4 FLASH
	defaultISR,				//irq5 RCC
	defaultISR,				//irq6 EXTI0
	defaultISR,				//irq7 EXTI1
	defaultISR,				//irq8 EXTI2
	defaultISR,				//irq9 EXTI3
	defaultISR,				//irq10 EXTI4
	defaultISR,				//irq11 DMA1_Stream0
	defaultISR,				//irq12 DMA1_Stream1
	defaultISR,				//irq13 DMA1_Stream2
	defaultISR,				//irq14 DMA1_Stream3
	defaultISR,				//irq15 DMA1_Stream4
	defaultISR,				//irq16 DMA1_Stream5
	defaultISR,				//irq17 DMA1_Stream6
	defaultISR,				//irq18 ADC
	defaultISR,				//irq19 FDCAN1_IT0
	defaultISR,				//irq20 FQuick AccessDCAN2_IT0
	defaultISR,				//irq21 FDCAN1_IT1
	defaultISR,				//irq22 FDCAN2_IT1
	defaultISR,				//irq23 EXTI9_5
	defaultISR,				//irq24 TIM1_BRK
	defaultISR,				//irq25 TIM1_UP
	defaultISR,				//irq26 TIM1_TRG_COM
	defaultISR,				//irq27 TIM1_CC
	defaultISR,				//irq28 TIM2
	defaultISR,				//irq29 TIM3
	defaultISR,				//irq30 TIM4
	defaultISR,				//irq31 I2C1_EV
	defaultISR,				//irq32 I2C1_ER
	defaultISR,				//irq33 I2C2_EV
	defaultISR,				//irq34 I2C2_ER
	defaultISR,				//irq35 SPI1
	defaultISR,				//irq36 SPI2
	defaultISR,				//irq37 USART1
	defaultISR,				//irq38 USART2
	defaultISR,				//irq39 USART3
	defaultISR,				//irq40 EXTI15_10
	defaultISR,				//irq41 RTC_Alarm
	defaultISR,				//irq42 reserved
	defaultISR,				//irq43 TIM8_BRK_TIM12
	defaultISR,				//irq44 TIM8_UP_TIM13
	defaultISR,				//irq45 TIM8_TRG_COM_TIM14
	defaultISR,				//irq46 TIM8_CC
	defaultISR,				//irq47 DMA1_Stream7
	defaultISR,				//irq48 FMC
	defaultISR,				//irq49 SDMMC1
	defaultISR,				//irq50 TIM5
	defaultISR,				//irq51 SPI3
	UART4_Handler,			//irq52 UART4
	defaultISR,				//irq53 UART5
	defaultISR,				//irq54 TIM6_DAC
	defaultISR,				//irq55 TIM7
	defaultISR,				//irq56 DMA2_Stream0
	defaultISR,				//irq57 DMA2_Stream1
	defaultISR,				//irq58 DMA2_Stream2
	defaultISR,				//irq59 DMA2_Stream3
	defaultISR,				//irq60 DMA2_Stream4
	defaultISR,				//irq61 ETH
	defaultISR,				//irq62 ETH_WKUP
	defaultISR,				//irq63 FDCAN_CAL
	defaultISR,				//irq64 reserved
	defaultISR,				//irq65 reserved
	defaultISR,				//irq66 reserved
	defaultISR,				//irq67 reserved
	defaultISR,				//irq68 DMA2_Stream5
	defaultISR,				//irq69 DMA2_Stream6
	defaultISR,				//irq70 DMA2_Stream7
	defaultISR,				//irq71 USART6
	defaultISR,				//irq72 I2C3_EV
	defaultISR,				//irq73 I2C3_ER
	defaultISR,				//irq74 OTG_HS_EP1_OUT
	defaultISR,				//irq75 OTG_HS_EP1_IN
	defaultISR,				//irq76 OTG_HS_WKUP
	defaultISR,				//irq77 OTG_HS
	defaultISR,				//irq78 DCMI_PSSI
	defaultISR,				//irq79 CRYP
	defaultISR,				//irq80 HASH_RNG
	defaultISR,				//irq81 FPU
	defaultISR,				//irq82 UART7
	defaultISR,				//irq83 UART8
	defaultISR,				//irq84 SPI4
	defaultISR,				//irq85 SPI5
	defaultISR,				//irq86 SPI6
	defaultISR,				//irq87 SAI1
	defaultISR,				//irq88 LTDC
	defaultISR,				//irq89 LTDC_ERR
	defaultISR,				//irq90 DMA2D
	defaultISR,				//irq91 reserved
	defaultISR,				//irq92 OCTOSPI1
	defaultISR,				//irq93 LPTIM1
	defaultISR,				//irq94 CEC
	defaultISR,				//irq95 I2C4_EV
	defaultISR,				//irq96 I2C4_ER
	defaultISR,				//irq97 SPDIF
	defaultISR,				//irq98 reserved
	defaultISR,				//irq99 reserved
	defaultISR,				//irq100 reserved
	defaultISR,				//irq101 reserved
	defaultISR,				//irq102 DMAMUX1_OV
	defaultISR,				//irq103 reserved
	defaultISR,				//irq104 reserved
	defaultISR,				//irq105 reserved
	defaultISR,				//irq106 reserved
	defaultISR,				//irq107 reserved
	defaultISR,				//irq108 reserved
	defaultISR,				//irq109 reserved
	defaultISR,				//irq110 DFSDM1_FLT0
	defaultISR,				//irq111 DFSDM1_FLT1
	defaultISR,				//irq112 DFSDM1_FLT2
	defaultISR,				//irq113 DFSDM1_FLT3
	defaultISR,				//irq114 reserved
	defaultISR,				//irq115 SWPMI1
	defaultISR,				//irq116 TIM15
	defaultISR,				//irq117 TIM16
	defaultISR,				//irq118 TIM17
	defaultISR,				//irq119 MDIOS_WKUP
	defaultISR,				//irq120 MDIOS
	defaultISR,				//irq121 reserved
	defaultISR,				//irq122 MDMA
	defaultISR,				//irq123 reserved
	defaultISR,				//irq124 SDMMC2
	defaultISR,				//irq125 HSEM0
	defaultISR,				//irq126 reserved
	defaultISR,				//irq127 ADC3
	defaultISR,				//irq128 DMAMUX2_OVR
	defaultISR,				//irq129 BDMA_CH0
	defaultISR,				//irq130 BDMA_CH1
	defaultISR,				//irq131 BDMA_CH2
	defaultISR,				//irq132 BDMA_CH3
	defaultISR,				//irq133 BDMA_CH4
	defaultISR,				//irq134 BDMA_CH5
	defaultISR,				//irq135 BDMA_CH6
	defaultISR,				//irq136 BDMA_CH7
	defaultISR,				//irq137 COMP
	defaultISR,				//irq138 LPTIM2
	defaultISR,				//irq139 LPTIM3
	defaultISR,				//irq140 LPTIM4
	defaultISR,				//irq141 LPTIM5
	defaultISR,				//irq142 LPUART
	defaultISR,				//irq143 reserved
	defaultISR,				//irq144 CRS
	defaultISR,				//irq145 ECC_DIAG_IT
	defaultISR,				//irq146 SAI4
	defaultISR,				//irq147 TEMP_IT
	defaultISR,				//irq148 reserved
	defaultISR,				//irq149 WKUP
	defaultISR,				//irq150 OCTOSPI2
	defaultISR,				//irq151 OTFDEC1
	defaultISR,				//irq152 OTFDEC2
	defaultISR,				//irq153 FMAC
	defaultISR,				//irq154 CORDIC
	defaultISR,				//irq155 UART9
	defaultISR,				//irq156 USART10
	defaultISR,				//irq157 I2C5_EV
	defaultISR,				//irq158 I2C5_ER
	defaultISR,				//irq159 FDCAN3_IT0
	defaultISR,				//irq160 FDCAN3_IT1
	defaultISR,				//irq161 TIM23
	defaultISR				//irq162 TIM24
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Firmware version string used for the bootloader

extern "C" const char
	__attribute__((section(".fwid")))
	__attribute__((used))
	g_firmwareID[] = "lcbringup-main";

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Stub for unused interrupts

void defaultISR()
{
	g_cliUART.BlockingFlush();
	g_cliUART.PrintString("Unused interrupt vector called\n");
	g_cliUART.BlockingFlush();

	while(1)
	{}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Exception vectors

void NMI_Handler()
{
	g_cliUART.BlockingFlush();
	g_cliUART.PrintString("NMI\n");
	g_cliUART.BlockingFlush();
	while(1)
	{}
}

void HardFault_Handler()
{
	g_cliUART.BlockingFlush();

	uint32_t* msp;
	asm volatile("mrs %[result], MSP" : [result]"=r"(msp));
	msp += 12;	//locals/alignment
	uint32_t r0 = msp[0];
	uint32_t r1 = msp[1];
	uint32_t r2 = msp[2];
	uint32_t r3 = msp[3];
	uint32_t r12 = msp[4];
	uint32_t lr = msp[5];
	uint32_t pc = msp[6];
	uint32_t xpsr = msp[7];

	g_cliUART.Printf("Hard fault\n");
	g_cliUART.Printf("    HFSR  = %08x\n", *(volatile uint32_t*)(0xe000ed2C));
	g_cliUART.Printf("    MMFAR = %08x\n", *(volatile uint32_t*)(0xe000ed34));
	g_cliUART.Printf("    BFAR  = %08x\n", *(volatile uint32_t*)(0xe000ed38));
	g_cliUART.Printf("    CFSR  = %08x\n", *(volatile uint32_t*)(0xe000ed28));
	g_cliUART.Printf("    UFSR  = %08x\n", *(volatile uint16_t*)(0xe000ed2a));
	g_cliUART.Printf("    DFSR  = %08x\n", *(volatile uint32_t*)(0xe000ed30));
	g_cliUART.Printf("    MSP   = %08x\n", msp);
	g_cliUART.BlockingFlush();
	g_cliUART.Printf("    r0    = %08x\n", r0);
	g_cliUART.Printf("    r1    = %08x\n", r1);
	g_cliUART.Printf("    r2    = %08x\n", r2);
	g_cliUART.Printf("    r3    = %08x\n", r3);
	g_cliUART.Printf("    r12   = %08x\n", r12);
	g_cliUART.Printf("    lr    = %08x\n", lr);
	g_cliUART.Printf("    pc    = %08x\n", pc);
	g_cliUART.Printf("    xpsr  = %08x\n", xpsr);

	g_cliUART.Printf("    Stack:\n");
	g_cliUART.BlockingFlush();
	for(int i=0; i<16; i++)
	{
		g_cliUART.Printf("        %08x\n", msp[i]);
		g_cliUART.BlockingFlush();
	}

	while(1)
	{}
}

void BusFault_Handler()
{
	g_cliUART.BlockingFlush();
	g_cliUART.PrintString("Bus fault\n");
	g_cliUART.BlockingFlush();

	while(1)
	{}
}

void UsageFault_Handler()
{
	g_cliUART.BlockingFlush();
	g_cliUART.PrintString("Usage fault\n");
	g_cliUART.BlockingFlush();

	while(1)
	{}
}

void MMUFault_Handler()
{
	g_cliUART.BlockingFlush();
	g_cliUART.PrintString("MMU fault\n");
	g_cliUART.BlockingFlush();

	while(1)
	{}
}
