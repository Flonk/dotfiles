{
  pkgs,
  stdenv,
  cmake,
  qt6,
  libcava,
  pipewire,
  pkg-config,
}:

stdenv.mkDerivation rec {
  pname = "cava-plugin";
  version = "1.0.12"; # Matches quickmilk plugin version for parity

  # Force rebuild when QML files change
  src = ./components/cava-plugin;

  nativeBuildInputs = [
    cmake
    pkg-config
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    libcava
    pipewire
    pkgs.fftw
  ];

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DCMAKE_SKIP_BUILD_RPATH=TRUE"
    "-DCMAKE_BUILD_WITH_INSTALL_RPATH=TRUE"
    "-DCMAKE_INSTALL_RPATH_USE_LINK_PATH=FALSE"
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/qt-6/qml/CavaPlugin

    # Install both the backing library and plugin library if they exist
    cp libcavaprovider.so $out/lib/qt-6/qml/CavaPlugin/ 2>/dev/null || echo "libcavaprovider.so not found"
    cp libcavaproviderplugin.so $out/lib/qt-6/qml/CavaPlugin/ 2>/dev/null || echo "libcavaproviderplugin.so not found"

    # Copy qmldir from source (contains QML type registrations)
    cp $src/qmldir $out/lib/qt-6/qml/CavaPlugin/

    echo "=== Installed files in CavaPlugin ==="
    ls -la $out/lib/qt-6/qml/CavaPlugin/

    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "Cava audio visualizer plugin for Quickshell";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
