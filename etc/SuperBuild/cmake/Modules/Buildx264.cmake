include(ExternalProject)

if(WIN32)
    # Built with MSYS2 on Windows, the way FFmpeg beside it is: x264 has a
    # shell configure script and no CMake build.
    find_package(Msys REQUIRED)
endif()

# x264 publishes no version tags, only branches, so the stable branch is
# pinned by commit. code.videolan.org rather than the GitHub mirror, which
# lags it.
set(x264_GIT_REPOSITORY "https://code.videolan.org/videolan/x264.git")
set(x264_GIT_TAG "b35605ace3ddf7c1a5d67a2eb553f034aef41d55")

set(x264_DEPS)
if(WIN32)
    list(APPEND x264_DEPS msys-packages)
endif()
if(TLRENDER_NASM)
    list(APPEND x264_DEPS NASM)
endif()

# Static, and no command line tool: this is here to be linked into FFmpeg.
set(x264_CONFIGURE_ARGS
    --prefix=${CMAKE_INSTALL_PREFIX}
    --enable-static
    --disable-cli
    --disable-opencl)

include(ProcessorCount)
ProcessorCount(x264_BUILD_JOBS)

if(WIN32)
    set(x264_MSYS2 ${MSYS_CMD} -use-full-path -defterm -no-start -here)
    list(JOIN x264_CONFIGURE_ARGS " " x264_CONFIGURE_ARGS_TMP)
    # CC=cl is what puts configure into its MSVC mode; without it the shell
    # finds gcc and builds something that cannot be linked into an MSVC
    # FFmpeg.
    set(x264_CONFIGURE ${x264_MSYS2}
        -c "CC=cl ./configure ${x264_CONFIGURE_ARGS_TMP}")
    set(x264_BUILD ${x264_MSYS2} -c "make -j${x264_BUILD_JOBS}")
    set(x264_INSTALL ${x264_MSYS2} -c "make install")
else()
    set(x264_CONFIGURE ./configure ${x264_CONFIGURE_ARGS})
    set(x264_BUILD make -j${x264_BUILD_JOBS})
    set(x264_INSTALL make install)
endif()

ExternalProject_Add(
    x264
    PREFIX ${CMAKE_CURRENT_BINARY_DIR}/x264
    DEPENDS ${x264_DEPS}
    GIT_REPOSITORY ${x264_GIT_REPOSITORY}
    GIT_TAG ${x264_GIT_TAG}
    CONFIGURE_COMMAND ${x264_CONFIGURE}
    BUILD_COMMAND ${x264_BUILD}
    INSTALL_COMMAND ${x264_INSTALL}
    BUILD_IN_SOURCE 1)

if(WIN32)
    # Same as x265 beside it: x264.pc says "-lx264", the MSVC build produces
    # "libx264.lib", and the toolchain turns "-lx264" into "x264.lib". Give it
    # that name rather than rewrite a pkg-config file that is otherwise right.
    ExternalProject_Add_Step(
        x264 msvc-library-name
        COMMAND ${CMAKE_COMMAND} -E copy
            ${CMAKE_INSTALL_PREFIX}/lib/libx264.lib
            ${CMAKE_INSTALL_PREFIX}/lib/x264.lib
        DEPENDEES install)
endif()
