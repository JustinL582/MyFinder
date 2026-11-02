# MyFinder

[中文](README.md) | **English**

A native macOS 14+ SwiftUI file browser that looks and behaves like Finder — and shows the **recursive total size of every folder**, which Finder's list view leaves blank.

## Features

- **Finder look & feel**: sidebar (Home / Desktop / Documents / Downloads), toolbar with back/forward, and four views — Icons, List, Columns, Gallery.
- **Folder sizes, automatically**: open a folder and the total size of every subfolder on that level is computed in the background and filled in as each one finishes. No need to drill into anything. Results are cached on disk, so revisiting is fast.
- **Columns view** shows the whole path side by side (Miller columns), with sizes in every column.
- **Sorting**: right-click → *Sort By* (Name / Kind / Date Modified / Size); pick the active key again to flip ascending/descending. Works in all views, or click a column header in List view.
- **File operations** (right-click): New Folder, Rename, Move to Trash, Copy Path, Show in Finder, Open.
- **Quick Look**: select an item and press **Space**.
- **Quits when the window closes** — nothing lingers in the background using memory.
- **English and Chinese UI**: follows the system language.

## Run

**Double-click** `MyFinder.app` (build it first with `打包App.command`, see below).

**English UI regardless of system language**: double-click `启动英文版.command`, or

```bash
open -n MyFinder.app --args -AppleLanguages "(en)"
```

**From the command line** (development):

```bash
cd MyFinderTool2.fresh
swift build
swift run MyFinder
```

`swift run` has no localization bundle, so it shows the Chinese source strings; use the packaged app for English.

You can also open `MyFinderTool2.fresh/Package.swift` in Xcode and press Run.

## Build the app bundle

Double-click `打包App.command` (or run it in a terminal). It does a release build, assembles `MyFinder.app` (executable, icon, `Info.plist`, localization resources) and ad-hoc signs it. The result is `MyFinder.app` next to the script.

> The app is ad-hoc signed, not notarized. On another Mac you may need to right-click → Open the first time.

## Requirements

- macOS 14 or later
- Xcode / Swift 5.9+ toolchain

## Localization

Chinese source strings are used as keys. English translations live in `Resources/en.lproj/Localizable.strings`; `Resources/zh-Hans.lproj` mirrors the keys. SwiftUI literals localize automatically; plain `String` values go through the `L()` helper in `MyFinderTool2.fresh/Localization.swift`. To add a language, add a `<lang>.lproj` folder under `Resources/` and list it in `CFBundleLocalizations` in `打包App.command`.

## Notes

- Runs as a non-sandboxed app so it can read any folder you open. A sandboxed build for distribution would need security-scoped bookmarks.
- Folder sizes use "compute the level you're viewing" — it never recurses the whole tree up front, so even huge directories open instantly.
