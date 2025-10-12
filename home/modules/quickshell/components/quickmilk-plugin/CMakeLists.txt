cmake_minimum_required(VERSION 3.16)

project(QuickmilkPlugin VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Qml Quick)
find_package(PkgConfig REQUIRED)

# Find FFTW (double precision)
pkg_check_modules(FFTW REQUIRED fftw3)

# Find pipewire for audio capture
pkg_check_modules(PIPEWIRE REQUIRED libpipewire-0.3)

qt6_standard_project_setup()

qt6_add_qml_module(quickmilk
    URI "Quickmilk"
    VERSION 1.0
    QML_FILES
        Quickmilk.qml
    SOURCES
        quickmilk.cpp
        quickmilk.h
        audiocollector.cpp
        audiocollector.h
        datatexture.cpp
        datatexture.h
        spectrumanalyzer.cpp
        spectrumanalyzer.h
        visualizereffects.cpp
        visualizereffects.h
)

target_link_libraries(quickmilk PRIVATE
    Qt6::Core 
    Qt6::Qml
    Qt6::Quick
    ${PIPEWIRE_LIBRARIES}
    ${FFTW_LIBRARIES}
)

target_include_directories(quickmilk PRIVATE
    ${PIPEWIRE_INCLUDE_DIRS}
    ${FFTW_INCLUDE_DIRS}
)