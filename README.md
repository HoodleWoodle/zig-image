# zig-image library

This is a library (WIP) to create, process, read and write different image formats with [Zig](https://ziglang.org/) programming language.

## Install & Build

This library assumes Zig v0.11.0.

## Supported image formats

| Image Format  | Read          | Write          |
| ------------- |:-------------:|:--------------:|
| BMP           | ✔️ (WIP)      | ❌             |
| PNG           | ✔️ (Upcoming) | ❌             |

### BMP - Bitmap

| DIB Header        | Supported     | Implemented    |
| ----------------- |:-------------:|:--------------:|
| OS21XBITMAPHEADER | ❌            |                |
| OS22XBITMAPHEADER | ❌            |                |
| BitmapInfoHeader  | ✔️            | ✔️             |
| BitmapV2Header    | ❌            |                |
| BitmapV3Header    | ✔️            | ✔️             |
| BitmapV4Header    | ✔️            | ❌             |
| BitmapV5Header    | ✔️            | ❌             |

| Compression Format  | Supported     | Implemented    |
| ------------------- |:-------------:|:--------------:|
| BI_RGB              | ✔️            | ✔️             |
| BI_RLE8             | ✔️            | ❌             |
| BI_RLE4             | ✔️            | ❌             |
| BI_BITFIELDS        | ✔️            | ✔️             |
| BI_JPEG             | ✔️            | ❌             |
| BI_PNG              | ✔️            | ❌             |
| BI_ALPHABITFIELDS   | ❌            |                |
| BI_CMYK             | ❌            |                |
| BI_CMYKRLE8         | ❌            |                |
| BI_CMYKRLE4         | ❌            |                |

Sources: [Wikipedia](https://en.wikipedia.org/wiki/BMP_file_format), [MS-WMF.pdf](https://winprotocoldoc.blob.core.windows.net/productionwindowsarchives/MS-WMF/[MS-WMF].pdf#%5B%7B%22num%22%3A195%2C%22gen%22%3A0%7D%2C%7B%22name%22%3A%22XYZ%22%7D%2C69%2C595%2C0%5D)

### PNG - Portable Network Graphics

* [Wikipedia](https://en.wikipedia.org/wiki/PNG)
