add_library(bsp STATIC
	common-vectors.cpp
	hwinit.cpp
	)

target_include_directories(bsp
	PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}
	"$<TARGET_PROPERTY:common-embedded-platform-core,INTERFACE_INCLUDE_DIRECTORIES>"
	)
