# CI builds and diagnostics

Dependency caches include MSVC and manifest/configuration hashes. Older caches
seed vcpkg, which checks ABIs before reuse. Successful configuration saves new
caches before source/test failures can discard the dependency build.
Compiler caching uses checksum-verified sccache 0.16.0 and a bounded local disk
cache persisted by GitHub-owned actions. Checked-out setup code and the cache
daemon do not receive Actions runtime credentials or the GitHub-script input token. Cache server I/O failures allow compilation
without cache. Statistics collection cannot replace or fail successful tests.

Stage logs preserve native exit codes and elapsed seconds. Diagnostics expire
after seven days and contain configuration records, cache statistics and JUnit
reports for CTest jobs. CTest requires a nonempty suite; test isolation is retained.
Compiler optimizations, existing native fixtures and browser audits are unchanged.

Windows binary artifacts retain their previous scope, rather than bundling an
entire installation. They expire after fourteen days and validate x64 PE headers
and packaged DLL dependency closure. Windows resolves API-set imports.

The WebAssembly job uses bounded ccache storage. Restored statistics
are reset before compilation so hit/miss reports describe the current run. Linking, tests and
package validation still execute on each run. Compare cold and warm timings
separately; CI validation does not replace interactive application testing.

Astra pins vcpkg's tool checkout in vcpkg-tool.sha separately from the manifest
baseline. Its version database must contain the explicitly required curl 8.21
while the baseline continues to select the other existing dependency versions.
The tool commit also participates in the binary dependency-cache key.

The build date is compiled in application.cpp instead of a widely included
header, retaining the real compiler date without invalidating unrelated files
when the date changes. Source optimizations and native/browser tests are unchanged.
