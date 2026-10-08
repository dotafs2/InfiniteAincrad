// Isolated OpenGL shader compilation/coverage QA, never a game screenshot.
#import <Foundation/Foundation.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl3.h>
#include <stdio.h>
#include <stdlib.h>

static GLuint compile(GLenum type, NSString *path) {
    NSError *error=nil;
    NSString *source=[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if(!source){fprintf(stderr,"Cannot read shader: %s\n",path.UTF8String);exit(2);}
    const char *code=source.UTF8String;
    GLuint shader=glCreateShader(type);glShaderSource(shader,1,&code,NULL);glCompileShader(shader);
    GLint ok=0;glGetShaderiv(shader,GL_COMPILE_STATUS,&ok);
    if(!ok){char log[16384];glGetShaderInfoLog(shader,sizeof(log),NULL,log);fprintf(stderr,"%s: %s\n",path.UTF8String,log);exit(3);}
    return shader;
}

int main(int argc,char **argv){@autoreleasepool{
    if(argc!=3)return 1;
    NSString *folder=@(argv[1]);
    NSData *data=[NSData dataWithContentsOfFile:@(argv[2])];
    NSDictionary *fixture=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if(!fixture)return 2;
    CGLPixelFormatAttribute attributes[]={kCGLPFAOpenGLProfile,(CGLPixelFormatAttribute)kCGLOGLPVersion_3_2_Core,kCGLPFAAllowOfflineRenderers,0};
    CGLPixelFormatObj format;CGLContextObj context;GLint formats;
    if(CGLChoosePixelFormat(attributes,&format,&formats)||!formats||CGLCreateContext(format,NULL,&context))return 4;
    CGLDestroyPixelFormat(format);CGLSetCurrentContext(context);
    GLuint fbo,color;glGenFramebuffers(1,&fbo);glBindFramebuffer(GL_FRAMEBUFFER,fbo);
    glGenTextures(1,&color);glBindTexture(GL_TEXTURE_2D,color);
    glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA8,64,64,0,GL_RGBA,GL_UNSIGNED_BYTE,NULL);
    glFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D,color,0);
    if(glCheckFramebufferStatus(GL_FRAMEBUFFER)!=GL_FRAMEBUFFER_COMPLETE)return 5;
    glViewport(0,0,64,64);glDisable(GL_BLEND);glDisable(GL_DEPTH_TEST);glDisable(GL_CULL_FACE);
    GLuint vao;glGenVertexArrays(1,&vao);glBindVertexArray(vao);
    NSMutableArray *results=[NSMutableArray array];
    for(NSDictionary *job in fixture[@"programs"]){
        GLuint vs=compile(GL_VERTEX_SHADER,[folder stringByAppendingPathComponent:job[@"vertex"]]);
        GLuint fs=compile(GL_FRAGMENT_SHADER,[folder stringByAppendingPathComponent:job[@"fragment"]]);
        GLuint program=glCreateProgram();glAttachShader(program,vs);glAttachShader(program,fs);glBindAttribLocation(program,15,"instance_color_custom_data");glLinkProgram(program);
        GLint ok;glGetProgramiv(program,GL_LINK_STATUS,&ok);
        if(!ok){char log[16384];glGetProgramInfoLog(program,sizeof(log),NULL,log);fprintf(stderr,"Link failed: %s\n",log);return 6;}
        glUseProgram(program);
        NSMutableArray *cases=[NSMutableArray array];
        for(NSDictionary *test in job[@"cases"]){
            NSArray *packed=test[@"packed"];
            glDisableVertexAttribArray(15);
            glVertexAttribI4ui(15,[packed[0] unsignedIntValue],[packed[1] unsignedIntValue],[packed[2] unsignedIntValue],[packed[3] unsignedIntValue]);
            NSDictionary *values=test[@"uniforms"];
            for(NSString *name in values){
                GLint location=glGetUniformLocation(program,name.UTF8String);
                id value=values[name];
                if([value isKindOfClass:[NSArray class]]){
                    NSArray *v=value;float f[16]={0};for(NSUInteger i=0;i<v.count&&i<16;i++)f[i]=[v[i] floatValue];
                    if(v.count==16)glUniformMatrix4fv(location,1,GL_FALSE,f);
                    else if(v.count==4)glUniform4fv(location,1,f);
                    else if(v.count==3)glUniform3fv(location,1,f);
                    else if(v.count==2)glUniform2fv(location,1,f);
                }else if([name hasPrefix:@"probe_bool_"]||CFGetTypeID((__bridge CFTypeRef)value)==CFBooleanGetTypeID()){glUniform1i(location,[value intValue]);}
                else glUniform1f(location,[value floatValue]);
            }
            glClearColor(0,0,0,0);glClear(GL_COLOR_BUFFER_BIT);glDrawArrays(GL_TRIANGLES,0,3);glFinish();
            unsigned char pixels[64*64*4];glReadPixels(0,0,64,64,GL_RGBA,GL_UNSIGNED_BYTE,pixels);
            int visible=0;for(int i=0;i<64*64;i++)if(pixels[i*4+3]>127)visible++;
            GLenum error=glGetError();if(error!=GL_NO_ERROR){fprintf(stderr,"OpenGL error %u\n",error);return 7;}
            NSUInteger center=(32*64+32)*4;
            [cases addObject:@{@"name":test[@"name"],@"visible_pixels":@(visible),@"total_pixels":@(64*64),
                @"center_rgba8":@[@(pixels[center]),@(pixels[center+1]),@(pixels[center+2]),@(pixels[center+3])]}];
        }
        [results addObject:@{@"name":job[@"name"],@"compiled":@YES,@"cases":cases}];
        glDeleteProgram(program);glDeleteShader(vs);glDeleteShader(fs);
    }
    NSDictionary *result=@{@"scope":@"Isolated current shader equations in windowless CGL; not Godot/browser/device pixels",@"renderer":@((const char*)glGetString(GL_RENDERER)),@"programs":results};
    NSData *out=[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil];
    fwrite(out.bytes,1,out.length,stdout);fputc('\n',stdout);
    glDeleteVertexArrays(1,&vao);glDeleteTextures(1,&color);glDeleteFramebuffers(1,&fbo);
    CGLSetCurrentContext(NULL);CGLDestroyContext(context);
}return 0;}
