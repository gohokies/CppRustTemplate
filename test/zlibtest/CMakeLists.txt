find_package(ZLIB REQUIRED)
 
add_executable(ZLibTest main.cpp)

target_link_libraries(ZLibTest PRIVATE GTest::gtest GTest::gtest_main ZLIB::ZLIB)

add_test(ZLibTest ZLibTest)
