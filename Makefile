
# .PHONY: *

all: launchd launchd_payload jb.dylib jbinit

jbinit:
	xcrun -sdk iphoneos clang -e__dyld_start -Wl,-dylinker -Wl,-dylinker_install_name,/usr/lib/dyld -nostdlib -static -Wl,-fatal_warnings -Wl,-dead_strip -Wl,-Z --target=arm64-apple-ios12.0 -std=gnu17 -flto -ffreestanding -U__nonnull -nostdlibinc -fno-stack-protector jbinit.c support/printf.c -o jbinit
	mv jbinit com.apple.dyld
	ldid -S com.apple.dyld
	mv com.apple.dyld jbinit

launchd:
	xcrun -sdk iphoneos clang -arch arm64 launchd.m -o launchd -fmodules -fobjc-arc -larchive
	ldid -Sent.xml launchd
	mv launchd jbloader

jb.dylib:
	xcrun -sdk iphoneos clang -arch arm64 -shared jb.c -o jb.dylib
	ldid -S jb.dylib

launchd_payload: launchd
	xcrun -sdk iphoneos clang -arch arm64 launchd_hook.m -o launchd_payload
	ldid -Sent.xml launchd_payload
	mv launchd_payload launchd

clean:
	rm -rf launchd jb.dylib jbinit launchd_payload jbloader
