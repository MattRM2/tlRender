include(ExternalProject)

find_package(Msys REQUIRED)

# The MSYS2 packages that the shell built projects here need: FFmpeg, x264 and
# libvpx all run a configure script through MSYS2 and all want the same tools.
#
# Installing them once, from a project the three depend on, rather than at the
# top of each configure command. pacman takes a lock on its database and
# refuses to start while another copy holds it, so two of those projects
# configuring at the same time -- which is exactly what a parallel superbuild
# does -- fails with "unable to lock database: File exists" from whichever
# lost. Nothing about that message points at the build that provoked it.
set(msys_packages_MSYS2 ${MSYS_CMD} -use-full-path -defterm -no-start -here)
set(msys_packages_SRC ${CMAKE_CURRENT_BINARY_DIR}/msys-packages/src)

ExternalProject_Add(
    msys-packages
    PREFIX ${CMAKE_CURRENT_BINARY_DIR}/msys-packages
    SOURCE_DIR ${msys_packages_SRC}
    DOWNLOAD_COMMAND ${CMAKE_COMMAND} -E make_directory ${msys_packages_SRC}
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ${msys_packages_MSYS2} -c "pacman -S diffutils make nasm pkgconf --noconfirm"
    INSTALL_COMMAND ""
    BUILD_IN_SOURCE 1)
