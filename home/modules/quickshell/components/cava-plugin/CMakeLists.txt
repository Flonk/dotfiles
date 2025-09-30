cmake_minimum_required(VERSION 3.16)

project(CavaPlugin VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Qml Quick)
find_package(PkgConfig REQUIRED)

# Find libcava
pkg_check_modules(CAVA REQUIRED cava)

# Find pipewire for audio capture
pkg_check_modules(PIPEWIRE REQUIRED libpipewire-0.3)

qt6_standard_project_setup()

qt6_add_qml_module(cavaprovider
    URI "CavaPlugin"
    VERSION 1.0
    SOURCES
        cavaprovider.cpp
        cavaprovider.h
        audiocollector.cpp  
        audiocollector.h
        microphonecavaprovider.cpp
        microphonecavaprovider.h
)

target_link_libraries(cavaprovider PRIVATE
    Qt6::Core 
    Qt6::Qml
    Qt6::Quick
    ${CAVA_LIBRARIES}
    ${PIPEWIRE_LIBRARIES}
)

target_include_directories(cavaprovider PRIVATE
    ${CAVA_INCLUDE_DIRS}
    ${PIPEWIRE_INCLUDE_DIRS}
)