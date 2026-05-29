# lulu Desktop Pet

This is a standalone Windows desktop pet version of lulu. It does not require Codex and does not call any API.

## Run

Double-click:

```text
run_lulu.bat
```

The launcher uses Windows PowerShell/WPF, so it can run on normal Windows computers without Python.

You can also run the PowerShell version from a terminal:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\lulu_pet.ps1
```

An optional Python/Tkinter version is also included:

```powershell
python lulu_pet.py
```

The Python version requires Python 3 with Tkinter. The PowerShell version does not.

## Interactions

- Drag lulu to move the floating window.
- Click lulu to trigger a random local action such as jumping, waving, sitting, nodding, shaking, peeking, shrinking, or posing.
- Right-click lulu to switch animation states, trigger a random action, or quit.
- At the top of each hour, lulu announces the current time and performs a small action.
- No chat feature is included. No network request is made and no API key is needed.

## Dragging behavior

The Windows launcher uses screen-space cursor tracking while dragging. This avoids direction flips caused by window-relative mouse coordinates and keeps the left/right movement animation responsive. Speech bubbles are hidden during drag to reduce transparent-window repaint artifacts.

## Files

```text
lulu_pet.ps1         main Windows desktop pet app
lulu_pet.py          main desktop pet app
run_lulu.bat         Windows launcher
assets/states/*      lulu animation frames
```

## Privacy

No API key, token, password, or personal credential is included. The app is fully local.
