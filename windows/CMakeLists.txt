cmake_minimum_required(VERSION 3.14)
project(ipfs_ffi_library LANGUAGES C CXX)

include("${CMAKE_SOURCE_DIR}/flutter/ephemeral/generated_config.cmake" OPTIONAL)

get_filename_component(IPFS_FFI_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/.." REALPATH)

set(DART_EXECUTABLE "")
if(DEFINED FLUTTER_ROOT AND EXISTS "${FLUTTER_ROOT}/bin/cache/dart-sdk/bin/dart.exe")
  set(DART_EXECUTABLE "${FLUTTER_ROOT}/bin/cache/dart-sdk/bin/dart.exe")
else()
  find_program(DART_EXECUTABLE NAMES dart.exe dart REQUIRED)
endif()

find_program(GO_EXECUTABLE NAMES go.exe go)
if(NOT GO_EXECUTABLE)
  message(FATAL_ERROR
    "ipfs_ffi: executável 'go' (Golang) não encontrado no PATH. "
    "Instale o Go (ex.: 'winget install GoLang.Go') e reinicie o terminal/IDE."
  )
endif()

find_program(GCC_EXECUTABLE NAMES gcc.exe gcc)
if(NOT GCC_EXECUTABLE)
  message(FATAL_ERROR
    "ipfs_ffi: executável 'gcc' (MinGW-w64) não encontrado no PATH. "
    "Instale o MinGW-w64 (ex.: 'winget install BrechtSanders.WinLibs.POSIX.UCRT') e reinicie o terminal/IDE."
  )
endif()

if(NOT EXISTS "${IPFS_FFI_ROOT}/.dart_tool/package_config.json")
  file(MAKE_DIRECTORY "${IPFS_FFI_ROOT}/.dart_tool")
  file(WRITE "${IPFS_FFI_ROOT}/.dart_tool/package_config.json" "{\"configVersion\":2,\"packages\":[]}\n")
endif()

set(IPFS_HOST_EXE "${IPFS_FFI_ROOT}/native/ipfs_host.exe")
set(IPFS_SHM_DLL "${IPFS_FFI_ROOT}/native/ipfs_shm.dll")

file(GLOB IPFS_GO_SOURCES "${IPFS_FFI_ROOT}/go/*.go")

add_custom_command(
  OUTPUT "${IPFS_HOST_EXE}" "${IPFS_SHM_DLL}"
  COMMAND "${DART_EXECUTABLE}" "${IPFS_FFI_ROOT}/tool/build.dart" --no-gen windows
  WORKING_DIRECTORY "${IPFS_FFI_ROOT}"
  DEPENDS
    "${IPFS_FFI_ROOT}/tool/build.dart"
    "${IPFS_FFI_ROOT}/shm/ipfs_shm.c"
    "${IPFS_FFI_ROOT}/shm/ipfs_shm.h"
    ${IPFS_GO_SOURCES}
  COMMENT "Building ipfs_ffi native binaries for Windows (ipfs_host.exe, ipfs_shm.dll)..."
  VERBATIM
)

add_custom_target(ipfs_ffi_native ALL
  DEPENDS "${IPFS_HOST_EXE}" "${IPFS_SHM_DLL}"
)

if(DEFINED BINARY_NAME AND TARGET ${BINARY_NAME})
  add_dependencies(${BINARY_NAME} ipfs_ffi_native)
endif()

set(ipfs_ffi_bundled_libraries
  "${IPFS_HOST_EXE}"
  "${IPFS_SHM_DLL}"
  PARENT_SCOPE
)
