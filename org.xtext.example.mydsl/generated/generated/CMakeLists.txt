cmake_minimum_required(VERSION 3.16)
project(TestModel)

set(CMAKE_CXX_STANDARD 17)

add_executable(TestModel
    src/main.cpp
    src/Person.cpp
    src/Employee.cpp
)

target_include_directories(TestModel PRIVATE include)
