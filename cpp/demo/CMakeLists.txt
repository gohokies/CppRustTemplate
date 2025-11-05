add_executable(CppDemo main.cpp)
target_link_libraries(CppDemo PRIVATE rust::algorithms rust::dynhelpers)

add_dependencies(CppDemo algorithms dynhelpers)
