#include "render.hpp"

#include <cairo/cairo.h>
#include <string>
#include <GLES2/gl2.h>
#include <hyprland/src/render/OpenGL.hpp>
#include <hyprland/src/render/gl/GLTexture.hpp>
#include <hyprland/src/render/Shader.hpp>
#include <hyprutils/math/Box.hpp>
#include <hyprutils/math/Misc.hpp>
#include <hyprutils/math/Vector2D.hpp>

#include "render/Context.hpp"
#include "render/Renderer.hpp"
#include "render/Texture.hpp"
#include "shaders.hpp"

using Render::GL::g_pHyprOpenGL;
using Hyprutils::Math::CBox;

static SP<Render::ITexture> loadChromeTexture(const char* name) {
#ifdef HY3_CHROME_DIR
	auto* surface = cairo_image_surface_create_from_png((std::string(HY3_CHROME_DIR) + "/" + name).c_str());
	if (cairo_surface_status(surface) != CAIRO_STATUS_SUCCESS) {
		cairo_surface_destroy(surface);
		return nullptr;
	}
	auto texture = g_pHyprRenderer->createTexture(surface);
	cairo_surface_destroy(surface);
	return texture;
#else
	return nullptr;
#endif
}

void Hy3Render::renderTab(
    Render::CRenderContext& ctx,
    const CBox& box,
    float opacity,
    bool blur,
    const CHyprColor& fillColor,
    const CHyprColor& borderColor,
    int borderWidth,
    int radius,
    float chrome
) {
	static auto& shader = Hy3Shaders::instance()->tab;
	auto& rdata = ctx.m_data;

	auto rbox = box;
	rdata.renderModif.applyToBox(rbox);

	const auto& monitorSize = rdata.pMonitor->m_transformedSize;
	auto monitorBox = CBox {Vector2D(), monitorSize};

	auto glMatrix = g_pHyprRenderer->projectBoxToTarget(ctx, monitorBox, Hyprutils::Math::HYPRUTILS_TRANSFORM_NORMAL);

	g_pHyprOpenGL->useShader(shader.program);

#ifndef GLES2
	glUniformMatrix3fv(shader.proj, 1, GL_TRUE, glMatrix.getMatrix().data());
#else
	glMatrix.transpose();
	glUniformMatrix3fv(shader.proj, 1, GL_FALSE, glMatrix.getMatrix().data());
#endif

	WP<Render::ITexture> blurTex;

	if (blur) {
		blurTex = g_pHyprRenderer->getBlurTexture(ctx);
		if (!blurTex) blur = false;
	}

	if (blur) {
		GLCALL(glActiveTexture(GL_TEXTURE0));
		//GLCALL(glBindTexture(blurTex->m_target, blurTex->m_texID));
		GLCALL(glBindTexture(GL_TEXTURE_2D, blurTex->m_texID));
		GLCALL(glUniform1i(shader.blurTex, 0));
	}

	GLCALL(glUniform1i(shader.applyBlur, blur));

	// premultiplied
	GLCALL(glUniform4f(
	    shader.fillColor,
	    fillColor.r * fillColor.a,
	    fillColor.g * fillColor.a,
	    fillColor.b * fillColor.a,
	    fillColor.a
	));

	if (borderWidth != 0) {
		GLCALL(glUniform4f(
		    shader.borderColor,
		    borderColor.r * borderColor.a,
		    borderColor.g * borderColor.a,
		    borderColor.b * borderColor.a,
		    borderColor.a
		));
	}

	GLCALL(glUniform2f(shader.monitorSize, monitorSize.x, monitorSize.y));
	GLCALL(glUniform2f(shader.pixelOffset, rbox.x, rbox.y));
	GLCALL(glUniform2f(shader.pixelSize, rbox.w, rbox.h));
	GLCALL(glUniform1f(shader.opacity, opacity));
	GLCALL(glUniform1f(shader.outerRadius, radius));
	GLCALL(glUniform1f(shader.borderWidth, borderWidth));
	GLCALL(glUniform1f(shader.chrome, chrome));

	static auto noiseTexture = loadChromeTexture("noise.png");
	static auto dotsTexture = loadChromeTexture("dots.png");
	static auto gradientTexture = loadChromeTexture("gradient.png");
	const bool chromeTextures = chrome > 0.0f && noiseTexture && dotsTexture && gradientTexture;
	GLCALL(glUniform1f(shader.chromeTextures, chromeTextures ? 1.0f : 0.0f));
	if (chromeTextures) {
		GLCALL(glActiveTexture(GL_TEXTURE1));
		GLCALL(glBindTexture(GL_TEXTURE_2D, noiseTexture->m_texID));
		GLCALL(glUniform1i(shader.noiseTex, 1));
		GLCALL(glActiveTexture(GL_TEXTURE2));
		GLCALL(glBindTexture(GL_TEXTURE_2D, dotsTexture->m_texID));
		GLCALL(glUniform1i(shader.dotsTex, 2));
		GLCALL(glActiveTexture(GL_TEXTURE3));
		GLCALL(glBindTexture(GL_TEXTURE_2D, gradientTexture->m_texID));
		GLCALL(glUniform1i(shader.gradientTex, 3));
		GLCALL(glActiveTexture(GL_TEXTURE0));
	}

	GLCALL(glBindVertexArray(shader.program->getUniformLocation(SHADER_SHADER_VAO)));
	GLCALL(glDrawArrays(GL_TRIANGLE_STRIP, 0, 4));
	GLCALL(glBindVertexArray(0));

	if (blur) {
		// GLCALL(glBindTexture(blurTex->m_target, 0));
		GLCALL(glBindTexture(GL_TEXTURE_2D, 0));
	}
}
