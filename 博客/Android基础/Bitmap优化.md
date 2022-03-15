# Bitmap优化

##### Bitmap描述

Bitmap图像处理的最重要类之一。用它可以获取图像文件信息并且可以进行编程操作。

##### Bitmap基本功能

![img](https://user-gold-cdn.xitu.io/2017/9/11/e82bec15af4300ac374373316f25cbe1?imageView2/0/w/1280/h/960/format/webp/ignore-error/1)



##### Bitmap占用多少内存

计算内存大小:图片像素宽x图片像素高x一个像素点占用的字节数(90%准确) 

##### Config解析

- Bitmap.Config.ALPHA_8：每个像素存储为单个半透明（alpha）通道。没有存储颜色信息。使用此配置，每个像素需要1个字节的内存
- Bitmap.Config.ARGB_4444:API级别29中不建议使用该字段。由于此配置的质量较差，建议改用ARGB_8888。
- Bitmap.Config.ARGB_8888:每个像素存储在4个字节上。每个通道（RGB和alpha表示半透明）以8位精度（256个可能的值）进行存储。此配置非常灵活，可提供最佳质量。应尽可能使用它
- Bitmap.Config.RGBA_F16:每个像素存储在8个字节上。每个通道（半透明的RGB和alpha）都存储为半精度浮点值。此配置特别适合于广色域和HDR内容。
- Bitmap.Config.565:每个像素存储在2个字节上，并且仅对RGB通道进行编码：红色存储5位精度（32个可能值），绿色存储6位精度（64个可能值），蓝色存储5位精度。精确。根据源的配置，此配置可能会产生轻微的视觉伪像。例如，如果没有抖动，结果可能会显示绿色。为了获得更好的结果，应使用抖动处理。当使用不需要高色彩保真度的不透明位图时，此配置可能很有用

##### **CompressFormat解析**

- Bitmap.compressFormat.JPEG 压缩为JPEG格式。质量0表示压缩为最小大小。 100表示压缩以获得最大视觉质量。
- Bitmap.compressFormat.PNG 压缩为PNG格式。 PNG是无损的，因此质量会被忽略

**管理位图内存**

Android3.0引入了BitmapFactory.Options.inBitmap字段。如果设置了此选项，那么采用Options对象的编码方法会在加载内容时尝试重复使用现有位图。这意味着位图内存得到了重复使用，而提高了性能，同时移除了内存分配和取消分配。不过`inBitmap`的使用方式存在些某些限制。特别是在`Android4.4`之前，系统仅支持大小相同的位图。

##### Bitmap压缩方法

Bitmap.compress(CompressFormat format, int quality, OutputStream stream)方法

将位图的压缩版本写入指定的输出流。 如果返回true，则可以通过将相应的输入流传递给BitmapFactory.decodeStream（）来重构位图。 注意：并非所有格式都直接支持所有位图配置，因此从BitmapFactory返回的位图可能具有不同的位深，并且/或者可能丢失了每个像素的alpha值（例如JPEG仅支持不透明的像素）。 

| Parameters |                                                              |
| :--------- | ------------------------------------------------------------ |
| `format`   | `Bitmap.CompressFormat`: 压缩图像的格式                      |
| `quality`  | `int`: 提示压缩机，0-100。根据CompressFormat的不同，该值的压缩也不同。 |
| `stream`   | `OutputStream`: 写入压缩数据的输出流。.                      |

##### Bitmap像素压缩方式

bitmapFactory.options.inSampleSize

如果设置为大于1的值，则请求解码器对原始图像进行二次采样，返回较小的图像以节省内存。 样本大小是任一维度中与已解码位图中单个像素相对应的像素数。 例如，inSampleSize == 4返回的图像为原始宽度/高度的1/4，像素数目的1/16。 任何小于等于1的值都与1相同。注意：解码器使用基于2的幂的最终值，任何其他值将四舍五入为最接近的2的幂。

截图网络代码

```
public static Bitmap decodeSampledBitmapFromResource(Resources res, int resId,
        int reqWidth, int reqHeight) {
    // 设置inJustDecodeBounds属性为true，只获取Bitmap原始宽高，不分配内存；
    final BitmapFactory.Options options = new BitmapFactory.Options();
    options.inJustDecodeBounds = true;
    BitmapFactory.decodeResource(res, resId, options);
    // 计算inSampleSize值；
    options.inSampleSize = calculateInSampleSize(options, reqWidth, reqHeight);
    // 真实加载Bitmap；
    options.inJustDecodeBounds = false;
    return BitmapFactory.decodeResource(res, resId, options);
}

public static int calculateInSampleSize(
            BitmapFactory.Options options, int reqWidth, int reqHeight) {
    // Raw height and width of image
    final int height = options.outHeight;
    final int width = options.outWidth;
    int inSampleSize = 1;
    if (height > reqHeight || width > reqWidth) {
        final int halfHeight = height / 2;
        final int halfWidth = width / 2;
        // 宽和高比需要的宽高大的前提下最大的inSampleSize
        while ((halfHeight / inSampleSize) >= reqHeight
                && (halfWidth / inSampleSize) >= reqWidth) {
            inSampleSize *= 2;
        }
    }
    return inSampleSize;
}


```

