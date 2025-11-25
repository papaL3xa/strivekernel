<h1 align="center">SMURF Kernel for Galaxy S10/Note10 devices.</h1>

# How to Install
- Extract First
- Flash kernel zip file via `TWRP` recovery based
- .tar file Flash with Odin on BL or AP
- Reboot to System
- Viola.. Enjoy the Kernel
- Install `KernelSU Next` from [Here](https://github.com/KernelSU-Next/KernelSU-Next/releases)

# Supported Devices:

|        Name       |  Codename  |    Model   |    Status  |
:------------------:|:----------:|:----------:|:----------:|
|    Galaxy S10e    | beyond0lte | SM-G970F/N |     ✅    |
|     Galaxy S10    | beyond1lte | SM-G973F/N |     ✅    |
|    Galaxy S10+    | beyond2lte | SM-G975F/N |     ✅    |
|   Galaxy S10 5G   |   beyondx  | SM-G977B/N |     ✅    |
|   Galaxy Note10   |     d1     | SM-N970F/N |     ✅    |
|  Galaxy Note10 5G |    d1xks   |  SM-N971N  |     ✅    |
|   Galaxy Note10+  |     d2s    | SM-N975F/N |     ✅    |
| Galaxy Note10+ 5G |     d2x    | SM-N976B/N |     ✅    |

# How to Build

1. Clone this repository

```
git clone https://github.com/papaL3xa/smurfkernel.git
```

2. Build for your device (To list all build script command run `./build.sh -h`)

```
./build.sh -m [device_codename] -v [kernel_version]
```

> **Example:** Build for Galaxy S10+
> 
> ```
> ./build.sh -m G975F -v 1.0.0
> ```

3. Output will place in FOLDER "papa"
4. Flash using TWRP based recovery for
   ```
   SmurfKernel_[device_codename]_[kernel_version]_TWRP_KSUN.zip
   ```
6. Flash using ODIN for
   ```
   SmurfKernel_[device_codename]_[kernel_version]_ODIN_KSUN.tar
   ```
8. Test it and enjoy!
   
# Credits

- [`GoRhanHee`](https://github.com/GoRhanHee) for [KernelSources & KSUN](https://github.com/GoRhanHee/exynos9820_samsung_Kernel)

