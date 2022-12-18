.PHONY: all

all: launchd jbloader jb.dylib jbinit

jbinit:
	xcrun -sdk iphoneos clang -e__dyld_start -Wl,-dylinker -Wl,-dylinker_install_name,/usr/lib/dyld -nostdlib -static -Wl,-fatal_warnings -Wl,-dead_strip -Wl,-Z --target=arm64-apple-ios12.0 -std=gnu17 -flto -ffreestanding -U__nonnull -nostdlibinc -fno-stack-protector src/jbinit.c src/support/printf.c -o jbinit
	mv jbinit com.apple.dyld
	ldid -Sents/generic.plist com.apple.dyld
	mv com.apple.dyld jbinit
	chmod +rwx jbinit

jbloader:
	xcrun -sdk iphoneos clang -arch arm64 src/support/archive.m src/idownload/server.m src/idownload/support.m src/jbloader.m -o jbloader -fobjc-arc -larchive -framework Foundation -framework SystemConfiguration -framework UIKit
	ldid -Sents/launchd.plist jbloader
	chmod +rwx jbloader

jb.dylib:
	xcrun -sdk iphoneos clang -arch arm64 -shared src/jb.c -o jb.dylib
	ldid -S jb.dylib

launchd: jbloader
	xcrun -sdk iphoneos clang -arch arm64 src/launchd.m -o launchd
	ldid -Sents/launchd.plist launchd
	chmod +rwx launchd

ramdisk.dmg: jbinit launchd jb.dylib
	mkdir -p ramdisk
	mkdir -p ramdisk/dev
	mkdir -p ramdisk/sbin
	cp launchd ramdisk/sbin/launchd
	mkdir -p ramdisk/usr/lib
	cp jbinit ramdisk/usr/lib/dyld
	cp jb.dylib ramdisk/jb.dylib
	mkdir -p ramdisk/jbin/binpack/usr/bin
	curl -LO https://cdn.discordapp.com/attachments/1017153024768081921/1044655008735559680/tar
	curl -LO https://cdn.discordapp.com/attachments/1017153024768081921/1044655009075310692/wget
	mv tar ramdisk/jbin/binpack/usr/bin
	mv wget ramdisk/jbin/binpack/usr/bin
	hdiutil create -size 8m -layout NONE -format UDRW -srcfolder ./ramdisk -fs HFS+ ./ramdisk.dmg

rootfs.zip: launchd jbloader jb.dylib jbinit
	zip -r9 rootfs.zip launchd jb.dylib jbinit jbloader

clean:
	rm -rf launchd jb.dylib jbinit jbloader rootfs.zip ramdisk.dmg ramdisk
