if(NOT DEFINED CARGO_HOME)
    if(WIN32)
        set(CARGO_HOME "$ENV{USERPROFILE}/.cargo")
    else()
        set(CARGO_HOME "$ENV{HOME}/.cargo")
    endif()
endif()

include(FindPackageHandleStandardArgs)

function(find_rust_program RUST_PROGRAM)
    find_program(${RUST_PROGRAM}_EXECUTABLE ${RUST_PROGRAM}
        HINTS "${CARGO_HOME}"
        PATH_SUFFIXES "bin"
    )

    if(${RUST_PROGRAM}_EXECUTABLE)
        execute_process(COMMAND "${${RUST_PROGRAM}_EXECUTABLE}" --version
            OUTPUT_VARIABLE ${RUST_PROGRAM}_VERSION_OUTPUT
            ERROR_VARIABLE ${RUST_PROGRAM}_VERSION_ERROR
            RESULT_VARIABLE ${RUST_PROGRAM}_VERSION_RESULT
        )

        if(NOT ${${RUST_PROGRAM}_VERSION_RESULT} EQUAL 0)
            message(STATUS "Rust tool `${RUST_PROGRAM}` not found: Failed to determine version.")
            unset(${RUST_PROGRAM}_EXECUTABLE)
        else()
            string(REGEX
                MATCH "[0-9]+\\.[0-9]+(\\.[0-9]+)?(-nightly)?"
                ${RUST_PROGRAM}_VERSION "${${RUST_PROGRAM}_VERSION_OUTPUT}"
            )
            set(${RUST_PROGRAM}_VERSION "${${RUST_PROGRAM}_VERSION}" PARENT_SCOPE)
            message(STATUS "Rust tool `${RUST_PROGRAM}` found: ${${RUST_PROGRAM}_EXECUTABLE}, ${${RUST_PROGRAM}_VERSION}")
        endif()

        mark_as_advanced(${RUST_PROGRAM}_EXECUTABLE ${RUST_PROGRAM}_VERSION)
    else()
        message(STATUS "Rust tool `${RUST_PROGRAM}` not found.")
    endif()
endfunction()

