"""Stage and verify a macOS build before stopping/replacing the installed app."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def install(source, destination, *, run=subprocess.run):
    source, destination = Path(source), Path(destination)
    if not (source / "Contents/MacOS/Mouser").is_file():
        raise RuntimeError(f"Missing built executable: {source}")
    stage = Path(tempfile.mkdtemp(prefix=".mouser-install-", dir=destination.parent))
    candidate = stage / "Mouser.app"
    backup = stage / "previous.app"
    try:
        # Copy/verification failures must not stop the running app or delete it.
        run(["ditto", str(source), str(candidate)], check=True)
        run(["codesign", "--verify", "--deep", "--strict", str(candidate)], check=True)
        run(["launchctl", "bootout", f"gui/{os.getuid()}/io.github.tombadash.mouser"],
            check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        run(["pkill", "-x", "Mouser"], check=False)
        # A source launch has a different executable name.
        root = Path(__file__).resolve().parents[1]
        run(["pkill", "-f", "--", str(root / "main_qml.py")], check=False)
        if destination.exists():
            destination.rename(backup)
        try:
            candidate.rename(destination)
        except Exception:
            if backup.exists():
                backup.rename(destination)
            raise
        plist = Path.home() / "Library/LaunchAgents/io.github.tombadash.mouser.plist"
        plist.unlink(missing_ok=True)
        run(["open", str(destination)], check=True)
    finally:
        # Never discard the previous app if rollback itself failed.
        if backup.exists() and not destination.exists():
            print(f"Previous app preserved for recovery: {backup}")
        else:
            shutil.rmtree(stage)


if __name__ == "__main__":
    import sys
    install(sys.argv[1], sys.argv[2])
