PY := .venv/bin/python
APP := dist/Mouser.app

.PHONY: dev release run-release install test quit clean

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

release: $(PY)
	./build_macos_app.sh

run-release: release quit
	open $(APP)

# Replaces the installed copy; ditto preserves the bundle's signature.
install: $(PY)
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
