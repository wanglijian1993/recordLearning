rm -r build
mkdir build
cd build
#设置交叉编译的参数
cmake -DANDROID_NDK=${NDK_PATH} \
	    -DCMAKE_TOOLCHAIN_FILE=${NDK_PATH}/build/cmake/android.toolchain.cmake \
	    -DANDROID_ABI="arm64-v8a" \
        -DANDROID_NATIVE_API_LEVEL=21 \
        ..
        
make