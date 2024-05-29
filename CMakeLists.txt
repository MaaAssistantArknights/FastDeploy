cmake_minimum_required(VERSION 3.20)
project(fastdeploy_ppocr CXX)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake")

find_package(OpenCV COMPONENTS core imgproc)
find_package(onnxruntime REQUIRED)
find_package(Eigen3 REQUIRED)
message("OpenCV_LIBS: ${OpenCV_LIBS} ${OPENCV_core_FOUND} ${OPENCV_WORLD_FOUND}")

option(WITH_CUDA "Whether WITH_GPU=ON, will enable onnxruntime-gpu/paddle-infernce-gpu/poros-gpu" OFF)

if(WITH_CUDA)
    add_definitions (-Wno-format-security)
    enable_language(CUDA)
    include(cmake/cuda.cmake)
    message(STATUS "CUDA compiler: ${CMAKE_CUDA_COMPILER}, version: ${CMAKE_CUDA_COMPILER_ID} ${CMAKE_CUDA_COMPILER_VERSION}")
    add_definitions(-DWITH_GPU)
    add_definitions(-DENABLE_CUDA_PREPROCESS)
    find_library(CUDA_LIB cudart ${CUDA_DIRECTORY}/lib64)
    include_directories(PRIVATE ${CUDA_DIRECTORY}/include)
endif()

option(PRINT_LOG "Print more debug log while running" OFF)
if(PRINT_LOG)
    add_definitions(-DPRINT_LOG)
endif()

add_library(FastDeploy_Core OBJECT
    fastdeploy/core/allocate.cc
    fastdeploy/core/fd_tensor.cc
    fastdeploy/core/fd_type.cc
    fastdeploy/fastdeploy_model.cc
    fastdeploy/runtime.cc
    fastdeploy/utils/utils.cc
    fastdeploy/backends/common/multiclass_nms.cc
)
target_compile_definitions(FastDeploy_Core PRIVATE ENABLE_ORT_BACKEND)
target_include_directories(FastDeploy_Core PUBLIC 
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>  # for build
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDE}>  # for install
)
target_link_libraries(FastDeploy_Core PRIVATE onnxruntime::onnxruntime)

set(BACKEND_ONNXRUNTIME_SRC
    fastdeploy/backends/ort/ops/adaptive_pool2d.cc
    fastdeploy/backends/ort/ops/multiclass_nms.cc
    fastdeploy/backends/ort/ort_backend.cc
    fastdeploy/backends/ort/utils.cc
)
if(WITH_CUDA)
    list(APPEND BACKEND_ONNXRUNTIME_SRC
        fastdeploy/backends/op_cuda_kernels/adaptive_pool2d_kernel.cu
    )
endif()
add_library(FastDeploy_Backend_ONNXRuntime OBJECT ${BACKEND_ONNXRUNTIME_SRC})
target_include_directories(FastDeploy_Backend_ONNXRuntime PUBLIC ${onnxruntime_INCLUDE_DIRS}) 
target_link_libraries(FastDeploy_Backend_ONNXRuntime PRIVATE FastDeploy_Core onnxruntime::onnxruntime)
if(WITH_CUDA)
    target_link_libraries(FastDeploy_Backend_ONNXRuntime PRIVATE ${CUDA_LIB})
endif()

set(TENSORFUNCTION_SRC
    fastdeploy/function/cast.cc
    fastdeploy/function/clip.cc
    fastdeploy/function/concat.cc
    fastdeploy/function/cumprod.cc
    fastdeploy/function/eigen.cc
    fastdeploy/function/elementwise.cc
    fastdeploy/function/full.cc
    fastdeploy/function/gather_scatter_along_axis.cc
    fastdeploy/function/gaussian_random.cc
    fastdeploy/function/isfinite.cc
    fastdeploy/function/linspace.cc
    fastdeploy/function/math.cc
    fastdeploy/function/pad.cc
    fastdeploy/function/quantile.cc
    fastdeploy/function/reduce.cc
    fastdeploy/function/slice.cc
    fastdeploy/function/softmax.cc
    fastdeploy/function/sort.cc
    fastdeploy/function/split.cc
    fastdeploy/function/tile.cc
    fastdeploy/function/transpose.cc
)
if(WITH_CUDA)
    list(APPEND TENSORFUNCTION_SRC
        fastdeploy/function/cuda_cast.cu
    )
