# TODO: ReleaseSafe does not function - this boi being low-key naughty

all:
	zig build -Doptimize=ReleaseSmall -Dcallback_host="http://192.168.7.230:8080" -Dhost_background_path="C:/windows/temp/background.png" --release=small

debug:
	zig build -freference-trace -Doptimize=Debug -Dcallback_host="http://192.168.7.230:8080" -Dhost_background_path="C:/windows/temp/background.png"

clean:
	rm -rf zig-out zig-cache .zig-cache

.phony: clean
