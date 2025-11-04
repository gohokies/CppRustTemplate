#include <stdio.h>

#include <gtest/gtest.h>

#include <zlib.h>

TEST(ZLibTest, Version)
{ 
    ASSERT_TRUE(ZLIB_VERNUM >= 0x1300);
}
