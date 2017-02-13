Command line executable should not use Cocoapods because executables look in their rpath for their framework dependencies, so frameworks should be found on that rpath or the user should change the rpath manually.
All this is avoided not using frameworks.

More info:
https://github.com/krzyzanowskim/CryptoSwift/issues/137

To avoid this problem, all the required frameworks are embedded into the executable
