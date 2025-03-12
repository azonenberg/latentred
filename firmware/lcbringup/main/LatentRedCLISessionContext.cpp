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
#include <algorithm>
#include "LatentRedCLISessionContext.h"
#include <ctype.h>
#include <bootloader/BootloaderAPI.h>
#include <cli/CommonCommands.h>
#include <fpga/AcceleratedCryptoEngine.h>

static const char* hostname_objid = "hostname";

//List of all valid commands
enum cmdid_t
{
	CMD_ADDRESS,
	CMD_ARP,
	CMD_AUTHORIZED,
	CMD_CACHE,
	//CMD_CLEAR,
	CMD_COMMIT,
	CMD_COMPACT,
	CMD_DETAIL,
	//CMD_DFU,
	//CMD_DHCP,
	CMD_EXIT,
	CMD_FINGERPRINT,
	CMD_FLASH,
	CMD_GATEWAY,
	CMD_HARDWARE,
	CMD_HOSTNAME,
	CMD_IP,
	CMD_KEY,
	CMD_KEYS,
	CMD_NO,
	CMD_NTP,
	CMD_RESCAN,
	CMD_RELOAD,
	CMD_ROLLBACK,
	CMD_ROUTE,
	CMD_SERVER,
	CMD_SHOW,
	CMD_SSH,
	CMD_SSH_ED25519,
	CMD_USERNAME,
	CMD_VERSION,
	CMD_ZEROIZE
};
/*
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// "flash"

static const clikeyword_t g_flashCommands[] =
{
	{"compact",		CMD_COMPACT,		nullptr,	"Force a compact operation on the key-value store, even if not full"},
	{nullptr,		INVALID_COMMAND,	nullptr,	nullptr}
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// "hostname"

static const clikeyword_t g_hostnameCommands[] =
{
	{"<string>",	FREEFORM_TOKEN,		nullptr,	"New host name"},
	{nullptr,		INVALID_COMMAND,	nullptr,	nullptr}
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// "ip"

static const clikeyword_t g_ipAddressCommands[] =
{
	//{"dhcp",		CMD_DHCP,			nullptr,				"Use DHCP for IP configuration"},
	{"<address>",	FREEFORM_TOKEN,		nullptr,				"New IPv4 address and subnet mask in x.x.x.x/yy format"},
	{nullptr,		INVALID_COMMAND,	nullptr,				nullptr}
};

static const clikeyword_t g_ipGatewayCommands[] =
{
	{"<address>",	FREEFORM_TOKEN,		nullptr,				"New IPv4 default gateway"},
	{nullptr,		INVALID_COMMAND,	nullptr,				nullptr}
};

static const clikeyword_t g_ipCommands[] =
{
	{"address",		CMD_ADDRESS,		g_ipAddressCommands,	"Set the IPv4 address of the device"},
	{"gateway",		CMD_GATEWAY,		g_ipGatewayCommands,	"Set the IPv4 default gateway of the device"},

	{nullptr,		INVALID_COMMAND,	nullptr,				nullptr}
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// "no"

static const clikeyword_t g_noSshKeyCommands[] =
{
	{"<slot>",			FREEFORM_TOKEN,			nullptr,					"Slot number of the authorized SSH key to delete"},
	{nullptr,			INVALID_COMMAND,		nullptr,					nullptr}
};

static const clikeyword_t g_noSshCommands[] =
{
	{"key",				CMD_KEY,				g_noSshKeyCommands,			"Remove authorized SSH keys"},

	{nullptr,			INVALID_COMMAND,		nullptr,					nullptr}
};

static const clikeyword_t g_noFlashCommands[] =
{
	{"<key>",			FREEFORM_TOKEN,			nullptr,					"Key of the flash object to delete"},
	{nullptr,			INVALID_COMMAND,		nullptr,					nullptr}
};

static const clikeyword_t g_noCommands[] =
{
	{"flash",			CMD_FLASH,				g_noFlashCommands,			"Deletes objects from flash"},
	{"ntp",				CMD_NTP,				nullptr,					"Disables the NTP client"},
	{"ssh",				CMD_SSH,				g_noSshCommands,			"Remove authorized SSH keys"},

	{nullptr,			INVALID_COMMAND,		nullptr,					nullptr}
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// "show"

static const clikeyword_t g_showArpCommands[] =
{
	{"cache",			CMD_CACHE,				nullptr,				"Show contents of the ARP cache"},
	{nullptr,			INVALID_COMMAND,		nullptr,				nullptr}
};

static const clikeyword_t g_showIpCommands[] =
{
	{"address",			CMD_ADDRESS,			nullptr,				"Show the IPv4 address and subnet mask"},
	{"route",			CMD_ROUTE,				nullptr,				"Show the IPv4 routing table"},
	{nullptr,			INVALID_COMMAND,		nullptr,				nullptr}
};

static const clikeyword_t g_showSshAuthorized[] =
{
	{"keys",			CMD_KEYS,				nullptr,				"Show authorized keys"},
	{nullptr,			INVALID_COMMAND,		nullptr,				nullptr}
};

static const clikeyword_t g_showSshCommands[] =
{
	{"authorized",		CMD_AUTHORIZED,			g_showSshAuthorized,	"Show authorized keys"},
	{"fingerprint",		CMD_FINGERPRINT,		nullptr,				"Show the SSH host key fingerprint (in OpenSSH base64 SHA256 format)"},
	{nullptr,			INVALID_COMMAND,		nullptr,				nullptr}
};

static const clikeyword_t g_showFlashDetailCommands[] =
{
	{"<objname>",		FREEFORM_TOKEN,		nullptr,					"Name of the flash object to display"},
	{nullptr,			INVALID_COMMAND,	nullptr,					nullptr}
};

static const clikeyword_t g_showFlashCommands[] =
{
	{"<cr>",			OPTIONAL_TOKEN,		nullptr,					""},
	{"detail",			CMD_DETAIL,			g_showFlashDetailCommands,	"Show detailed flash object contents"},
	{nullptr,			INVALID_COMMAND,	nullptr,					nullptr}
};

static const clikeyword_t g_showCommands[] =
{
	{"arp",				CMD_ARP,			g_showArpCommands,			"Print ARP information"},
	{"flash",			CMD_FLASH,			g_showFlashCommands,		"Display flash usage and log data"},
	{"hardware",		CMD_HARDWARE,		nullptr,					"Print hardware information"},
	{"ip",				CMD_IP,				g_showIpCommands,			"Print IPv4 information"},
	{"ntp",				CMD_NTP,			nullptr,					"Print NTP information"},
	{"ssh",				CMD_SSH,			g_showSshCommands,			"Print SSH information"},
	{"version",			CMD_VERSION,		nullptr,					"Show firmware / FPGA version"},
	{nullptr,			INVALID_COMMAND,	nullptr,					nullptr}
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// "ssh"

static const clikeyword_t g_sshCommandsDescription[] =
{
	{"<description>",	FREEFORM_TOKEN,			nullptr,					"Description of key (typically user@host)"},
	{nullptr,			INVALID_COMMAND,		nullptr,					nullptr}
};

static const clikeyword_t g_sshCommandsBlob[] =
{
	{"<blob>",			FREEFORM_TOKEN,			g_sshCommandsDescription,	"Base64 encoded public key blob"},
	{nullptr,			INVALID_COMMAND,		nullptr,					nullptr}
};

static const clikeyword_t g_sshCommandsType[] =
{
	{"ssh-ed25519",		CMD_SSH_ED25519,		g_sshCommandsBlob,			"Ed25519 public key"},
	{nullptr,			INVALID_COMMAND,		nullptr,					nullptr}
};

static const clikeyword_t g_sshCommandsUsername[] =
{
	{"<username>",		FREEFORM_TOKEN,			nullptr,					"SSH username"},
	{nullptr,			INVALID_COMMAND,		nullptr,					nullptr}
};

static const clikeyword_t g_sshCommands[] =
{
	{"key",				CMD_KEY,				g_sshCommandsType,			"Authorize a new SSH public key"},
	{"username",		CMD_USERNAME,			g_sshCommandsUsername,		"Sets the SSH username"},
	{nullptr,			INVALID_COMMAND,		nullptr,					nullptr}
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// "ntp"

static const clikeyword_t g_ntpServerCommands[] =
{
	{"<ip>",			FREEFORM_TOKEN,			nullptr,					"IP address of NTP server to use"},
	{nullptr,			INVALID_COMMAND,		nullptr,					nullptr}
};

static const clikeyword_t g_ntpCommands[] =
{
	{"server",			CMD_SERVER,				g_ntpServerCommands,		"Sets the NTP server to use"},
	{nullptr,			INVALID_COMMAND,		nullptr,					nullptr}
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// zeroize

static const clikeyword_t g_zeroizeCommands[] =
{
	{"all",				FREEFORM_TOKEN,			nullptr,				"Confirm erasing all flash data and return to default state"},
	{nullptr,			INVALID_COMMAND,		nullptr,				nullptr}
};
*/
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Top level command lists

