MEMORY
{
	FMC_ARTIX(RW):	ORIGIN = 0xc0000000, LENGTH = 1M

	FMC_KUP_APB1(RW):	ORIGIN = 0xc0100000, LENGTH = 64K
	FMC_KUP_APB2(RW):	ORIGIN = 0xc0110000, LENGTH = 64K
}

SECTIONS
{
	/* Stuff on the Artix */
	.sfr_artix  (NOLOAD):
	{
		. = ALIGN(1024);
		KEEP (*(.fgpioa))
		. = ALIGN(1024);
		KEEP (*(.fdevinfo))
		. = ALIGN(1024);
		KEEP (*(.fmdio))
		. = ALIGN(1024);
		KEEP (*(.fxadc))
	} > FMC_ARTIX

	/* KU+ APB1 (1 kB blocks) */
	.sfr_kup_apb1  (NOLOAD):
	{
		. = ALIGN(1024);
		KEEP (*(.fkdevinfo))
		. = ALIGN(1024);
		KEEP (*(.fgpiob))
		. = ALIGN(1024);
		KEEP (*(.fcurve25519))
	} > FMC_KUP_APB1

	/* KU+ APB2 (4 kB blocks) */
	.sfr_kup_apb2  (NOLOAD):
	{
		. = ALIGN(4096);
		KEEP (*(.fethrx))
		. = ALIGN(4096);
		KEEP (*(.fethtx))
	} > FMC_KUP_APB2
}