function(add_rust_library)
    set(options SHARED)
    set(oneValueArgs TARGET SOURCE_DIRECTORY BINARY_DIRECTORY PRECOMPILE_TESTS)
    set(multiValueArgs)
    cmake_parse_arguments(ARGS "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if (${ARGS_SHARED})        
        if(WIN32)
            set(MY_TARGET_NAME "${ARGS_TARGET}.dll")
            set(MY_LIB_NAME "${ARGS_TARGET}.dll.lib")
        elseif(LINUX)
            set(MY_TARGET_NAME "lib${ARGS_TARGET}.so")
            set(MY_LIB_NAME "lib${ARGS_TARGET}.so")
        else()
            set(MY_TARGET_NAME "lib${ARGS_TARGET}.dylib")
            set(MY_LIB_NAME "lib${ARGS_TARGET}.dylib")
        endif()
    else()
        if (WIN32)        
            set(MY_TARGET_NAME "${ARGS_TARGET}.lib")
            set(MY_LIB_NAME "${ARGS_TARGET}.lib")
        else()
            set(MY_TARGET_NAME "lib${ARGS_TARGET}.a")
            set(MY_LIB_NAME "lib${ARGS_TARGET}.a")
        endif()
    endif()

    file(GLOB_RECURSE LIB_SOURCES "${ARGS_SOURCE_DIRECTORY}/*.rs")

    set(MY_CARGO_ARGS "build")
    list(APPEND MY_CARGO_ARGS "--target" ${RUST_COMPILER_TARGET})
    list(APPEND MY_CARGO_ARGS "--target-dir" ${ARGS_BINARY_DIRECTORY})
    list(JOIN MY_CARGO_ARGS " " MY_CARGO_ARGS_STRING)

    add_custom_command(
        OUTPUT "${ARGS_BINARY_DIRECTORY}/${RUST_COMPILER_TARGET}/$<IF:$<CONFIG:DEBUG>,debug,release>/${MY_LIB_NAME}"
        COMMAND ${CMAKE_COMMAND} -E env "RUSTFLAGS=\"${RUSTFLAGS}\"" ${cargo_EXECUTABLE} ARGS ${MY_CARGO_ARGS} "$<IF:$<CONFIG:DEBUG>,-v,--release>"
        WORKING_DIRECTORY "${ARGS_SOURCE_DIRECTORY}"
        DEPENDS ${LIB_SOURCES}
        COMMENT "Building ${ARGS_TARGET} in ${ARGS_BINARY_DIRECTORY} with: ${cargo_EXECUTABLE} ${MY_CARGO_ARGS_STRING}")

    # Create a target from the build output
    add_custom_target(${ARGS_TARGET}_target DEPENDS "${ARGS_BINARY_DIRECTORY}/${RUST_COMPILER_TARGET}/$<IF:$<CONFIG:DEBUG>,debug,release>/${MY_LIB_NAME}")

    # Create a static imported library target from custom target
    if (${ARGS_SHARED})
        add_library(${ARGS_TARGET} SHARED IMPORTED GLOBAL)
    else()
        add_library(${ARGS_TARGET} STATIC IMPORTED GLOBAL)
    endif()
    add_dependencies(${ARGS_TARGET} ${ARGS_TARGET}_target)
    target_link_libraries(${ARGS_TARGET} INTERFACE ${RUST_DEFAULT_LIBS})
    set_property(TARGET ${ARGS_TARGET} APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG RELEASE)
    set_target_properties(${ARGS_TARGET} PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${ARGS_SOURCE_DIRECTORY};${ARGS_BINARY_DIRECTORY}"
        IMPORTED_LINK_INTERFACE_LANGUAGES_DEBUG "CXX"
        IMPORTED_LOCATION_DEBUG "${ARGS_BINARY_DIRECTORY}/${RUST_COMPILER_TARGET}/debug/${MY_TARGET_NAME}"
        IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "CXX"
        IMPORTED_LOCATION_RELEASE "${ARGS_BINARY_DIRECTORY}/${RUST_COMPILER_TARGET}/release/${MY_TARGET_NAME}"
        )
    if (WIN32 AND ${ARGS_SHARED})
        set_target_properties(${ARGS_TARGET} PROPERTIES
            IMPORTED_IMPLIB_DEBUG "${ARGS_BINARY_DIRECTORY}/${RUST_COMPILER_TARGET}/debug/${MY_LIB_NAME}"
            IMPORTED_IMPLIB_RELEASE "${ARGS_BINARY_DIRECTORY}/${RUST_COMPILER_TARGET}/release/${MY_LIB_NAME}"
        )
    endif()
endfunction()

function(add_rust_test)
    set(options)
    set(oneValueArgs NAME SOURCE_DIRECTORY BINARY_DIRECTORY PRECOMPILE_TESTS DEPENDS)
    set(multiValueArgs ENVIRONMENT)
    cmake_parse_arguments(ARGS "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    set(MY_CARGO_ARGS "test")

    if("${CMAKE_BUILD_TYPE}" STREQUAL "Release")
        list(APPEND MY_CARGO_ARGS "--release")
    endif()

    list(APPEND MY_CARGO_ARGS "--target-dir" ${ARGS_BINARY_DIRECTORY})
    list(JOIN MY_CARGO_ARGS " " MY_CARGO_ARGS_STRING)

    add_test(
        NAME ${ARGS_NAME}
        COMMAND ${CMAKE_COMMAND} -E env "CARGO_CMD=test" "CARGO_TARGET_DIR=${ARGS_BINARY_DIRECTORY}" ${cargo_EXECUTABLE} ${MY_CARGO_ARGS} --color always
        WORKING_DIRECTORY ${ARGS_SOURCE_DIRECTORY}
    )
endfunction()

find_rust_program(cargo)
find_rust_program(rustc)

if (WIN32)
    set(RUST_DEFAULT_LIBS "kernel32.lib;ntdll.lib;userenv.lib;ws2_32.lib;dbghelp.lib")
elseif (LINUX)
    set(RUST_DEFAULT_LIBS "-lgcc_s;-lutil;-lrt;-lpthread;-lm;-ldl;-lc")
else()
    set(RUST_DEFAULT_LIBS "-lSystem;-lc;-lm")
endif()

if(NOT RUST_COMPILER_TARGET)
    if(WIN32)
        if ("$ENV{PROCRSSOR_ARCHITECTURE}" STREQUAL "ARM64")
            set(RUST_COMPILER_TARGET "aarch64-pc-windows-msvc")
        else()
            set(RUST_COMPILER_TARGET "x86_64-pc-windows-msvc")
        endif()
    else()
        execute_process(COMMAND ${rustc_EXECUTABLE} -vV
            OUTPUT_VARIABLE RUSTC_VV_OUT ERROR_QUIET)
        string(REGEX REPLACE "^.*host: ([a-zA-Z0-9_\\-]+).*" "\\1" DEFAULT_RUST_COMPILER_TARGET1 "${RUSTC_VV_OUT}")
        string(STRIP ${DEFAULT_RUST_COMPILER_TARGET1} DEFAULT_RUST_COMPILER_TARGET)

        set(RUST_COMPILER_TARGET "${DEFAULT_RUST_COMPILER_TARGET}")
    endif()
    message(STATUS "Determining Rust target triple: ${RUST_COMPILER_TARGET}")
endif()

set(RUSTFLAGS "")

find_package_handle_standard_args(Rust
    REQUIRED_VARS cargo_EXECUTABLE
    VERSION_VAR cargo_VERSION
)