//Top level commands in root mode
static const clikeyword_t g_rootCommands[] =
{
	/*
	{"commit",		CMD_COMMIT,			nullptr,				"Commit volatile config changes to flash memory"},
	//{"dfu",			CMD_DFU,			nullptr,				"Reboot in DFU mode for firmware updating the main CPU"},
	{"eeprom",		CMD_EEPROM,			g_eepromCommands,		"Program or dump socket EEPROM"},*/
	{"exit",		CMD_EXIT,			nullptr,				"Log out"},
	/*{"flash",		CMD_FLASH,			g_flashCommands,		"Maintenance operations on flash"},
	{"hostname",	CMD_HOSTNAME,		g_hostnameCommands,		"Change the host name"},
	{"ip",			CMD_IP,				g_ipCommands,			"Configure IP addresses"},
	{"no",			CMD_NO,				g_noCommands,			"Remove or disable features"},
	{"ntp",			CMD_NTP,			g_ntpCommands,			"Configure NTP client"},
	{"reload",		CMD_RELOAD,			nullptr,				"Restart the system"},
	{"rollback",	CMD_ROLLBACK,		nullptr,				"Revert changes made since last commit"},
	{"show",		CMD_SHOW,			g_showCommands,			"Print information"},
	{"ssh",			CMD_SSH,			g_sshCommands,			"Configure SSH protocol"},
	{"zeroize",		CMD_ZEROIZE,		g_zeroizeCommands,		"Erase all configuration data and reload"},*/
	{nullptr,		INVALID_COMMAND,	nullptr,				nullptr}
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Main CLI code

LatentRedCLISessionContext::LatentRedCLISessionContext()
	: CLISessionContext(g_rootCommands)
{
	//cannot LoadHostname or do anything else touching the KVS here because the local console session is a global,
	//and is initialized before App_Init() calls InitKVS()
}

void LatentRedCLISessionContext::PrintPrompt()
{
	if(m_rootCommands == g_rootCommands)
		m_stream->Printf("%s@%s# ", m_username, m_hostname);
	m_stream->Flush();
}

void LatentRedCLISessionContext::LoadHostname()
{
	memset(m_hostname, 0, sizeof(m_hostname));

	//Read hostname, set to default value if not found
	auto hlog = g_kvs->FindObject(hostname_objid);
	if(hlog)
		strncpy(m_hostname, (const char*)g_kvs->MapObject(hlog), std::min((size_t)hlog->m_len, sizeof(m_hostname)-1));
	else
		strncpy(m_hostname, "switch", sizeof(m_hostname)-1);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Top level command dispatcher

void LatentRedCLISessionContext::OnExecute()
{
	if(m_rootCommands == g_rootCommands)
		OnExecuteRoot();

	//TODO other modes

	m_stream->Flush();
}

/**
	@brief Execute a command in config mode
 */
void LatentRedCLISessionContext::OnExecuteRoot()
{
	switch(m_command[0].m_commandID)
	{
		/*case CMD_COMMIT:
			OnCommit();
			break;*/
		/*
		case CMD_DFU:
			{
				//TODO: require confirmation or something
				RTC::Unlock();
				g_bbram->m_state = STATE_DFU;
				asm("dmb st");
				RTC::Lock();
				Reset();
			}
			break;
		*/

		/*case CMD_EEPROM:
			OnEepromCommand();
			break;*/

		case CMD_EXIT:
			m_stream->Flush();

			//SSH session? Close the socket
			if(m_stream == &m_sshstream)
				m_sshstream.GetServer()->GracefulDisconnect(m_sshstream.GetSessionID(), m_sshstream.GetSocket());

			//Local console? Nothing needed on real hardware (TODO logout)
			else
			{
			}
			break;/*

		case CMD_FLASH:
			if(m_command[1].m_commandID == CMD_COMPACT)
			{
				if(!g_kvs->Compact())
					g_log(Logger::ERROR, "Compaction failed\n");
			}
			break;

		case CMD_HOSTNAME:
			memset(m_hostname, 0, sizeof(m_hostname));
			strncpy(m_hostname, m_command[1].m_text, sizeof(m_hostname)-1);
			break;

		case CMD_IP:
			OnIPCommand();
			break;

		case CMD_NO:
			OnNoCommand();
			break;

		case CMD_NTP:
			if(m_command[1].m_commandID == CMD_SERVER)
				OnNtpServer(m_command[2].m_text);
			break;

		case CMD_RELOAD:
			OnReload();
			break;

		case CMD_ROLLBACK:
			OnRollback();
			break;

		case CMD_SHOW:
			OnShowCommand();
			break;

		case CMD_SSH:
			OnSSHCommand();
			break;

		case CMD_ZEROIZE:
			if(!strcmp(m_command[1].m_text, "all"))
			{
				g_kvs->WipeAll();
				OnReload();
			}
			break;*/

		default:
			m_stream->Printf("Unrecognized command\n");
			break;
	}
}
/*
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// "commit"

void LatentRedCLISessionContext::OnCommit()
{
	//Save hostname and SSH username
	if(!g_kvs->StoreStringObjectIfNecessary(hostname_objid, m_hostname, "dumptruck"))
		m_stream->Printf("KVS write error\n");

	if(!g_kvs->StoreStringObjectIfNecessary(g_usernameObjectID, g_sshUsername, g_defaultSshUsername))
		m_stream->Printf("KVS write error\n");

	//Save SSH authorized key list
	g_keyMgr.CommitToKVS();

	//Save service configuration
	//g_dhcpClient->SaveConfigToKVS();
	g_udp->GetNTP().SaveConfigToKVS();

	//Save IP configuration
	if(!g_kvs->StoreObjectIfNecessary<IPv4Address>(g_ipConfig.m_address, g_defaultIP, "ip.address"))
		m_stream->Printf("KVS write error\n");
	if(!g_kvs->StoreObjectIfNecessary<IPv4Address>(g_ipConfig.m_netmask, g_defaultNetmask, "ip.netmask"))
		m_stream->Printf("KVS write error\n");
	if(!g_kvs->StoreObjectIfNecessary<IPv4Address>(g_ipConfig.m_broadcast, g_defaultBroadcast, "ip.broadcast"))
		m_stream->Printf("KVS write error\n");
	if(!g_kvs->StoreObjectIfNecessary<IPv4Address>(g_ipConfig.m_gateway, g_defaultGateway, "ip.gateway"))
		m_stream->Printf("KVS write error\n");
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// "ip"

void LatentRedCLISessionContext::OnIPAddress(const char* addr)
{
	SetIPAddress(m_stream, addr);
}

void LatentRedCLISessionContext::OnIPGateway(const char* gw)
{
	if(!ParseIPAddress(gw, g_ipConfig.m_gateway))
		m_stream->Printf("Usage: ip gateway x.x.x.x\n");
}

void LatentRedCLISessionContext::OnIPCommand()
{
	switch(m_command[1].m_commandID)
	{
		case CMD_ADDRESS:
			if(m_command[2].m_commandID == CMD_DHCP)
			{
				g_usingDHCP = true;
				g_dhcpClient->Enable();
			}
			else
			{
				//g_usingDHCP = false;
				//g_dhcpClient->Disable();
				OnIPAddress(m_command[2].m_text);
			}
			break;

		case CMD_GATEWAY:
			OnIPGateway(m_command[2].m_text);
			break;

		default:
			m_stream->Printf("Unrecognized command\n");
			break;
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// "ntp"

void LatentRedCLISessionContext::OnNtpServer(const char* addr)
{
	//Parse the base IP address
	IPv4Address iaddr;
	if(!ParseIPAddress(addr, iaddr))
	{
		m_stream->Printf("Usage: ntp server x.x.x.x\n");
		return;
	}

	g_udp->GetNTP().Enable();
	g_udp->GetNTP().SetServerAddress(iaddr);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// "no"

void LatentRedCLISessionContext::OnNoSSHCommand()
{
	switch(m_command[2].m_commandID)
	{
		case CMD_KEY:
			g_keyMgr.RemovePublicKey(atoi(m_command[3].m_text));
			break;

		default:
			break;
	}
}

void LatentRedCLISessionContext::OnNoCommand()
{
	switch(m_command[1].m_commandID)
	{
		case CMD_FLASH:
			RemoveFlashKey(m_stream, m_command[2].m_text);
			break;

		case CMD_NTP:
			g_udp->GetNTP().Disable();
			break;

		case CMD_SSH:
			OnNoSSHCommand();
			break;

		default:
			break;
	}
}*/

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// "reload"

void LatentRedCLISessionContext::OnReload()
{
	//TODO: do this through the supervisor to do a whole-system reset instead of just rebooting the MCU

	g_log("Reload requested\n");
	Reset();
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// "rollback"

/**
	@brief Load all of our configuration from the KVS, discarding any recent changes made in the CLI
 */
void LatentRedCLISessionContext::OnRollback()
{
	/*
	g_keyMgr.LoadFromKVS(false);

	//g_dhcpClient->LoadConfigFromKVS();
	g_udp->GetNTP().LoadConfigFromKVS();
	ConfigureIP();
	LoadHostname();
	g_sshd->LoadUsername();
	*/
}
/*
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// "show"

void LatentRedCLISessionContext::OnShowCommand()
{
	switch(m_command[1].m_commandID)
	{
		case CMD_ARP:
			switch(m_command[2].m_commandID)
			{
				case CMD_CACHE:
					PrintARPCache(m_stream, g_ethProtocol);
					break;

				default:
					break;
			}
			break;

		case CMD_FLASH:
			OnShowFlash();
			break;

		case CMD_HARDWARE:
			OnShowHardware();
			break;

		case CMD_IP:
			switch(m_command[2].m_commandID)
			{
				case CMD_ADDRESS:
					PrintIPAddress(m_stream);
					break;

				case CMD_ROUTE:
					PrintDefaultRoute(m_stream);
					break;

				default:
					break;
			}
			break;

		case CMD_NTP:
			PrintNTP(m_stream, g_udp->GetNTP());
			break;

		case CMD_SSH:
			switch(m_command[2].m_commandID)
			{
				case CMD_AUTHORIZED:
					PrintSSHKeys(m_stream, g_keyMgr);
					break;

				case CMD_FINGERPRINT:
					PrintSSHHostKey(m_stream);
					break;

				default:
					break;
			}
			break;

		case CMD_VERSION:
			OnShowVersion();
			break;

		default:
			m_stream->Printf("Unrecognized command\n");
			break;
	}
}

void LatentRedCLISessionContext::OnShowFlash()
{
	//No details requested? Show root dir listing
	if(m_command[2].m_commandID == OPTIONAL_TOKEN)
		PrintFlashSummary(m_stream);

	//Showing details of a single object
	else
		PrintFlashDetails(m_stream, m_command[3].m_text);
}

void LatentRedCLISessionContext::OnShowHardware()
{
	PrintProcessorInfo(m_stream);

	//m_stream->Printf("\n");
	//m_stream->Printf("Supervisor:");
	//m_stream->Printf("    %s\n", g_superVersion);

	m_stream->Printf("\n");
	m_stream->Printf("Ethernet interface mgmt0:\n");
	m_stream->Printf("    MAC address: %02x:%02x:%02x:%02x:%02x:%02x\n",
		g_macAddress[0], g_macAddress[1], g_macAddress[2], g_macAddress[3], g_macAddress[4], g_macAddress[5]);

	//TODO: refactor into common
	m_stream->Printf("\n");
	m_stream->Printf("FPGA:\n");

	uint32_t idcode = FDEVINFO.idcode;
	memcpy(g_fpgaSerial, (const void*)FDEVINFO.serial, 8);

	//Print status
	m_stream->Printf("    IDCODE:   %08x (%s rev %d)\n", idcode, GetNameOfFPGA(idcode), idcode >> 28);
	m_stream->Printf("    Serial:   %02x%02x%02x%02x%02x%02x%02x%02x\n",
		g_fpgaSerial[7], g_fpgaSerial[6], g_fpgaSerial[5], g_fpgaSerial[4],
		g_fpgaSerial[3], g_fpgaSerial[2], g_fpgaSerial[1], g_fpgaSerial[0]);

	//Read USERCODE
	g_usercode = FDEVINFO.usercode;
	m_stream->Printf("    Usercode: %08x\n", g_usercode);
	{
		LogIndenter li2(g_log);

		//Format per XAPP1232:
		//31:27 day
		//26:23 month
		//22:17 year
		//16:12 hr
		//11:6 min
		//5:0 sec
		int day = g_usercode >> 27;
		int mon = (g_usercode >> 23) & 0xf;
		int yr = 2000 + ((g_usercode >> 17) & 0x3f);
		int hr = (g_usercode >> 12) & 0x1f;
		int min = (g_usercode >> 6) & 0x3f;
		int sec = g_usercode & 0x3f;
		m_stream->Printf("    Version:  %04d-%02d-%02d %02d:%02d:%02d\n",
			yr, mon, day, hr, min, sec);
	}

	m_stream->Printf("\n");
	m_stream->Printf("Temperatures:\n");
	m_stream->Printf("    Supervisor: %uhk C\n", ReadSupervisorRegister(SUPER_REG_MCUTEMP));
	m_stream->Printf("    MCU:        %uhk C\n",  g_dts.GetTemperature());
	m_stream->Printf("    FPGA:       %uhk C\n",  FXADC.die_temp);
	m_stream->Printf("    LTC3374A:   %uhk C\n", ReadSupervisorRegister(SUPER_REG_LTC_TEMP));

	//Print sensor values
	m_stream->Printf("\n");
	m_stream->Printf("Power rails:\n");
	m_stream->Printf("    +------------+---------+---------+--------+\n");
	m_stream->Printf("    | Rail       | Voltage | Current |  Power |\n");
	m_stream->Printf("    +------------+---------+---------+--------+\n");

	PrintPowerRail("VBUS", SUPER_REG_VVBUS, SUPER_REG_IVBUS);
	PrintPowerRail("3V3_SB", SUPER_REG_3V3, SUPER_REG_I3V3_SB);
	PrintPowerRail("3V3", SUPER_REG_V3V3, SUPER_REG_I3V3);
	PrintPowerRail("2V5", SUPER_REG_V2V5, SUPER_REG_I2V5);
	PrintPowerRail("1V8", SUPER_REG_V1V8, SUPER_REG_I1V8);
	m_stream->Printf("    |     VCCAUX |   %uhk |         |        |\n", FXADC.volt_aux);
	PrintPowerRail("1V2", SUPER_REG_V1V2, SUPER_REG_I1V2);
	PrintPowerRail("1V0", SUPER_REG_V1V0, SUPER_REG_I1V0);
	m_stream->Printf("    |     VCCINT |   %uhk |         |        |\n", FXADC.volt_core);
	m_stream->Printf("    |    VCCBRAM |   %uhk |         |        |\n", FXADC.volt_ram);
	PrintPowerRail("DUT_VDD", SUPER_REG_VDUTVDD, SUPER_REG_IDUTVDD);
	PrintPowerRail("VCCIO33", SUPER_REG_VIO_33, SUPER_REG_IIO_33);
	PrintPowerRail("VCCIO25", SUPER_REG_VIO_25, SUPER_REG_IIO_25);
	PrintPowerRail("VCCIO18", SUPER_REG_VIO_18, SUPER_REG_IIO_18);
	PrintPowerRail("VCCIO12", SUPER_REG_VIO_12, SUPER_REG_IIO_12);

	m_stream->Printf("    +------------+---------+---------+-------+\n");
}

void LatentRedCLISessionContext::OnShowVersion()
{
	m_stream->Printf("DUMPTRUCK v0.1\n");
	m_stream->Printf("by Andrew D. Zonenberg\n");
	m_stream->Printf("\n");
	m_stream->Printf("This system is open hardware! Board design files and firmware/gateware source code are at:\n");
	m_stream->Printf("https://github.com/azonenberg/dumptruck\n");
	m_stream->Printf("\n");
	m_stream->Printf("Firmware compiled at %s on %s\n", __TIME__, __DATE__);
	#ifdef __GNUC__
	m_stream->Printf("Compiler: g++ %s\n", __VERSION__);
	m_stream->Printf("CLI source code last modified: %s\n", __TIMESTAMP__);
	#endif
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// "ssh"

void LatentRedCLISessionContext::OnSSHCommand()
{
	switch(m_command[1].m_commandID)
	{
		case CMD_KEY:
			g_keyMgr.AddPublicKey(m_command[2].m_text, m_command[3].m_text, m_command[4].m_text);
			break;

		case CMD_USERNAME:
			//yes this can truncate, we accept that
			#pragma GCC diagnostic push
			#pragma GCC diagnostic ignored "-Wstringop-truncation"
			strncpy(g_sshUsername, m_command[2].m_text, sizeof(g_sshUsername)-1);
			#pragma GCC diagnostic pop
			break;

		default:
			m_stream->Printf("Unrecognized command\n");
			break;
	}
}
*/
