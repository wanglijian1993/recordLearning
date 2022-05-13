rm -rf build 
mkdir build
cd build
#设置交叉编译的参数
cmake DANDROID_NDK=${NDK} \
        .DCHAKE_TOOLCHAIN_FILE=${NDK_PATH}/build/cmake/ndroid.toolchain.cmake \
        -DANDROID_ABI="armeabi-v8a" \
        -DANDROID_NATIVE_API_LEVEL=21 \
        ..

make
