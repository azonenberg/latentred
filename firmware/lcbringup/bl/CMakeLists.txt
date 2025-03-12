add_executable(bootloader
	#BootloaderCLISessionContext.cpp
	#BootloaderSFTPServer.cpp
	#BootloaderSSHTransportServer.cpp
	#BootloaderTCPProtocol.cpp
	#BootloaderUDPProtocol.cpp
	#MainApplicationFirmwareUpdater.cpp

	mainloop.cpp
	vectors.cpp)

target_link_options(bootloader
	PUBLIC "-ffunction-sections"
	PUBLIC "-Wl,--gc-sections"
	PUBLIC "-Wl,-T${CMAKE_CURRENT_SOURCE_DIR}/bootloader.ld"
	PUBLIC "-L${PROJECT_ROOT}/stm32-cpp/devices/link/"
	PUBLIC "-L${CMAKE_CURRENT_SOURCE_DIR}/..")

target_link_libraries(bootloader
	bsp
	common-embedded-platform-boilerplate-h735
	common-embedded-platform-bootloader
	common-embedded-platform-core
	common-embedded-platform-fpga
	common-embedded-platform-tcpip
	common-embedded-platform-services
	embedded-cli
	embedded-utils
	microkvs
	staticnet
	stm32-cpp
	)

# Calculate flash usage and generate binary file
common_postbuild(bootloader)
