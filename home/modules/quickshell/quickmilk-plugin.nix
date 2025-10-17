{
  pkgs,
  stdenv,
  cmake,
  qt6,
  pipewire,
  pkg-config,
}:

stdenv.mkDerivation rec {
  pname = "quickmilk-plugin";
  version = "1.0.13"; # Performance optimizations: reduced allocations and improved math

  # Force rebuild when QML files change
  src = ./components/quickmilk-plugin;

  nativeBuildInputs = [
    cmake
    pkg-config
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
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

    mkdir -p $out/lib/qt-6/qml/Quickmilk

    # Copy the built plugin files
    cp libquickmilk.so $out/lib/qt-6/qml/Quickmilk/
    cp libquickmilkplugin.so $out/lib/qt-6/qml/Quickmilk/
    cp qmldir $out/lib/qt-6/qml/Quickmilk/
    cp Quickmilk.qml $out/lib/qt-6/qml/Quickmilk/

    echo "=== Installed files in Quickmilk ==="
    ls -la $out/lib/qt-6/qml/Quickmilk/

    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "Quickmilk audio visualizer plugin for Quickshell";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
