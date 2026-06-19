cmake_minimum_required(VERSION 3.16)
project(kwin_fancyzones)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
# KWIN_EFFECT_FACTORY expands to a Q_OBJECT class; AUTOMOC must recognize it.
list(APPEND CMAKE_AUTOMOC_MACRO_NAMES
    KWIN_EFFECT_FACTORY KWIN_EFFECT_FACTORY_ENABLED
    KWIN_EFFECT_FACTORY_SUPPORTED KWIN_EFFECT_FACTORY_SUPPORTED_ENABLED)

find_package(ECM REQUIRED NO_MODULE)
list(APPEND CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
include(KDEInstallDirs)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets DBus Quick Qml)
find_package(KF6 REQUIRED COMPONENTS CoreAddons)
find_package(KWin REQUIRED)

add_library(fancyzones MODULE fancyzoneseffect.cpp)
set_target_properties(fancyzones PROPERTIES PREFIX "")
target_link_libraries(fancyzones
    KWin::kwin
    Qt6::Core
    Qt6::Gui
    KF6::CoreAddons
)

# KWin discovers out-of-tree effects from the Qt plugin dir, under kwin/effects/plugins.
install(TARGETS fancyzones
    DESTINATION ${KDE_INSTALL_QTPLUGINDIR}/kwin/effects/plugins/)
