find_package(OpenCL REQUIRED)

add_executable(OpenCLTest main.cpp)

target_link_libraries(OpenCLTest PRIVATE GTest::gtest GTest::gtest_main OpenCL::OpenCL)

add_test(OpenCLTest OpenCLTest)
