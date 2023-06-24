find_path(onnxruntime_INCLUDE_DIR NAMES onnxruntime_c_api.h PATH_SUFFIXES onnxruntime onnxruntime/core/session)

find_library(onnxruntime_LIBRARY NAMES onnxruntime)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(
    onnxruntime
    REQUIRED_VARS onnxruntime_LIBRARY onnxruntime_INCLUDE_DIR
)

if(onnxruntime_FOUND)
    set(onnxruntime_INCLUDE_DIRS "${onnxruntime_INCLUDE_DIR}")
    if(NOT TARGET onnxruntime::onnxruntime)
        add_library(onnxruntime::onnxruntime UNKNOWN IMPORTED)
        set_target_properties(onnxruntime::onnxruntime PROPERTIES
            IMPORTED_LOCATION "${onnxruntime_LIBRARY}"
            INTERFACE_INCLUDE_DIRECTORIES "${onnxruntime_INCLUDE_DIRS}"
        )
    endif()
endif()
