# Amber Linux — automatic folder emblem icons.
#
# Gives chosen folder NAMES a custom icon automatically, the way the XDG
# "Downloads" folder shows a download-arrow icon — no right-click, no menu.
#
# Mechanism: a Nemo InfoProvider runs for every file Nemo displays. For a folder
# whose name is in FOLDER_MAP we write metadata::custom-icon (a file:// URI) — the
# only icon-metadata Nemo actually renders (metadata::custom-icon-name is ignored,
# which is why the earlier context-menu approach didn't work). The URI is resolved
# against the *active* icon theme, so it auto-matches whichever Amber variant/shape
# is in use. The matching folder-<emblem>.png icons are produced by build-icons.sh.
#
# Cost: the per-file callback checks the name FIRST (an in-memory dict lookup), so
# every file that is not one of the FOLDER_MAP names returns immediately with zero
# disk I/O. Only the handful of matching folders ever read/write metadata, and the
# icon-theme lookup is cached per active theme.
#
# To add or rename a category, edit FOLDER_MAP (icon name = folder-<x>, an icon
# the Amber themes provide) and run `nemo -q` to reload.

import re

import gi
gi.require_version("Nemo", "3.0")
gi.require_version("Gtk", "3.0")
from gi.repository import Nemo, GObject, Gtk, Gio  # noqa: E402

# folder name -> themed icon name (must exist in the active icon theme)
FOLDER_MAP = {
    "Code": "folder-code",
    "Projects": "folder-projects",
    ".kat800": "folder-kat800",
}

ATTR = "metadata::custom-icon"
# A custom-icon URI is "ours" if it points at one of our emblem PNGs. We only
# ever touch empty or our-own values, so we never clobber a user's deliberate
# icon or a folder-colour the switcher set (those point at .../folder.png).
OURS_RE = re.compile(r"/folder-(?:%s)\.png$" % "|".join(
    re.escape(v.split("folder-", 1)[1]) for v in FOLDER_MAP.values()))


class AmberFolderIcons(GObject.GObject, Nemo.InfoProvider):

    def __init__(self):
        super().__init__()
        # active-theme-name -> {icon_name: uri}; rebuilt only on a cache miss.
        self._cache = {}

    def _icon_uri(self, icon_name):
        """file:// URI of icon_name in the active icon theme, or None (cached)."""
        theme = Gtk.Settings.get_default().get_property("gtk-icon-theme-name")
        by_icon = self._cache.get(theme)
        if by_icon is None:
            by_icon = self._cache[theme] = {}
        if icon_name not in by_icon:
            it = Gtk.IconTheme.new()
            it.set_custom_theme(theme)
            info = it.choose_icon_for_scale([icon_name, None], 256, 1, 0)
            path = info.get_filename() if info is not None else None
            by_icon[icon_name] = Gio.File.new_for_path(path).get_uri() if path else None
        return by_icon[icon_name]

    def update_file_info(self, f):
        try:
            # Name-first short-circuit: anything not in FOLDER_MAP costs only this
            # in-memory check and returns with zero disk I/O.
            if f.get_uri_scheme() != "file" or not f.is_directory():
                return Nemo.OperationResult.COMPLETE
            desired = FOLDER_MAP.get(f.get_name())
            if desired is None:
                return Nemo.OperationResult.COMPLETE

            uri = self._icon_uri(desired)
            if uri is None:
                return Nemo.OperationResult.COMPLETE

            gfile = f.get_location()
            try:
                current = gfile.query_info(ATTR, Gio.FileQueryInfoFlags.NONE, None) \
                               .get_attribute_string(ATTR)
            except Exception:
                current = None
            # Only set when it actually changed, and never clobber a user's own
            # custom icon or a folder-colour (those are not OURS_RE matches).
            if current != uri and ((not current) or OURS_RE.search(current)):
                gfile.set_attribute_string(ATTR, uri, Gio.FileQueryInfoFlags.NONE, None)
                f.invalidate_extension_info()
        except Exception:
            pass
        return Nemo.OperationResult.COMPLETE
