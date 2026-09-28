PY := .venv/bin/python
APP := dist/Mouser.app

.PHONY: dev run-dev run release run-release install reset-permissions test quit clean

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
	# Build first: a compiler/signing/Keychain failure must leave the running
	# installed app untouched. Preserve TCC grants; never reset them here.
	# Remove source-checkout and previous packaged builds before rebuilding. This
	# prevents Spotlight from finding stale Mouser.app copies in the repository.
	rm -rf build dist
	$(MAKE) release
	$(PY) tools/install_macos_app.py $(APP) /Applications/Mouser.app
	# Keep only the installed copy; do not leave another app bundle in the repo.
	rm -rf build dist

# Only for deliberate permission troubleshooting; normal installs must not
# revoke previously granted Accessibility and Input Monitoring access.
reset-permissions:
	tccutil reset Accessibility io.github.tombadash.mouser
	tccutil reset ListenEvent io.github.tombadash.mouser

test: $(PY)
	$(PY) -m unittest discover -s tests

clean:
	rm -rf build dist
