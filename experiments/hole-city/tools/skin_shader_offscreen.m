// Windowless macOS OpenGL compiler/render probe for exported skin inputs.
// No application window, browser, localhost access or focus changes.
#import <Foundation/Foundation.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl3.h>
#include <stdio.h>
#include <stdlib.h>
static GLuint compile(GLenum kind, NSString *path) {
    NSString *text=[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if(!text){fprintf(stderr,"Missing shader %s\n",path.UTF8String);exit(2);}
    const char *source=text.UTF8String;GLuint shader=glCreateShader(kind);glShaderSource(shader,1,&source,0);glCompileShader(shader);
    GLint ok;glGetShaderiv(shader,GL_COMPILE_STATUS,&ok);if(!ok){char log[8192];glGetShaderInfoLog(shader,8192,0,log);fprintf(stderr,"%s: %s\n",path.UTF8String,log);exit(3);}return shader;
}
static GLuint program(NSString *folder, NSString *name) {
    GLuint vert=compile(GL_VERTEX_SHADER,[folder stringByAppendingPathComponent:[name stringByAppendingString:@".vert"]]);
    GLuint frag=compile(GL_FRAGMENT_SHADER,[folder stringByAppendingPathComponent:[name stringByAppendingString:@".frag"]]);
    GLuint p=glCreateProgram();glAttachShader(p,vert);glAttachShader(p,frag);glBindAttribLocation(p,0,"in_position");glBindAttribLocation(p,1,"in_uv");glLinkProgram(p);GLint ok;glGetProgramiv(p,GL_LINK_STATUS,&ok);if(!ok){char log[8192];glGetProgramInfoLog(p,8192,0,log);fprintf(stderr,"Link: %s\n",log);exit(4);}glDeleteShader(vert);glDeleteShader(frag);return p;
}
int main(int argc,char **argv){@autoreleasepool {
    if(argc<3)return 1;NSString *folder=@(argv[1]);float time=atof(argv[2]);
    CGLPixelFormatAttribute attrs[]={kCGLPFAOpenGLProfile,(CGLPixelFormatAttribute)kCGLOGLPVersion_3_2_Core,kCGLPFAAllowOfflineRenderers,(CGLPixelFormatAttribute)0};
    CGLPixelFormatObj pixel;GLint count;CGLContextObj ctx;
    if(CGLChoosePixelFormat(attrs,&pixel,&count)||!count||CGLCreateContext(pixel,0,&ctx))return 2;CGLSetCurrentContext(ctx);
    printf("Renderer: %s\n",glGetString(GL_RENDERER));
    NSArray *skins=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[folder stringByAppendingPathComponent:@"render-inputs.json"]] options:0 error:nil];
    NSMutableDictionary *programs=[NSMutableDictionary dictionary];
    for(NSString *name in @[@"flat",@"tide",@"accretion",@"solid_skin",@"aurora",@"cinder_flame"])programs[name]=@(program([folder stringByAppendingPathComponent:@"glsl"],name));
    const int W=1600,H=640,TW=320,TH=320;GLuint fbo,texture,depth,vao;glGenFramebuffers(1,&fbo);glBindFramebuffer(GL_FRAMEBUFFER,fbo);glGenTextures(1,&texture);glBindTexture(GL_TEXTURE_2D,texture);glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA8,W,H,0,GL_RGBA,GL_UNSIGNED_BYTE,0);glFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D,texture,0);glGenRenderbuffers(1,&depth);glBindRenderbuffer(GL_RENDERBUFFER,depth);glRenderbufferStorage(GL_RENDERBUFFER,GL_DEPTH_COMPONENT24,W,H);glFramebufferRenderbuffer(GL_FRAMEBUFFER,GL_DEPTH_ATTACHMENT,GL_RENDERBUFFER,depth);
    if(glCheckFramebufferStatus(GL_FRAMEBUFFER)!=GL_FRAMEBUFFER_COMPLETE)return 5;
    glGenVertexArrays(1,&vao);glBindVertexArray(vao);glClearColor(.84,.92,1,1);glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);glEnable(GL_DEPTH_TEST);glDisable(GL_CULL_FACE);glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
    int si=0;
    for(NSDictionary *skin in skins){glViewport((si%5)*TW,(1-si/5)*TH,TW,TH);
        for(int pass=0;pass<2;pass++)for(NSDictionary *mesh in skin[@"meshes"]){BOOL transparent=[mesh[@"transparent"] boolValue];if(transparent!=(pass==1))continue;
            NSString *name=[mesh[@"shader"] length]?[[mesh[@"shader"] lastPathComponent] stringByDeletingPathExtension]:@"flat";GLuint p=[programs[name] unsignedIntValue];glUseProgram(p);
            glUniform1f(glGetUniformLocation(p,"fx_time"),time);
            // Reset optional parameters because multiple skins share programs.
            for(NSString *key in @[@"spectral",@"lensed",@"splash",@"phase_shift",@"warmth"])glUniform1f(glGetUniformLocation(p,key.UTF8String),0);
            for(NSString *key in mesh[@"params"]){id value=mesh[@"params"][key];GLint location=glGetUniformLocation(p,key.UTF8String);if([value isKindOfClass:[NSArray class]]){glUniform4f(location,[value[0] floatValue],[value[1] floatValue],[value[2] floatValue],[value[3] floatValue]);}else if([key isEqualToString:@"style"])glUniform1i(location,[value intValue]);else glUniform1f(location,[value floatValue]);}
            NSArray *positions=mesh[@"positions"],*uvs=mesh[@"uvs"],*indices=mesh[@"indices"];NSUInteger n=positions.count/3;
            float *vertices=malloc(n*5*sizeof(float));for(NSUInteger i=0;i<n;i++){for(int k=0;k<3;k++)vertices[i*5+k]=[positions[i*3+k] floatValue];for(int k=0;k<2;k++)vertices[i*5+3+k]=[uvs[i*2+k] floatValue];}
            GLuint *ix=malloc(indices.count*sizeof(GLuint));for(NSUInteger i=0;i<indices.count;i++)ix[i]=[indices[i] unsignedIntValue];GLuint buffers[2];glGenBuffers(2,buffers);glBindBuffer(GL_ARRAY_BUFFER,buffers[0]);glBufferData(GL_ARRAY_BUFFER,n*5*sizeof(float),vertices,GL_STATIC_DRAW);glBindBuffer(GL_ELEMENT_ARRAY_BUFFER,buffers[1]);glBufferData(GL_ELEMENT_ARRAY_BUFFER,indices.count*sizeof(GLuint),ix,GL_STATIC_DRAW);glEnableVertexAttribArray(0);glEnableVertexAttribArray(1);glVertexAttribPointer(0,3,GL_FLOAT,GL_FALSE,5*sizeof(float),0);glVertexAttribPointer(1,2,GL_FLOAT,GL_FALSE,5*sizeof(float),(void*)(3*sizeof(float)));
            if(transparent){glEnable(GL_BLEND);glDepthMask(GL_FALSE);}else{glDisable(GL_BLEND);glDepthMask(GL_TRUE);}
            glDrawElements(GL_TRIANGLES,(GLsizei)indices.count,GL_UNSIGNED_INT,0);glDeleteBuffers(2,buffers);free(vertices);free(ix);
        }si++;
    }
    unsigned char *bytes=malloc(W*H*4);glReadPixels(0,0,W,H,GL_RGBA,GL_UNSIGNED_BYTE,bytes);GLenum error=glGetError();if(error){fprintf(stderr,"GL error %u\n",error);return 6;}
    NSString *output=[folder stringByAppendingPathComponent:[NSString stringWithFormat:@"shader-frame-%.1f.ppm",time]];FILE *f=fopen(output.UTF8String,"wb");fprintf(f,"P6\n%d %d\n255\n",W,H);for(int y=H-1;y>=0;y--)for(int x=0;x<W;x++)fwrite(bytes+(y*W+x)*4,1,3,f);fclose(f);free(bytes);printf("Compiled 5 shipped shader programs; rendered %d skins at %.1fs\n",si,time);
    glDeleteVertexArrays(1,&vao);glDeleteFramebuffers(1,&fbo);glDeleteTextures(1,&texture);glDeleteRenderbuffers(1,&depth);for(NSNumber *p in programs.allValues)glDeleteProgram(p.unsignedIntValue);CGLSetCurrentContext(0);CGLDestroyContext(ctx);CGLDestroyPixelFormat(pixel);return 0;
}}
