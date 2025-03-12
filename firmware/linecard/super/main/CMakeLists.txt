add_executable(main
	#KupLulzSuperSPIServer.cpp
	Init.cpp

	vectors.cpp)

target_link_options(main
	PUBLIC "-ffunction-sections"
	PUBLIC "-Wl,--gc-sections"
	#PUBLIC "-Wl,-T${PROJECT_ROOT}/stm32-cpp/devices/link/stm32l431_32kboot_app.ld"
	PUBLIC "-Wl,-T${PROJECT_ROOT}/stm32-cpp/devices/link/stm32l431.ld"
	PUBLIC "-L${PROJECT_ROOT}/stm32-cpp/devices/link/")

target_link_libraries(main
	bsp
	common-embedded-platform-core
	common-embedded-platform-supervisor
	embedded-cli
	embedded-utils
	microkvs
	stm32-cpp
	)

# Calculate flash usage and generate binary file
common_postbuild(main)
