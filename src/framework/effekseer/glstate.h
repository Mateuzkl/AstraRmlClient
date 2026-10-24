#pragma once
// Desktop GL3.3 or ANGLE ES3. Include after Astra's backend GL declarations.
#include <array>

class EffekseerGlState {
    struct Stencil { GLint function, reference, valueMask, writeMask, fail, depthFail, pass; };
    struct Unit { GLint texture, sampler; };
public:
    EffekseerGlState() {
        glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &drawFbo); glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, &readFbo);
        glGetIntegerv(GL_RENDERBUFFER_BINDING, &renderbuffer);
        glGetIntegerv(GL_VIEWPORT, viewport); glGetIntegerv(GL_SCISSOR_BOX, scissor);
        glGetIntegerv(GL_CURRENT_PROGRAM, &program); glGetIntegerv(GL_VERTEX_ARRAY_BINDING, &vao);
        glGetIntegerv(GL_ARRAY_BUFFER_BINDING, &vbo); glGetIntegerv(GL_ELEMENT_ARRAY_BUFFER_BINDING, &ebo);
        glGetIntegerv(GL_ACTIVE_TEXTURE, &active);
        GLint available; glGetIntegerv(GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS, &available);
        unitCount = std::min(available, int(units.size()));
        for (int i=0;i<unitCount;++i) {
            glActiveTexture(GL_TEXTURE0+i); glGetIntegerv(GL_TEXTURE_BINDING_2D, &units[i].texture);
            glGetIntegerv(GL_SAMPLER_BINDING, &units[i].sampler);
        }
        glActiveTexture(active);
        for (size_t i=0;i<capabilities.size();++i) enabled[i]=glIsEnabled(capabilities[i]);
        glGetIntegerv(GL_BLEND_EQUATION_RGB,&eqRgb); glGetIntegerv(GL_BLEND_EQUATION_ALPHA,&eqAlpha);
        glGetIntegerv(GL_BLEND_SRC_RGB,&srcRgb); glGetIntegerv(GL_BLEND_DST_RGB,&dstRgb);
        glGetIntegerv(GL_BLEND_SRC_ALPHA,&srcAlpha); glGetIntegerv(GL_BLEND_DST_ALPHA,&dstAlpha);
        glGetFloatv(GL_BLEND_COLOR,blendColor); glGetBooleanv(GL_COLOR_WRITEMASK,colorMask);
        glGetBooleanv(GL_DEPTH_WRITEMASK,&depthMask); glGetIntegerv(GL_DEPTH_FUNC,&depthFunc);
#ifdef OPENGL_ES
        glGetFloatv(GL_DEPTH_RANGE,depthRange);
#else
        glGetDoublev(GL_DEPTH_RANGE,depthRange);
#endif
        glGetIntegerv(GL_CULL_FACE_MODE,&cullFace); glGetIntegerv(GL_FRONT_FACE,&frontFace);
        glGetIntegerv(GL_UNPACK_ALIGNMENT,&unpackAlignment); glGetIntegerv(GL_UNPACK_ROW_LENGTH,&unpackRow);
        glGetIntegerv(GL_UNPACK_SKIP_PIXELS,&unpackPixels); glGetIntegerv(GL_UNPACK_SKIP_ROWS,&unpackRows);
        glGetIntegerv(GL_PIXEL_UNPACK_BUFFER_BINDING,&unpackBuffer);
        glGetIntegerv(GL_PIXEL_PACK_BUFFER_BINDING,&packBuffer); glGetIntegerv(GL_PACK_ALIGNMENT,&packAlignment);
        captureStencil(front,false); captureStencil(back,true);
    }
    ~EffekseerGlState() {
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER,drawFbo); glBindFramebuffer(GL_READ_FRAMEBUFFER,readFbo);
        glBindRenderbuffer(GL_RENDERBUFFER,renderbuffer); glViewport(viewport[0],viewport[1],viewport[2],viewport[3]);
        glScissor(scissor[0],scissor[1],scissor[2],scissor[3]); glUseProgram(program);
        glBindVertexArray(vao); glBindBuffer(GL_ELEMENT_ARRAY_BUFFER,ebo); glBindBuffer(GL_ARRAY_BUFFER,vbo);
        for(int i=0;i<unitCount;++i) {
            glActiveTexture(GL_TEXTURE0+i); glBindTexture(GL_TEXTURE_2D,units[i].texture); glBindSampler(i,units[i].sampler);
        }
        glActiveTexture(active);
        for(size_t i=0;i<capabilities.size();++i) { if(enabled[i]) glEnable(capabilities[i]); else glDisable(capabilities[i]); }
        glBlendEquationSeparate(eqRgb,eqAlpha); glBlendFuncSeparate(srcRgb,dstRgb,srcAlpha,dstAlpha);
        glBlendColor(blendColor[0],blendColor[1],blendColor[2],blendColor[3]);
        glColorMask(colorMask[0],colorMask[1],colorMask[2],colorMask[3]);
        glDepthMask(depthMask); glDepthFunc(depthFunc);
