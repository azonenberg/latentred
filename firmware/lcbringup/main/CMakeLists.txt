add_executable(main
	LatentRedCLISessionContext.cpp
	#DumptruckSFTPServer.cpp
	LatentRedSSHTransportServer.cpp
	LatentRedTCPProtocol.cpp
	LatentRedUDPProtocol.cpp
	LatentRedPhyPollTask.cpp
	PortState.cpp

	globals.cpp
	Init.cpp
	vectors.cpp)

target_link_options(main
	PUBLIC "-ffunction-sections"
	PUBLIC "-Wl,--gc-sections"
	PUBLIC "-Wl,-T${CMAKE_CURRENT_SOURCE_DIR}/firmware.ld"
	PUBLIC "-L${PROJECT_ROOT}/stm32-cpp/devices/link/"
	PUBLIC "-L${CMAKE_CURRENT_SOURCE_DIR}/..")

target_link_libraries(main
	bsp
	common-embedded-platform-boilerplate-h735
	common-embedded-platform-cli
	common-embedded-platform-core
	common-embedded-platform-drivers
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
common_postbuild(main)
