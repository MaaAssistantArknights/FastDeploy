# Copyright (c) 2022 PaddlePaddle Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

cmake_minimum_required(VERSION 3.24)
set(WITH_STATIC ON)
set(MSVC_STATIC_CRT OFF)
add_subdirectory(${Paddle2ONNX_SRC} paddle2onnx EXCLUDE_FROM_ALL)
add_library(external_paddle2onnx INTERFACE)
target_include_directories(external_paddle2onnx INTERFACE ${Paddle2ONNX_SRC})
target_link_libraries(external_paddle2onnx INTERFACE "$<LINK_LIBRARY:WHOLE_ARCHIVE,paddle2onnx>")
