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

	/* KU+ APB1 (1 kB blocks at c010_0000) */
	.sfr_kup_apb1  (NOLOAD):
	{
		. = ALIGN(1024);
		KEEP (*(.fkdevinfo))
		. = ALIGN(1024);
		KEEP (*(.fgpiob))
		. = ALIGN(1024);
		KEEP (*(.fcurve25519))
		. = ALIGN(1024);
		. += 1024;	/* QPLL SMPM DRP */
		. += 1024;	/* QPLL SFP DRP */
		. += 1024;	/* SMPM SERDES DRP 0 */
		. += 1024;	/* SMPM SERDES DRP 1 */
		. += 1024;	/* SMPM SERDES DRP 2 */
		. += 1024;	/* QPLL QSFP DRP */
		. += 1024;	/* QSFP SERDES DRP 0 */
		. += 1024;	/* QSFP SERDES DRP 1 */
		. += 1024;	/* QSFP SERDES DRP 2 */
		. += 1024;	/* QSFP SERDES DRP 3 */
		. = ALIGN(1024);
		KEEP (*(.fqspi))
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
