SHELL      := /usr/bin/env bash
DIST_DIR   := dist
ICON_DIR   := dist-icons
SYSTEM_DIR := /usr/share/themes
COLORS_SYS := /usr/share/folder-color-switcher/colors.d
NEMOPY_SYS := /usr/share/nemo-python/extensions
WALLPAPERS_SYS := /usr/share/backgrounds/amber-linux
WP_PROPS_SYS := /usr/share/gnome-background-properties
# Cinnamon's own Backgrounds picker (cs_backgrounds.py) hardcodes a scan of
# this directory instead — it does NOT read gnome-background-properties, and
# has no per-user equivalent, so wallpapers only reach Cinnamon's picker via
# a system-wide install. Linux Mint ships its own wallpaper XML into both
# directories for the same reason; we follow that precedent.
WP_PROPS_CINN_SYS := /usr/share/cinnamon-background-properties
THEME      ?= phosphorus
# Icon theme defaults to the GTK theme; override to pick the rounder Yaru set,
# e.g. make use THEME=phosphorus ICONS=phosphorus-Yaru
ICONS      ?= $(THEME)

BRANCH ?= main
REMOTE ?= origin
ROOT_COMMIT_MSG ?= Initial amber-theme

# The finished package. amberlinux-apt ingests it via `make deb-path`;
# amberlinux-apt/docs/PACKAGING.md is the shared target contract.
# Architecture: all — SCSS-compiled CSS and recoloured SVG/PNG icons, no
# compiled binaries.
VERSION = 0.1.0
DEB = dist/amber-theme_$(VERSION)-1_all.deb

# The standalone Dart Sass CLI build.sh compiles with — no Node/Bun/npm
# involved. No apt package exists for it (only Go bindings do), so `deps`
# vendors the official linux-x64 release tarball into .tools/, gitignored.
# https://github.com/sass/dart-sass/releases
DART_SASS_VERSION := 1.102.0

.PHONY: all clean use deps fetch-sass icons push force-push lint hooks check build ci deb deb-path deb-install deb-remove deactivate-if-active check-no-agent-files

