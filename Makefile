PY := .venv/bin/python
APP := dist/Mouser.app

.PHONY: dev run-dev run release run-release install test quit clean

$(PY): requirements.txt
	python3 -m venv .venv
	$(PY) -m pip install -r requirements.txt
	touch $(PY)

# Only one Mouser can own the mouse at a time.
quit:
	-pkill -x Mouser
	# Also stop source/dev launches, whose Python process is invisible to the
	# packaged-app name but still owns Mouser's single-instance socket.
	-pkill -f -- "$(CURDIR)/main_qml.py"

dev: $(PY) quit
	$(PY) main_qml.py

# Friendly aliases for source-checkout development launches.
run-dev: dev
run: dev

release: $(PY)
	./build_macos_app.sh

run-release: release quit
	open $(APP)

# Replaces the installed copy; ditto preserves the bundle's signature.
install: $(PY)
	# Remove a source-checkout LaunchAgent first; otherwise it can restart the
	# Terminal/Python build while the packaged app is being installed.
	-launchctl bootout gui/$$(id -u) io.github.tombadash.mouser
	rm -f "$$HOME/Library/LaunchAgents/io.github.tombadash.mouser.plist"
	$(MAKE) quit
	# Remove source-checkout and previous packaged builds before rebuilding. This
	# prevents Spotlight from finding stale Mouser.app copies in the repository.
	rm -rf build dist
	$(MAKE) release
	rm -rf /Applications/Mouser.app
	ditto $(APP) /Applications/Mouser.app
	# Keep only the installed copy; do not leave another app bundle in the repo.
	rm -rf build dist
	open /Applications/Mouser.app

test: $(PY)
	$(PY) -m unittest discover -s tests

clean:
	rm -rf build dist
