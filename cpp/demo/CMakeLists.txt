add_executable(CppDemo main.cpp)
target_link_libraries(CppDemo PRIVATE rust::algorithms)

add_dependencies(CppDemo algorithms)
#find_library(RustAlgorithmsLib NAMES algorithms PATHS ${CMAKE_BINARY_DIR}/rust/target/$<IF:$<CONFIG:DEBUG>,debug,release> OUTPUT_VARIABLE RUST_LIB_FOUND)
#if (NOT RustAlgorithmsLib)
#    message(FATAL_ERROR "Could not find Rust algorithms library")
#endif()
