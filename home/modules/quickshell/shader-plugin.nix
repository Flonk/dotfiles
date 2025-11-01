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
    shopt -s nullglob

    compile_shader() {
      local shader="$1"
      if [ -f "$shader" ]; then
        local output="''${shader}.qsb"
        echo "Compiling ''${shader} -> ''${output}"
        qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "$output" "$shader"
      fi
    }

    # Compile shaders within the new nested directory structure
    if [ -d shaders ]; then
      find shaders -type f \( -name '*.frag' -o -name '*.vert' \) -print |
        while IFS= read -r shader; do
          compile_shader "$shader"
        done
    fi
  '';

  installPhase = ''
    mkdir -p $out/lib/qt-6/qml/ShaderPlugin

    # Install module definition
    install -Dm644 qmldir "$out/lib/qt-6/qml/ShaderPlugin/qmldir"

    # Copy shader directories (sources + compiled outputs + QML widgets)
    if [ -d shaders ]; then
      cp -r shaders "$out/lib/qt-6/qml/ShaderPlugin/"
    fi

    echo "Installed files in ShaderPlugin:"
    find "$out/lib/qt-6/qml/ShaderPlugin" -maxdepth 5 -type f | sort
  '';
  meta = with pkgs.lib; {
    description = "GLSL shader plugin for Quickshell";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
