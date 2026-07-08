%global debug_package %{nil}
%global __os_install_post %{nil}

Name:           moonrelay
Version:        @VERSION@
Release:        1%{?dist}
Summary:        A Matrix chat client for professionals.
License:        AGPL-3.0-or-later
URL:            https://github.com/SurenaSKQ/moonrelay
Vendor:         Surena Karimpour Ghannadi
Source0:        https://github.com/SurenaSKQ/moonrelay/releases/download/v@VERSION@/moonrelay-v@VERSION@.tar.gz

# Linux base requirements (matches Flutter release glibc floor).
Requires:       glibc >= 2.31
Requires:       gtk3
Requires:       nss
Requires:       libsecret
Requires:       sqlite3
Requires:       jsoncpp
Requires:       libcurl
Recommends:     libappindicator-gtk3

%description
Moonrelay is a desktop Matrix chat client for professionals. It supports
end-to-end encryption via Vodozemac, rich messages (text, image, audio,
file, video), custom themes, and integration with the Freedesktop
matrix:// URI scheme.

%prep
# Buildroot is supplied by `rpmbuild -bb --buildroot=...`

%build
# Bundle already provided via external `flutter build linux --release`

%install
cp -a %{buildroot}/. %{buildroot}/

# Symlink the binary into /usr/bin (already in BUILDROOT layout).
%files
/usr/bin/moonrelay
/usr/lib/moonrelay
/usr/share/applications/moonrelay.desktop
/usr/share/icons/hicolor/256x256/apps/moonrelay.png
/usr/share/metainfo/io.github.surenaskq.moonrelay.appdata.xml

%post
if [ -x /usr/bin/update-desktop-database ]; then
  /usr/bin/update-desktop-database -q /usr/share/applications || :
fi
if [ -x /usr/bin/xdg-mime ]; then
  /usr/bin/xdg-mime default moonrelay.desktop x-scheme-handler/matrix || :
fi

%changelog
* @BUILD_DATE@ Surena Karimpour Ghannadi <https://github.com/SurenaSKQ> - @VERSION@-1
- Automated package rebuild for version @VERSION@.
