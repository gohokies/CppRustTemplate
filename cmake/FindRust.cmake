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
        elseif(LINUX)
            set(MY_TARGET_NAME "lib${ARGS_TARGET}.so")
        else()
            set(MY_TARGET_NAME "lib${ARGS_TARGET}.dylib")
        endif()
    else()
        if (WIN32)        
            set(MY_TARGET_NAME "${ARGS_TARGET}.lib")
        else()
            set(MY_TARGET_NAME "lib${ARGS_TARGET}.a")
        endif()
    endif()

    file(GLOB_RECURSE LIB_SOURCES "${ARGS_SOURCE_DIRECTORY}/*.rs")

    set(MY_CARGO_ARGS ${CARGO_ARGS})
    list(APPEND MY_CARGO_ARGS "--target-dir" ${ARGS_BINARY_DIRECTORY})
    list(JOIN MY_CARGO_ARGS " " MY_CARGO_ARGS_STRING)

    add_custom_command(
        OUTPUT "${ARGS_BINARY_DIRECTORY}/${RUST_COMPILER_TARGET}/$<IF:$<CONFIG:DEBUG>,debug,release>/${MY_TARGET_NAME}"
        COMMAND ${CMAKE_COMMAND} -E env "RUSTFLAGS=\"${RUSTFLAGS}\"" ${cargo_EXECUTABLE} ARGS ${MY_CARGO_ARGS} "$<IF:$<CONFIG:DEBUG>,-v,--release>"
        WORKING_DIRECTORY "${ARGS_SOURCE_DIRECTORY}"
        DEPENDS ${LIB_SOURCES}
        COMMENT "Building ${ARGS_TARGET} in ${ARGS_BINARY_DIRECTORY} with:  ${cargo_EXECUTABLE} ${MY_CARGO_ARGS_STRING}")

    # Create a target from the build output
    add_custom_target(${ARGS_TARGET}_target DEPENDS "${ARGS_BINARY_DIRECTORY}/${RUST_COMPILER_TARGET}/$<IF:$<CONFIG:DEBUG>,debug,release>/${MY_TARGET_NAME}")

    # Create a static imported library target from custom target
    if (${ARGS_SHARED})
        add_library(${ARGS_TARGET} SHARED IMPORTED GLOBAL)
    else()
        add_library(${ARGS_TARGET} STATIC IMPORTED GLOBAL)
    endif()
    add_dependencies(${ARGS_TARGET} ${ARGS_TARGET}_target)
    target_link_libraries(${ARGS_TARGET} INTERFACE ${RUST_NATIVE_STATIC_LIBS})
    if (WIN32)
        target_link_libraries(${ARGS_TARGET} INTERFACE Ws2_32.lib Ntdll.lib userenv.lib)
    endif()
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
            IMPORTED_IMPLIB_DEBUG "${ARGS_BINARY_DIRECTORY}/${RUST_COMPILER_TARGET}/debug/${MY_TARGET_NAME}.lib"
            IMPORTED_IMPLIB_RELEASE "${ARGS_BINARY_DIRECTORY}/${RUST_COMPILER_TARGET}/release/${MY_TARGET_NAME}.lib"
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


# Determine the native libs required to link w/ rust static libs
# message(STATUS "Detecting native static libs for rust: ${rustc_EXECUTABLE} --crate-type staticlib --print=native-static-libs /dev/null")
execute_process(
    COMMAND ${CMAKE_COMMAND} -E env "CARGO_TARGET_DIR=${CMAKE_BINARY_DIR}" ${rustc_EXECUTABLE} --crate-type staticlib --print=native-static-libs /dev/null
    OUTPUT_VARIABLE RUST_NATIVE_STATIC_LIBS_OUTPUT
    ERROR_VARIABLE RUST_NATIVE_STATIC_LIBS_ERROR
    RESULT_VARIABLE RUST_NATIVE_STATIC_LIBS_RESULT
)
string(REGEX REPLACE "\r?\n" ";" LINE_LIST "${RUST_NATIVE_STATIC_LIBS_ERROR}")

foreach(LINE ${LINE_LIST})
    # do the match on each line
    string(REGEX MATCH "native-static-libs: .*" LINE "${LINE}")

    if(NOT LINE)
        continue()
    endif()

    string(REPLACE "native-static-libs: " "" LINE "${LINE}")
    string(REGEX REPLACE "  " "" LINE "${LINE}")
    string(REGEX REPLACE " " ";" LINE "${LINE}")

    if(LINE)
        message(STATUS "Rust's native static libs: ${LINE}")
        set(RUST_NATIVE_STATIC_LIBS "${LINE}")
        break()
    endif()
endforeach()

if(NOT RUST_COMPILER_TARGET)
    # Automatically determine the Rust Target Triple.
    # Note: Users may override automatic target detection by specifying their own. Most likely needed for cross-compiling.
    # For reference determining target platform: https://doc.rust-lang.org/nightly/rustc/platform-support.html
    if(WIN32)
        # For windows x86/x64, it's easy enough to guess the target.
        if(CMAKE_SIZEOF_VOID_P EQUAL 8)
            set(RUST_COMPILER_TARGET "x86_64-pc-windows-msvc")
        else()
            set(RUST_COMPILER_TARGET "i686-pc-windows-msvc")
        endif()
    elseif(CMAKE_SYSTEM_NAME STREQUAL Darwin AND "${CMAKE_OSX_ARCHITECTURES}" MATCHES "^(arm64;x86_64|x86_64;arm64)$")
        # Special case for Darwin because we may want to build universal binaries.
        set(RUST_COMPILER_TARGET "universal-apple-darwin")
    else()
        # Determine default LLVM target triple.
        execute_process(COMMAND ${rustc_EXECUTABLE} -vV
            OUTPUT_VARIABLE RUSTC_VV_OUT ERROR_QUIET)
        string(REGEX REPLACE "^.*host: ([a-zA-Z0-9_\\-]+).*" "\\1" DEFAULT_RUST_COMPILER_TARGET1 "${RUSTC_VV_OUT}")
        string(STRIP ${DEFAULT_RUST_COMPILER_TARGET1} DEFAULT_RUST_COMPILER_TARGET)

        set(RUST_COMPILER_TARGET "${DEFAULT_RUST_COMPILER_TARGET}")
    endif()
endif()

set(CARGO_ARGS "build")

if(NOT "${RUST_COMPILER_TARGET}" MATCHES "^universal-apple-darwin$")
    # Don't specify the target for macOS universal builds, we'll do that manually for each build.
    list(APPEND CARGO_ARGS "--target" ${RUST_COMPILER_TARGET})
endif()

set(RUSTFLAGS "")

find_package_handle_standard_args(Rust
    REQUIRED_VARS cargo_EXECUTABLE
    VERSION_VAR cargo_VERSION
)
