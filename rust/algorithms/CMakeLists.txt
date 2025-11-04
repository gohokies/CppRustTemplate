add_rust_library(
    TARGET algorithms
    SOURCE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    BINARY_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
)

add_library(rust::algorithms ALIAS algorithms)