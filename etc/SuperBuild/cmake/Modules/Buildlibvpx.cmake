include(ExternalProject)

if(WIN32)
    # Built with MSYS2 on Windows, like FFmpeg and x264: libvpx has a shell
    # configure script and no CMake build.
    find_package(Msys REQUIRED)
endif()

set(libvpx_GIT_REPOSITORY "https://github.com/webmproject/libvpx.git")
set(libvpx_GIT_TAG "v1.15.2")

set(libvpx_DEPS)
if(WIN32)
    list(APPEND libvpx_DEPS msys-packages)
endif()
if(TLRENDER_NASM)
    list(APPEND libvpx_DEPS NASM)
endif()

# Static, and nothing but the library: this is here to be linked into FFmpeg.
set(libvpx_CONFIGURE_ARGS
    --prefix=${CMAKE_INSTALL_PREFIX}
    --disable-examples
    --disable-tools
    --disable-docs
    --disable-unit-tests
    --enable-pic
    --enable-vp9
    --disable-shared
    --enable-static)

include(ProcessorCount)
ProcessorCount(libvpx_BUILD_JOBS)

if(WIN32)
    set(libvpx_MSYS2 ${MSYS_CMD} -use-full-path -defterm -no-start -here)
    # The Visual Studio target rather than a compiler override: libvpx builds
    # for MSVC by generating project files and driving MSBuild from its
    # makefile, which is not the CC=cl route x264 takes. The CRT is left
    # dynamic (no --enable-static-msvcrt) to match the /MD that FFmpeg and
    # everything else here is built with.
    list(APPEND libvpx_CONFIGURE_ARGS --target=x86_64-win64-vs17)
    list(JOIN libvpx_CONFIGURE_ARGS " " libvpx_CONFIGURE_ARGS_TMP)
    set(libvpx_CONFIGURE ${libvpx_MSYS2}
        -c "./configure ${libvpx_CONFIGURE_ARGS_TMP}")
    set(libvpx_BUILD ${libvpx_MSYS2} -c "make -j${libvpx_BUILD_JOBS}")
    set(libvpx_INSTALL ${libvpx_MSYS2} -c "make install")
else()
    set(libvpx_CONFIGURE ./configure ${libvpx_CONFIGURE_ARGS})
    set(libvpx_BUILD make -j${libvpx_BUILD_JOBS})
    set(libvpx_INSTALL make install)
endif()

ExternalProject_Add(
    libvpx
    PREFIX ${CMAKE_CURRENT_BINARY_DIR}/libvpx
    DEPENDS ${libvpx_DEPS}
    GIT_REPOSITORY ${libvpx_GIT_REPOSITORY}
    GIT_TAG ${libvpx_GIT_TAG}
    CONFIGURE_COMMAND ${libvpx_CONFIGURE}
    BUILD_COMMAND ${libvpx_BUILD}
    INSTALL_COMMAND ${libvpx_INSTALL}
    BUILD_IN_SOURCE 1)

if(WIN32)
    # The Visual Studio target installs neither where nor what FFmpeg looks
    # for: the library lands in "lib/x64" as "vpxmd.lib" (md for the dynamic
    # CRT), and no vpx.pc is written at all, while FFmpeg finds libvpx through
    # pkg-config and nothing else.
    #
    # The file is written here, at configure time, so every path in it is a
    # CMake variable expanded once. Generating a script that writes it would
    # mean escaping pkg-config's own "${}" through two layers.
    string(REGEX REPLACE "^v" "" libvpx_VERSION ${libvpx_GIT_TAG})
    set(libvpx_PC ${CMAKE_CURRENT_BINARY_DIR}/libvpx/vpx.pc)
    file(WRITE ${libvpx_PC}
"prefix=${CMAKE_INSTALL_PREFIX}
exec_prefix=${CMAKE_INSTALL_PREFIX}
libdir=${CMAKE_INSTALL_PREFIX}/lib
includedir=${CMAKE_INSTALL_PREFIX}/include

Name: vpx
Description: WebM Project VPx codec implementation
Version: ${libvpx_VERSION}
Requires:
Conflicts:
Libs: -L${CMAKE_INSTALL_PREFIX}/lib -lvpx
Libs.private:
Cflags: -I${CMAKE_INSTALL_PREFIX}/include
")

    ExternalProject_Add_Step(
        libvpx msvc-install
        COMMAND ${CMAKE_COMMAND} -E copy
            ${CMAKE_INSTALL_PREFIX}/lib/x64/vpxmd.lib
            ${CMAKE_INSTALL_PREFIX}/lib/vpx.lib
        COMMAND ${CMAKE_COMMAND} -E copy
            ${libvpx_PC}
            ${CMAKE_INSTALL_PREFIX}/lib/pkgconfig/vpx.pc
        DEPENDEES install)
endif()
