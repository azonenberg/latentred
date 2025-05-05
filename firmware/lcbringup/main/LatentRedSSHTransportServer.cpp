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
#include "LatentRedSSHTransportServer.h"
#include <algorithm>

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

LatentRedSSHTransportServer::LatentRedSSHTransportServer(TCPProtocol& tcp)
	: SSHTransportServer(tcp)
	, m_auth(g_sshUsername, g_keyMgr)
{
	g_log("Initializing SSH server\n");
	LogIndenter li(g_log);

	//Initialize crypto and SFTP state
	for(size_t i=0; i<SSH_TABLE_SIZE; i++)
	{
		m_state[i].m_crypto = &m_engine[i];
		//m_state[i].m_sftpState = &m_sftpState[i];
	}

	//Find the keys, generating if required
	unsigned char pub[ECDSA_KEY_SIZE] = {0};
	unsigned char priv[ECDSA_KEY_SIZE] = {0};

	bool found = true;
	if(!g_kvs->ReadObject("ssh.hostpub", pub, ECDSA_KEY_SIZE))
		found = false;
	if(!g_kvs->ReadObject("ssh.hostpriv", priv, ECDSA_KEY_SIZE))
		found = false;

	if(found)
	{
		g_log("Using existing SSH host key\n");
		CryptoEngine::SetHostKey(pub, priv);
	}

	else
	{
		g_log("No SSH host key in flash, generating new key pair\n");
		m_state[0].m_crypto->GenerateHostKey();

		if(!g_kvs->StoreObject("ssh.hostpub", CryptoEngine::GetHostPublicKey(), ECDSA_KEY_SIZE))
			g_log(Logger::ERROR, "Unable to store SSH host public key to flash\n");
		if(!g_kvs->StoreObject("ssh.hostpriv", CryptoEngine::GetHostPrivateKey(), ECDSA_KEY_SIZE))
			g_log(Logger::ERROR, "Unable to store SSH host private key to flash\n");
	}

	char buf[64] = {0};
	m_state[0].m_crypto->GetHostKeyFingerprint(buf, sizeof(buf));
	g_log("ED25519 key fingerprint is SHA256:%s.\n", buf);

	//Load the SSH username
	LoadUsername();

	//Load authorized keys
	g_keyMgr.LoadFromKVS();

	//Set up authenticators
	UsePasswordAuthenticator(nullptr);
	UsePubkeyAuthenticator(&m_auth);

	//Set up SFTP server
	//UseSFTPServer(&m_sftp);
}

void LatentRedSSHTransportServer::LoadUsername()
{
	memset(g_sshUsername, 0, sizeof(g_sshUsername));

	//Read hostname, set to default value if not found
	auto hlog = g_kvs->FindObject(g_usernameObjectID);
	if(hlog)
		strncpy(g_sshUsername, (const char*)g_kvs->MapObject(hlog), std::min((size_t)hlog->m_len, sizeof(g_sshUsername)-1));
	else
		strncpy(g_sshUsername, g_defaultSshUsername, sizeof(g_sshUsername)-1);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Shell helpers

void LatentRedSSHTransportServer::InitializeShell(int id, TCPTableEntry* socket)
{
	m_context[id].Initialize(id, socket, this, m_state[id].m_username);
	m_context[id].PrintPrompt();

	//TODO: only if we "terminal monitor" or similar?
	//g_logSink->AddSink(m_context[id].GetSSHStream());
}

void LatentRedSSHTransportServer::GracefulDisconnect(int id, TCPTableEntry* socket)
{
	//g_logSink->RemoveSink(m_context[id].GetSSHStream());
	SSHTransportServer::GracefulDisconnect(id, socket);
}

void LatentRedSSHTransportServer::DropConnection(int id, TCPTableEntry* socket)
{
	//g_logSink->RemoveSink(m_context[id].GetSSHStream());
	SSHTransportServer::DropConnection(id, socket);
}

void LatentRedSSHTransportServer::OnRxShellData(int id, [[maybe_unused]] TCPTableEntry* socket, char* data, uint16_t len)
{
	for(uint16_t i=0; i<len; i++)
		m_context[id].OnKeystroke(data[i]);
}

void LatentRedSSHTransportServer::DoExecRequest(int id, TCPTableEntry* socket, const char* cmd, uint16_t len)
{
	m_context[id].Initialize(id, socket, this, m_state[id].m_username);

	for(uint16_t i=0; i<len; i++)
		m_context[id].OnKeystroke(cmd[i], false);
	m_context[id].SilentExecute();
}
