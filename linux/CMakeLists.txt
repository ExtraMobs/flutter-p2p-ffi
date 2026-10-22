cmake_minimum_required(VERSION 3.13)
project(p2p_ffi_library LANGUAGES C CXX)

include("${CMAKE_SOURCE_DIR}/flutter/ephemeral/generated_config.cmake" OPTIONAL)

get_filename_component(P2P_FFI_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/.." REALPATH)

set(DART_EXECUTABLE "")
if(DEFINED FLUTTER_ROOT AND EXISTS "${FLUTTER_ROOT}/bin/cache/dart-sdk/bin/dart")
  set(DART_EXECUTABLE "${FLUTTER_ROOT}/bin/cache/dart-sdk/bin/dart")
else()
  find_program(DART_EXECUTABLE NAMES dart REQUIRED)
endif()

find_program(GO_EXECUTABLE NAMES go)
if(NOT GO_EXECUTABLE)
  message(FATAL_ERROR
    "p2p_ffi: executável 'go' (Golang) não encontrado no PATH. "
    "Instale o Go e reinicie o terminal/IDE."
  )
endif()

find_program(GCC_EXECUTABLE NAMES gcc)
if(NOT GCC_EXECUTABLE)
  message(FATAL_ERROR
    "p2p_ffi: executável 'gcc' não encontrado no PATH. "
    "Instale o build-essential/gcc (ex.: 'sudo apt-get install build-essential') e reinicie o terminal/IDE."
  )
endif()

if(NOT EXISTS "${P2P_FFI_ROOT}/.dart_tool/package_config.json")
  file(MAKE_DIRECTORY "${P2P_FFI_ROOT}/.dart_tool")
  file(WRITE "${P2P_FFI_ROOT}/.dart_tool/package_config.json" "{\"configVersion\":2,\"packages\":[]}\n")
endif()

set(P2P_HOST_BIN "${P2P_FFI_ROOT}/native/p2p_host")
set(P2P_SHM_SO "${P2P_FFI_ROOT}/native/libp2p_shm.so")

file(GLOB IPFS_GO_SOURCES "${P2P_FFI_ROOT}/go/*.go")

add_custom_command(
  OUTPUT "${P2P_HOST_BIN}" "${P2P_SHM_SO}"
  COMMAND "${DART_EXECUTABLE}" "${P2P_FFI_ROOT}/tool/build.dart" --no-gen linux
  WORKING_DIRECTORY "${P2P_FFI_ROOT}"
  DEPENDS
    "${P2P_FFI_ROOT}/tool/build.dart"
    "${P2P_FFI_ROOT}/shm/p2p_shm.c"
    "${P2P_FFI_ROOT}/shm/p2p_shm.h"
    ${IPFS_GO_SOURCES}
  COMMENT "Building p2p_ffi native binaries for Linux (p2p_host, libp2p_shm.so)..."
  VERBATIM
)

add_custom_target(p2p_ffi_native ALL
  DEPENDS "${P2P_HOST_BIN}" "${P2P_SHM_SO}"
)

if(DEFINED BINARY_NAME AND TARGET ${BINARY_NAME})
  add_dependencies(${BINARY_NAME} p2p_ffi_native)
endif()

set(p2p_ffi_bundled_libraries
  "${P2P_HOST_BIN}"
  "${P2P_SHM_SO}"
  PARENT_SCOPE
)
