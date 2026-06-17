# Fonts

Drop the following TrueType files here (exact filenames — they're referenced by
`Info.plist` `UIAppFonts` and `Typography.swift`). All three families are open-source
(SIL Open Font License); download from Google Fonts.

```
PlusJakartaSans-Regular.ttf
PlusJakartaSans-Medium.ttf
PlusJakartaSans-SemiBold.ttf
PlusJakartaSans-Bold.ttf
PlusJakartaSans-ExtraBold.ttf
Inter-Regular.ttf
Inter-Medium.ttf
Inter-SemiBold.ttf
Inter-Bold.ttf
JetBrainsMono-Regular.ttf
JetBrainsMono-Medium.ttf
JetBrainsMono-Bold.ttf
```

If a file is missing, the app still builds and runs — `Typography.swift` falls back to
the equivalent system font automatically. Add the .ttf files before shipping so the UI
matches the design exactly.

This README is excluded from the app target in `project.yml`.
