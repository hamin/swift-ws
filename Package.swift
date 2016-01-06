import PackageDescription

let package = Package(
	name: "ws",
	dependencies: [
        .Package(url:"https://github.com/dunkelstern/Adler32.git", majorVersion: 0)
    ]
)