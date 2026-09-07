include(ExternalProject)

# The canonical repository. The GitHub mirror stops at 3.4.
set(x265_GIT_REPOSITORY "https://bitbucket.org/multicoreware/x265_git.git")
set(x265_GIT_TAG "4.2")

set(x265_DEPS)
if(TLRENDER_NASM)
    list(APPEND x265_DEPS NASM)
endif()

# Static, and no command line tool: this is here to be linked into FFmpeg,
# not to be shipped as a program. The assembly needs NASM, which is on PATH
# on Windows and built here everywhere else.
set(x265_ARGS
    ${TLRENDER_EXTERNAL_ARGS}
    -DENABLE_SHARED=OFF
    -DENABLE_CLI=OFF
    -DENABLE_ASSEMBLY=ON)
if(TLRENDER_NASM)
    list(APPEND x265_ARGS -DCMAKE_ASM_NASM_COMPILER=${CMAKE_INSTALL_PREFIX}/bin/nasm)
endif()

ExternalProject_Add(
    x265
    PREFIX ${CMAKE_CURRENT_BINARY_DIR}/x265
    DEPENDS ${x265_DEPS}
    GIT_REPOSITORY ${x265_GIT_REPOSITORY}
    GIT_TAG ${x265_GIT_TAG}
    SOURCE_SUBDIR source
    CMAKE_ARGS ${x265_ARGS})

if(WIN32)
    # FFmpeg finds x265 through pkg-config and nothing else, and two things
    # about a static MSVC build defeat it.
    #
    # The library is "x265-static.lib" while x265.pc says "-lx265", which the
    # MSVC toolchain turns into "x265.lib". That name is given below rather
    # than changed in the file, so the same pkg-config file works whichever
    # of the two a later x265 installs.
    #
    # And x265 reads the Windows registry to size its thread pool, so anything
    # linking it needs advapi32, which its own x265.pc does not say. FFmpeg's
    # configure link test then fails on three unresolved Reg* symbols and
    # reports "x265 not found using pkg-config", which points nowhere near it.
    # Hence the replacement file.
    #
    # advapi32 goes in Libs rather than only Libs.private, which is where it
    # belongs: FFmpeg is built shared here, so its configure asks pkg-config
    # for --libs without --static, and a private entry is not returned at all.
    #
    # It is written at configure time so that every path in it is a CMake
    # variable expanded once, rather than pkg-config's own "${}" escaped
    # through a generated script.
    set(x265_PC ${CMAKE_CURRENT_BINARY_DIR}/x265/x265.pc)
    file(WRITE ${x265_PC}
"prefix=${CMAKE_INSTALL_PREFIX}
exec_prefix=${CMAKE_INSTALL_PREFIX}
libdir=${CMAKE_INSTALL_PREFIX}/lib
includedir=${CMAKE_INSTALL_PREFIX}/include

Name: x265
Description: H.265/HEVC video encoder
Version: ${x265_GIT_TAG}
Libs: -L${CMAKE_INSTALL_PREFIX}/lib -lx265 -ladvapi32
Libs.private: -ladvapi32
Cflags: -I${CMAKE_INSTALL_PREFIX}/include
")

    ExternalProject_Add_Step(
        x265 msvc-fixups
        COMMAND ${CMAKE_COMMAND} -E copy
            ${CMAKE_INSTALL_PREFIX}/lib/x265-static.lib
            ${CMAKE_INSTALL_PREFIX}/lib/x265.lib
        COMMAND ${CMAKE_COMMAND} -E copy
            ${x265_PC}
            ${CMAKE_INSTALL_PREFIX}/lib/pkgconfig/x265.pc
        DEPENDEES install)
endif()