endif()
# hide tensor functions from shared library
add_library(FastDeploy_TensorFunction OBJECT ${TENSORFUNCTION_SRC})
target_include_directories(FastDeploy_TensorFunction PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(FastDeploy_TensorFunction PRIVATE Eigen3::Eigen)
if(WITH_CUDA)
    target_link_libraries(FastDeploy_TensorFunction PRIVATE ${CUDA_LIB})
endif()
if(MSVC)
    set_source_files_properties(
        fastdeploy/function/reduce.cc
        PROPERTIES COMPILE_OPTIONS "/bigobj"
    )
    target_compile_definitions(FastDeploy_TensorFunction PRIVATE EIGEN_STRONG_INLINE=inline)
endif()

set(VISION_COMMON_SRC
    fastdeploy/vision/common/processors/base.cc
    fastdeploy/vision/common/processors/cast.cc
    fastdeploy/vision/common/processors/center_crop.cc
    fastdeploy/vision/common/processors/color_space_convert.cc
    fastdeploy/vision/common/processors/convert.cc
    fastdeploy/vision/common/processors/convert_and_permute.cc
    fastdeploy/vision/common/processors/crop.cc
    fastdeploy/vision/common/processors/hwc2chw.cc
    fastdeploy/vision/common/processors/limit_by_stride.cc
    fastdeploy/vision/common/processors/limit_short.cc
    fastdeploy/vision/common/processors/mat.cc
    fastdeploy/vision/common/processors/normalize.cc
    fastdeploy/vision/common/processors/normalize_and_permute.cc
    fastdeploy/vision/common/processors/pad.cc
    fastdeploy/vision/common/processors/pad_to_size.cc
    fastdeploy/vision/common/processors/proc_lib.cc
    fastdeploy/vision/common/processors/resize.cc
    fastdeploy/vision/common/processors/resize_by_short.cc
    fastdeploy/vision/common/processors/stride_pad.cc
    fastdeploy/vision/common/processors/transform.cc
    fastdeploy/vision/common/processors/utils.cc
    fastdeploy/vision/common/processors/warp_affine.cc
    fastdeploy/vision/common/result.cc
)
if(WITH_CUDA)
    list(APPEND VISION_COMMON_SRC
        fastdeploy/vision/common/processors/normalize_and_permute.cu
    )
endif()
add_library(FastDeploy_Vision_Common OBJECT ${VISION_COMMON_SRC})
if(WITH_CUDA)
    target_link_libraries(FastDeploy_Vision_Common PRIVATE ${CUDA_LIB})
endif()
target_link_libraries(FastDeploy_Vision_Common PUBLIC FastDeploy_Core ${OpenCV_LIBS} PRIVATE FastDeploy_TensorFunction)

add_library(FastDeploy_Vision_OCR OBJECT
    fastdeploy/vision/ocr/ppocr/classifier.cc
    fastdeploy/vision/ocr/ppocr/cls_postprocessor.cc
    fastdeploy/vision/ocr/ppocr/cls_preprocessor.cc
    fastdeploy/vision/ocr/ppocr/dbdetector.cc
    fastdeploy/vision/ocr/ppocr/det_postprocessor.cc
    fastdeploy/vision/ocr/ppocr/det_preprocessor.cc
    fastdeploy/vision/ocr/ppocr/ppocr_v2.cc
    fastdeploy/vision/ocr/ppocr/rec_postprocessor.cc
    fastdeploy/vision/ocr/ppocr/rec_preprocessor.cc
    fastdeploy/vision/ocr/ppocr/recognizer.cc
    fastdeploy/vision/ocr/ppocr/utils/clipper.cc
    fastdeploy/vision/ocr/ppocr/utils/get_rotate_crop_image.cc
    fastdeploy/vision/ocr/ppocr/utils/ocr_postprocess_op.cc
    fastdeploy/vision/ocr/ppocr/utils/sorted_boxes.cc
)
target_link_libraries(FastDeploy_Vision_OCR PUBLIC FastDeploy_Vision_Common ${OpenCV_LIBS} PRIVATE FastDeploy_TensorFunction)

# export symbols
set_target_properties(FastDeploy_Core FastDeploy_Vision_OCR FastDeploy_Backend_ONNXRuntime PROPERTIES COMPILE_DEFINITIONS FASTDEPLOY_LIB)

# https://gitlab.kitware.com/cmake/cmake/-/issues/18090
# https://gitlab.kitware.com/cmake/cmake/-/issues/18935
add_library(fastdeploy_ppocr
    $<TARGET_OBJECTS:FastDeploy_Vision_OCR>
    $<TARGET_OBJECTS:FastDeploy_Vision_Common>
    $<TARGET_OBJECTS:FastDeploy_Core>
    $<TARGET_OBJECTS:FastDeploy_Backend_ONNXRuntime>
    $<TARGET_OBJECTS:FastDeploy_TensorFunction>
)
set_target_properties(
    fastdeploy_ppocr
    FastDeploy_Core
    FastDeploy_Backend_ONNXRuntime
    FastDeploy_TensorFunction
    FastDeploy_Vision_Common
    FastDeploy_Vision_OCR
    PROPERTIES
        CXX_STANDARD 17
)
target_link_libraries(fastdeploy_ppocr PUBLIC ${OpenCV_LIBS} PRIVATE onnxruntime::onnxruntime)
if(WITH_GPU)
    target_link_libraries(fastdeploy_ppocr PRIVATE ${CUDA_LIB})
endif()
if(ANDROID)
  target_link_libraries(fastdeploy_ppocr PRIVATE log)
endif()

install(TARGETS fastdeploy_ppocr EXPORT fastdeploy_ppocrConfig)
install(EXPORT fastdeploy_ppocrConfig DESTINATION share/fastdeploy_ppocr)
install(
  DIRECTORY ${PROJECT_SOURCE_DIR}/fastdeploy
  DESTINATION ${CMAKE_INSTALL_PREFIX}/include
  FILES_MATCHING
  PATTERN "*.h"
)
