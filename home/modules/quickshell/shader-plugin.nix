{
  pkgs,
  stdenv,
  qt6,
}:

stdenv.mkDerivation rec {
  pname = "shader-plugin";
  version = "1.0.0";

  # Source directory containing shaders
  src = ./components/shader-plugin;

  nativeBuildInputs = [
    qt6.qtshadertools # Provides qsb tool for shader compilation
    qt6.wrapQtAppsHook # Required for Qt dependencies
  ];

  buildPhase = ''
    # Compile each .frag shader to .frag.qsb
    for shader in *.frag; do
      if [ -f "$shader" ]; then
        echo "Compiling $shader..."
        qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 \
          -o "''${shader}.qsb" "$shader"
      fi
    done
  '';

  installPhase = ''
    mkdir -p $out/lib/qt-6/qml/ShaderPlugin

    # Install compiled shaders
    cp *.frag.qsb $out/lib/qt-6/qml/ShaderPlugin/ 2>/dev/null || echo "No compiled shaders found"

    # Install QML files
    cp $src/qmldir $out/lib/qt-6/qml/ShaderPlugin/
    cp $src/XorShaderWidget.qml $out/lib/qt-6/qml/ShaderPlugin/

    # List what we installed for debugging
    echo "Installed files in ShaderPlugin:"
    ls -la $out/lib/qt-6/qml/ShaderPlugin/
  '';

  meta = with pkgs.lib; {
    description = "GLSL shader plugin for Quickshell";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