#ifdef OPENGL_ES
        glDepthRangef(depthRange[0],depthRange[1]);
#else
        glDepthRange(depthRange[0],depthRange[1]);
#endif
        glCullFace(cullFace); glFrontFace(frontFace);
        glBindBuffer(GL_PIXEL_UNPACK_BUFFER,unpackBuffer); glBindBuffer(GL_PIXEL_PACK_BUFFER,packBuffer);
        glPixelStorei(GL_UNPACK_ALIGNMENT,unpackAlignment); glPixelStorei(GL_UNPACK_ROW_LENGTH,unpackRow);
        glPixelStorei(GL_UNPACK_SKIP_PIXELS,unpackPixels); glPixelStorei(GL_UNPACK_SKIP_ROWS,unpackRows);
        glPixelStorei(GL_PACK_ALIGNMENT,packAlignment); restoreStencil(front,GL_FRONT); restoreStencil(back,GL_BACK);
    }
    EffekseerGlState(const EffekseerGlState&)=delete;
    EffekseerGlState& operator=(const EffekseerGlState&)=delete;
private:
    static void captureStencil(Stencil& s,bool b) {
        glGetIntegerv(b?GL_STENCIL_BACK_FUNC:GL_STENCIL_FUNC,&s.function);
        glGetIntegerv(b?GL_STENCIL_BACK_REF:GL_STENCIL_REF,&s.reference);
        glGetIntegerv(b?GL_STENCIL_BACK_VALUE_MASK:GL_STENCIL_VALUE_MASK,&s.valueMask);
        glGetIntegerv(b?GL_STENCIL_BACK_WRITEMASK:GL_STENCIL_WRITEMASK,&s.writeMask);
        glGetIntegerv(b?GL_STENCIL_BACK_FAIL:GL_STENCIL_FAIL,&s.fail);
        glGetIntegerv(b?GL_STENCIL_BACK_PASS_DEPTH_FAIL:GL_STENCIL_PASS_DEPTH_FAIL,&s.depthFail);
        glGetIntegerv(b?GL_STENCIL_BACK_PASS_DEPTH_PASS:GL_STENCIL_PASS_DEPTH_PASS,&s.pass);
    }
    static void restoreStencil(const Stencil& s,GLenum face) {
        glStencilFuncSeparate(face,s.function,s.reference,s.valueMask); glStencilMaskSeparate(face,s.writeMask);
        glStencilOpSeparate(face,s.fail,s.depthFail,s.pass);
    }
    static constexpr std::array capabilities{GL_BLEND,GL_DEPTH_TEST,GL_CULL_FACE,GL_SCISSOR_TEST,
        GL_STENCIL_TEST,
#ifndef OPENGL_ES
        GL_FRAMEBUFFER_SRGB,
#endif
        GL_RASTERIZER_DISCARD,GL_SAMPLE_ALPHA_TO_COVERAGE};
    std::array<GLboolean,capabilities.size()> enabled{}; std::array<Unit,16> units{};
    GLint drawFbo{},readFbo{},renderbuffer{},viewport[4]{},scissor[4]{},program{},vao{},vbo{},ebo{},active{},unitCount{};
    GLint eqRgb{},eqAlpha{},srcRgb{},dstRgb{},srcAlpha{},dstAlpha{},depthFunc{},cullFace{},frontFace{};
    GLint unpackAlignment{},unpackRow{},unpackPixels{},unpackRows{},unpackBuffer{},packBuffer{},packAlignment{};
    GLfloat blendColor[4]{}; GLboolean colorMask[4]{},depthMask{};
#ifdef OPENGL_ES
    GLfloat depthRange[2]{};
#else
    GLdouble depthRange[2]{};
#endif
    Stencil front{},back{};
};
