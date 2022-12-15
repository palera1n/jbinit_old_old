.PHONY: all

all: launchd jbloader jb.dylib jbinit

jbinit:
	xcrun -sdk iphoneos clang -e__dyld_start -Wl,-dylinker -Wl,-dylinker_install_name,/usr/lib/dyld -nostdlib -static -Wl,-fatal_warnings -Wl,-dead_strip -Wl,-Z --target=arm64-apple-ios12.0 -std=gnu17 -flto -ffreestanding -U__nonnull -nostdlibinc -fno-stack-protector jbinit.c support/printf.c -o jbinit
	mv jbinit com.apple.dyld
	ldid -Sents/generic.plist com.apple.dyld
	mv com.apple.dyld jbinit

jbloader:
	xcrun -sdk iphoneos clang -arch arm64 support/archive.m idownload/server.m idownload/support.m jbloader.m -o jbloader -fobjc-arc -larchive -framework Foundation -framework SystemConfiguration -framework UIKit
	ldid -Sents/launchd.plist jbloader

jb.dylib:
	xcrun -sdk iphoneos clang -arch arm64 -shared jb.c -o jb.dylib
	ldid -S jb.dylib

launchd: jbloader
	xcrun -sdk iphoneos clang -arch arm64 launchd.m -o launchd
	ldid -Sents/launchd.plist launchd

ramdisk.dmg: jbinit launchd jb.dylib
	mkdir -p ramdisk
	mkdir -p ramdisk/dev
	mkdir -p ramdisk/sbin
	cp launchd ramdisk/sbin/launchd
	mkdir -p ramdisk/usr/lib
	cp jbinit ramdisk/usr/lib/dyld
	cp jb.dylib ramdisk/jb.dylib
	hdiutil create -size 8m -layout NONE -format UDRW -srcfolder ./ramdisk -fs HFS+ ./ramdisk.dmg

rootfs: launchd jbloader jb.dylib jbinit
	zip -r9 rootfs.zip launchd jb.dylib jbinit jbloader

clean:
	rm -rf launchd jb.dylib jbinit jbloader
