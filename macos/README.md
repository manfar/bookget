# Bookget macOS Intel GUI

This SwiftUI app is a macOS 14+ front end for the existing Bookget Go CLI. It does not reimplement the downloaders or alter the Windows C++/WebView2 GUI.

## Build on an Intel Mac

From the repository root:

```bash
make macos-app
```

Output:

```text
dist/darwin-amd64/Bookget.app
```

To replace an existing generated bundle after reviewing the path:

```bash
FORCE=1 make macos-app
```

The build creates an x86_64 Go CLI in `Contents/Resources/bin/bookget`, a SwiftUI executable in `Contents/MacOS/Bookget`, and an ad-hoc code signature. It is a local development build and is not Apple-notarized.

## GUI scope and known limits

- Supports one direct HTTP/HTTPS URL per task.
- Passes destination directory, optional Cookies and Headers files, page range, volume range, and per-task thread count to the existing CLI.
- Uses the existing Go downloader and site routers. It does not reproduce those functions in Swift.
- Displays combined stdout/stderr output and an indeterminate running indicator.
- The current CLI does not expose a stable structured progress protocol, so the GUI intentionally does not display a fabricated percentage or byte count.
- Terminating a process sends the operating-system terminate signal. It is not a confirmed graceful cancellation; a downloader implementation may leave partial output files.
- Batch URL-file mode and the interactive image-template mode are not exposed in this first GUI.

Cookies and Headers paths are passed to the CLI; the GUI does not copy their contents. Cookies must use a format accepted by the existing Bookget code. Headers use one `Name: Value` entry per line.
