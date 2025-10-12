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
    compile_shader() {
      local shader="$1"
      if [ -f "$shader" ]; then
        echo "Compiling $shader..."
        qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 \
          -o "''${shader}.qsb" "$shader"
      fi
    }

    for shader in *.frag *.vert; do
      compile_shader "$shader"
    done
  '';

  installPhase = ''
    mkdir -p $out/lib/qt-6/qml/ShaderPlugin

    # Install compiled shaders
    for shader in *.frag.qsb *.vert.qsb; do
      if [ -f "$shader" ]; then
        cp "$shader" $out/lib/qt-6/qml/ShaderPlugin/
      fi
    done

    # Install QML files
    cp $src/qmldir $out/lib/qt-6/qml/ShaderPlugin/
    cp $src/*.qml $out/lib/qt-6/qml/ShaderPlugin/

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
