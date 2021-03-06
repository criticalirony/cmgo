
function (add_go_executable _TARGET_NAME)
    set (options)
    set (oneValueArgs "PACAKGE;OUTPUT_DIR;OUTPUT_NAME")
    set (multiValueArgs "FLAGS")

    cmake_parse_arguments(PARSE_ARGV 1 _ADD_GO
        "${options}"
        "${oneValueArgs}"
        "${multiValueArgs}"
    )

    if (NOT DEFINED _ADD_GO_PACKAGE)
        set (_ADD_GO_PACKAGE ${CMAKE_CURRENT_SOURCE_DIR})
    endif()

    if (NOT DEFINED _ADD_GO_OUTPUT_DIR)
        set (_ADD_GO_OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR})
    else()
        get_filename_component(_ADD_GO_OUTPUT_DIR ${_ADD_GO_OUTPUT_DIR} ABSOLUTE)
    endif()

    # ensure output directory exists
    file (MAKE_DIRECTORY "${_ADD_GO_OUTPUT_DIR}")

    if (NOT DEFINED _ADD_GO_OUTPUT_NAME)
        set (_GO_TARGET_OUTPUT_NAME "${_TARGET_NAME}")
    else()
        set (_GO_TARGET_OUTPUT_NAME "${_ADD_GO_OUTPUT_NAME}")
    endif()
    
    execute_process(COMMAND pwd
        OUTPUT_VARIABLE _out
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    execute_process(COMMAND ${Golang_GO_EXECUTABLE} list -f "{{.Dir}}" ${_ADD_GO_PACKAGE}
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        OUTPUT_VARIABLE _GO_PACKAGE_DIR
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_VARIABLE err
        ERROR_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE res
    )

    if (res)
        message(FATAL_ERROR "Failed to: go list: ${err}")
    endif ()

    file(GLOB _GO_PACKAGE_FILES ${_GO_PACKAGE_DIR}/*.go)
    
    execute_process(COMMAND ${Golang_GO_EXECUTABLE} list -f "{{ join .Deps \";\" }}" ${_ADD_GO_PACKAGE}
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        OUTPUT_VARIABLE _GO_PACKAGE_DEPS
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_VARIABLE err
        ERROR_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE res
        # COMMAND_ECHO STDERR
    )

    if (res)
        message(FATAL_ERROR "Failed to: go list: ${err}")
    endif ()

    set(_GO_PACKAGE_DEPS_FILES "")
    foreach(item IN LISTS _GO_PACKAGE_DEPS)
        execute_process(COMMAND ${Golang_GO_EXECUTABLE} list -f "dir:{{.Dir}};std:{{.Standard}};" ${item}
            WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
            OUTPUT_VARIABLE _item_package_dir
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_VARIABLE err
            ERROR_STRIP_TRAILING_WHITESPACE
            RESULT_VARIABLE res
        )

        # set (_golang_dep_package_dir_regex [[(go([0-9]+)(\.([0-9]+)(\.([0-9]+))?)?.*)]])
        set (_golang_dep_package_dir_regex [[dir:(.+);std:(.+);.*]])
        if (_item_package_dir MATCHES "${_golang_dep_package_dir_regex}")
            set (_item_package_dir_dir "${CMAKE_MATCH_1}")
            set (_item_package_dir_std "${CMAKE_MATCH_2}")
        endif()

        if (_item_package_dir_std STREQUAL "true")
            continue()
        endif()

        execute_process(COMMAND ${Golang_GO_EXECUTABLE} list -f "{{ join .GoFiles \" \" }}" ${item}
            WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
            OUTPUT_VARIABLE _item_package_files
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_VARIABLE err
            ERROR_STRIP_TRAILING_WHITESPACE
            RESULT_VARIABLE res
        )

        foreach(file_item IN LISTS _item_package_files)
            list(APPEND _GO_PACKAGE_DEPS_FILES "${_item_package_dir_dir}/${file_item}")
        endforeach()
    endforeach()

    set(CMAKE_GO_OBJ_OUTPUT_PATH "${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${_TARGET_NAME}.dir")

    add_custom_command(
        OUTPUT "${_ADD_GO_OUTPUT_DIR}/${_GO_TARGET_OUTPUT_NAME}"
        COMMAND ${Golang_GO_EXECUTABLE} build -v -x ${_ADD_GO_FLAGS} -o "${_ADD_GO_OUTPUT_DIR}/${_GO_TARGET_OUTPUT_NAME}"
        DEPENDS ${_GO_PACKAGE_FILES} ${_GO_PACKAGE_DEPS_FILES}
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        COMMENT "Building Golang objects for ${_TARGET_NAME}"
    )

    add_custom_target(${_TARGET_NAME} ALL DEPENDS "${_ADD_GO_OUTPUT_DIR}/${_GO_TARGET_OUTPUT_NAME}")

    set_property(
        TARGET
            ${_TARGET_NAME}
        PROPERTY
            INSTALL_FILES
                "${_ADD_GO_OUTPUT_DIR}/${_GO_TARGET_OUTPUT_NAME}"
    )
endfunction()