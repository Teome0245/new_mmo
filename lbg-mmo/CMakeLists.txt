cmake_minimum_required(VERSION 3.10)
project(LBG-MMO)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)

# Add subdirectories
find_package(PkgConfig REQUIRED)
pkg_check_modules(LUA REQUIRED lua5.3)
pkg_check_modules(MYSQL REQUIRED mariadb)
include_directories(${LUA_INCLUDE_DIRS} ${MYSQL_INCLUDE_DIRS})
link_libraries(${MYSQL_LIBRARIES})

add_subdirectory(MMOEngine)
add_subdirectory(server-core3)
