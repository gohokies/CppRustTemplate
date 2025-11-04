#set(CARGO_BUILD_ARGS "--target-dir" ${CMAKE_CURRENT_BINARY_DIR}/target)
#
#add_custom_target(build_rust_libs
#    COMMAND ${CMAKE_COMMAND} -E echo "Building Rust libraries..."
#        cargo build ${CARGO_BUILD_ARGS} "$<IF:$<CONFIG:RELEASE>,--release,-v>"
#    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
#    VERBATIM)
add_subdirectory(algorithms)