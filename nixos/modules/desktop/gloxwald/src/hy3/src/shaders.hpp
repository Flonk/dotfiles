#pragma once

#include <GLES2/gl2.h>
#include <hyprland/src/render/OpenGL.hpp>
#include <hyprland/src/render/Shader.hpp>

class Hy3Shaders {
public:
	struct {
		SP<CShader> program;
		GLint proj;
		GLint monitorSize;
		GLint pixelOffset;
		GLint pixelSize;
		GLint applyBlur;
		GLint blurTex;
		GLint opacity;
		GLint fillColor;
		GLint borderColor;
		GLint borderWidth;
		GLint outerRadius;
	} tab;

	static Hy3Shaders* instance();

private:
	Hy3Shaders();
};
