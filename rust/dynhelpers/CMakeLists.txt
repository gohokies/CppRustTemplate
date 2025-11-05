add_rust_library(SHARED
    TARGET dynhelpers
    SOURCE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    BINARY_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
)

add_library(rust::dynhelpers ALIAS dynhelpers)