# Copy every directory entry of SRC_DIR into DEST_DIR, skipping any entry
# named SKIP_NAME (pass empty to skip nothing). Used by `deb` for both the
# theme and icon-theme trees. SRC_DIR/*/ (trailing slash) matches directories
# only — SRC_DIR/* would also match files, and dist/ can contain one: the
# .deb `make deb` itself writes there, which would otherwise get staged into
# the package as if it were a theme.
define copy_variants
	@for d in $(1)/*/; do \
	    name=$$(basename "$$d"); \
	    if [ -n "$(3)" ] && [ "$$name" = "$(3)" ]; then continue; fi; \
	    echo "Installing $$name → $(2)/$$name"; \
	    rm -rf "$(2)/$$name"; \
	    cp -r "$$d" "$(2)/$$name"; \
	done
endef

# Vendor the standalone Dart Sass CLI build.sh compiles with — everything
# `make all`/`make check` need, and nothing else. Split out from `deps` so CI's
# lightweight compile-only job doesn't need the packaging toolchain below.
fetch-sass:
	@mkdir -p .tools
	@if [ ! -x .tools/dart-sass/sass ]; then \
	    echo "Fetching standalone Dart Sass $(DART_SASS_VERSION)..." && \
	    curl -fsSL -o /tmp/dart-sass.tar.gz \
	        https://github.com/sass/dart-sass/releases/download/$(DART_SASS_VERSION)/dart-sass-$(DART_SASS_VERSION)-linux-x64.tar.gz && \
	    tar -xzf /tmp/dart-sass.tar.gz -C .tools && \
	    rm -f /tmp/dart-sass.tar.gz; \
	fi

# Everything needed for the full local-dev/packaging pipeline: the sass CLI,
# the packaging tools, the Mint-Y-Yaru/Yaru base icon themes build-icons.sh
# reads from and recolours, imagemagick (`convert`), which build-icons.sh and
# build.sh's thumbnail recolouring both shell out to, and
# gtk-update-icon-cache, which writes the icon-theme.cache each generated theme
# ships — nothing regenerates it after install, so a build without it would
# silently ship cacheless themes.
deps: hooks fetch-sass
	sudo apt install dpkg-dev lintian shellcheck imagemagick mint-y-icons \
		yaru-theme-icon gtk-update-icon-cache

all:
	bash build.sh $(DIST_DIR)

# Cheap sanity check: every profile actually compiles.
check:
	@test -n "$$(ls profiles-yaml/*.yaml 2>/dev/null)" || { echo "check: no profiles found"; exit 1; }
	bash build.sh /tmp/amber-theme-check-dist
	@rm -rf /tmp/amber-theme-check-dist
	@echo "check: all profiles compile"

# The two artefacts a .deb needs: compiled themes and recoloured icon themes.
build: all icons

# Generate the per-profile folder icon themes — a squarer Mint-Y-Yaru-based
# set and a rounder Yaru-based set per profile, plus the Nemo folder-colour
# palette (folder-color-switcher/Amber.json).
icons:
	bash build-icons.sh $(ICON_DIR)

clean:
	rm -rf $(DIST_DIR) $(ICON_DIR) out

# If the active Cinnamon/GTK theme is one of ours, switch to stock
# Mint-Y-Dark-Grey first — otherwise removing the files out from under a live
# session leaves gsettings pointing at a theme that no longer exists on disk.
# Names come from profiles-yaml/*.yaml, not $(DIST_DIR), so this still works
# after `make clean` or on a machine that never ran `make all`.
deactivate-if-active:
	@current=$$(gsettings get org.cinnamon.theme name | tr -d "'"); \
	for y in profiles-yaml/*.yaml; do \
	    name=$$(bash scripts/yaml-field.sh "$$y" name); \
	    if [ "$$current" = "$$name" ]; then \
	        echo "Active theme '$$current' is ours — switching to Mint-Y-Dark-Grey first"; \
	        gsettings set org.cinnamon.theme name 'Mint-Y-Dark-Grey'; \
	        gsettings set org.cinnamon.desktop.interface gtk-theme 'Mint-Y-Dark-Grey'; \
	        gsettings set org.gnome.desktop.interface gtk-theme 'Mint-Y-Dark-Grey'; \
	        gsettings set org.cinnamon.desktop.wm.preferences theme 'Mint-Y-Dark-Grey'; \
	        gsettings set org.gnome.desktop.wm.preferences theme 'Mint-Y-Dark-Grey'; \
	        gsettings set org.cinnamon.desktop.interface icon-theme 'Mint-Y'; \
	        gsettings set org.gnome.desktop.interface icon-theme 'Mint-Y'; \
	        break; \
	    fi; \
	done

# Stage the system-wide package: every compiled theme, every generated icon
# theme (minus folder-color-switcher/, which isn't an icon theme), the Nemo
# folder-colour palette and extension, and docs. No maintainer scripts: every
# generated theme carries the icon-theme.cache build-icons.sh already wrote, so
# there is nothing left to run at unpack time. hicolor-icon-theme's trigger
# would not help — it watches /usr/share/icons/hicolor only, not the sibling
# theme directories these install to. mint-y-icons ships its caches the same way.
deb: build
	rm -rf out/deb
	install -d -m755 out/deb/$(SYSTEM_DIR)
	$(call copy_variants,$(DIST_DIR),out/deb/$(SYSTEM_DIR),)
	install -d -m755 out/deb/usr/share/icons
	$(call copy_variants,$(ICON_DIR),out/deb/usr/share/icons,folder-color-switcher)
	install -D -m644 $(ICON_DIR)/folder-color-switcher/Amber.json out/deb/$(COLORS_SYS)/Amber.json
	install -D -m644 src/nemo-python/amber-folder-icons.py out/deb/$(NEMOPY_SYS)/amber-folder-icons.py
	install -d -m755 out/deb/$(WALLPAPERS_SYS)
	@for f in wallpapers/*.svg; do install -m644 "$$f" "out/deb/$(WALLPAPERS_SYS)/$$(basename "$$f")"; done
	install -D -m644 wallpapers/amber.xml out/deb/$(WP_PROPS_SYS)/amber.xml
	install -D -m644 wallpapers/amber.xml out/deb/$(WP_PROPS_CINN_SYS)/amber.xml
	install -D -m644 LICENSE out/deb/usr/share/doc/amber-theme/LICENSE
	install -D -m644 packaging/debian/copyright out/deb/usr/share/doc/amber-theme/copyright
	install -D -m644 packaging/lintian-overrides out/deb/usr/share/lintian/overrides/amber-theme
	gzip -9n < packaging/debian/changelog > out/deb/usr/share/doc/amber-theme/changelog.Debian.gz
	chmod 644 out/deb/usr/share/doc/amber-theme/changelog.Debian.gz
	find out/deb -type d -exec chmod 755 {} +
	find out/deb -type f -exec chmod 644 {} +
	mkdir -p out/deb/DEBIAN
	cd out/deb && find . -type f -not -path './DEBIAN/*' -printf '%P\n' | sort | xargs md5sum > DEBIAN/md5sums
	sed -e 's/@VERSION@/$(VERSION)/' \
		-e "s/@SIZE@/$$(du -sk out/deb --exclude=DEBIAN | cut -f1)/" \
		packaging/control.in > out/deb/DEBIAN/control
	mkdir -p dist
	dpkg-deb --build --root-owner-group out/deb $(DEB)

# Where `make deb` puts the package: one absolute path, nothing else.
deb-path:
	@echo "$(CURDIR)/$(DEB)"

# The only supported way to test a change: build the real package and
# install/remove it through apt. No per-user or raw-system shortcut exists —
# those left orphaned files and drifted from what actually ships.
deb-install: deb
	sudo apt install --reinstall ./$(DEB)

deb-remove: deactivate-if-active
	sudo apt remove amber-theme

ci: check build lint
	@echo "CI OK"

# Apply a theme to the current user session (GTK widgets + Cinnamon shell).
# Default: make use          → phosphorus
# Override: make use THEME=phosphorus
use:
	gsettings set org.cinnamon.desktop.interface gtk-theme '$(THEME)'
	gsettings set org.gnome.desktop.interface gtk-theme '$(THEME)'
	gsettings set org.cinnamon.theme name '$(THEME)'
	gsettings set org.cinnamon.desktop.wm.preferences theme '$(THEME)'
	gsettings set org.gnome.desktop.wm.preferences theme '$(THEME)'
	gsettings set org.cinnamon.desktop.interface icon-theme '$(ICONS)'
	gsettings set org.gnome.desktop.interface icon-theme '$(ICONS)'
	@echo "Active theme (Desktop + Controls + Window borders): $(THEME)  Icons: $(ICONS)"

push:
	git push "$(REMOTE)" "$(BRANCH)"

# Rewrite the whole tree as one signed root commit and force-push it. The suite's
# repos carry no history until the first official release.
# Agent files are never published. Two ways they get in: already tracked, or
# present-and-unignored when `git add -A` below sweeps the whole tree. Both are
# checked here, because a squashed history shows no file being added — a stray
# path simply appears in the root commit as though it always belonged.
check-no-agent-files:
	@bad=$$(git ls-files | grep -E '(^|/)(\.mcp\.json|\.claude/|\.claude-amber/)' || true); \
	if [ -n "$$bad" ]; then \
		echo "agent files are tracked and must not be published:"; \
		printf '  %s\n' $$bad; \
		echo "fix: git rm -r --cached <path>, then add it to .gitignore"; \
		exit 2; \
	fi
	@for p in .mcp.json .claude .claude-amber; do \
		if [ -e "$$p" ] && ! git check-ignore -q "$$p"; then \
			echo "$$p exists and is not gitignored — 'git add -A' would publish it"; \
			echo "fix: add $$p to .gitignore"; \
			exit 2; \
		fi; \
	done
	@echo "no agent files staged for publication"

force-push: check-no-agent-files
	@test -z "$$(git status --porcelain)" || { \
		echo "Working tree is dirty. Commit, stash, or revert changes first."; \
		exit 2; \
	}
	@orig_branch="$$(git branch --show-current)"; \
	tmp_branch="root-squash-$$(date +%s)"; \
	git checkout --orphan "$$tmp_branch"; \
	git add -A; \
	git commit -S -m "$(ROOT_COMMIT_MSG)"; \
	git branch -D "$(BRANCH)" 2>/dev/null || true; \
	git branch -m "$(BRANCH)"; \
	git push --force --set-upstream "$(REMOTE)" "$(BRANCH)"; \
	echo "Rewrote $$orig_branch as signed root commit on $(REMOTE)/$(BRANCH)."

lint: deb
	@if command -v shellcheck >/dev/null; then \
		git ls-files | while read -r f; do \
			case "$$f" in *.sh|*.bash) echo "$$f";; \
			*) head -1 "$$f" 2>/dev/null | grep -q '^#!.*sh' && echo "$$f";; esac; \
		done | xargs -r shellcheck --severity=warning && echo "shellcheck OK"; \
	else echo "shellcheck not installed — skipping (apt install shellcheck)"; fi
	@test "$$(git config --get core.hooksPath)" = .githooks || echo "lint: hooks not installed — run 'make hooks'"
	@if command -v lintian >/dev/null; then lintian --no-tag-display-limit -L '>=pedantic' $(DEB); \
	else echo "lintian not installed — skipping (apt install lintian)"; fi

# A shipped hook does nothing until core.hooksPath points at it.
hooks:
	@git config core.hooksPath .githooks && echo "hooks: core.hooksPath -> .githooks"
