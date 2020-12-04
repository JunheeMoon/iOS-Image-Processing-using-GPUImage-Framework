#import "GPUImageQuadGenerator.h"

NSString *const kGPUImageQuadGeneratorVertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 
 void main()
 {
     gl_Position = position;
 }
);

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
NSString *const kGPUImageQuadGeneratorFragmentShaderString = SHADER_STRING
(
 uniform lowp vec3 quadColor;
 
 void main()
 {
     gl_FragColor = vec4(quadColor, 1.0);
 }
);
#else
NSString *const kGPUImageQuadGeneratorFragmentShaderString = SHADER_STRING
(
 uniform vec3 quadColor;
 
 void main()
 {
     gl_FragColor = vec4(quadColor, 1.0);
 }
);
#endif

@interface GPUImageQuadGenerator()

- (void)generateQuadCoordinates;

@end

@implementation GPUImageQuadGenerator

@synthesize quadWidth = _quadWidth;

#pragma mark -
#pragma mark Initialization and teardown

- (id)init;
{
    if (!(self = [super initWithVertexShaderFromString:kGPUImageQuadGeneratorVertexShaderString fragmentShaderFromString:kGPUImageQuadGeneratorFragmentShaderString]))
    {
        return nil;
    }
    
    runSynchronouslyOnVideoProcessingQueue(^{
        quadWidthUniform = [filterProgram uniformIndex:@"quadWidth"];
        quadColorUniform = [filterProgram uniformIndex:@"quadColor"];
        
        self.quadWidth = 2.0;
        [self setQuadColorRed:1.0 green:0.0 blue:0.0];
    });
    
    return self;
}

- (void)dealloc
{
    if (quadCoordinates)
    {
        free(quadCoordinates);
    }
}

#pragma mark -
#pragma mark Rendering

- (void)generateQuadCoordinates;
{
    quadCoordinates = calloc(1024 * 4*100, sizeof(GLfloat));
}
 
NSUInteger maxBoxesIndex ;
NSUInteger currentBoxIndex;
NSUInteger currentVertexIndex;
- (void)renderQuadsFromArray:(GLfloat *)boxesArrayInercepts count:(NSUInteger)numberOfQuads frameTime:(CMTime)frameTime;
{
    if (self.preventRendering)
    {
        return;
    }
        
    if (quadCoordinates == NULL)
    {
        [self generateQuadCoordinates];
    }
    
    // Iterate through and generate vertices from the slopes and intercepts
    currentVertexIndex = 0;
    currentBoxIndex = 0;
    maxBoxesIndex = numberOfQuads *4;
    while(currentBoxIndex < maxBoxesIndex)
    {
        GLfloat minX = (boxesArrayInercepts[currentBoxIndex++]-0.5f)*2;
        GLfloat minY = (boxesArrayInercepts[currentBoxIndex++]-0.5f)*2;
        GLfloat maxX = (boxesArrayInercepts[currentBoxIndex++]-0.5f)*2;
        GLfloat maxY = (boxesArrayInercepts[currentBoxIndex++]-0.5f)*2;
        //NSLog(@" %d/%d %f %f %f %f",currentBoxIndex, maxBoxesIndex, minX, minY,maxX-minX, maxY-minY);
        quadCoordinates[currentVertexIndex++] = minX;
        quadCoordinates[currentVertexIndex++] = minY;
        quadCoordinates[currentVertexIndex++] = minX;
        quadCoordinates[currentVertexIndex++] = maxY;
        
        quadCoordinates[currentVertexIndex++] = minX;
        quadCoordinates[currentVertexIndex++] = maxY;
        quadCoordinates[currentVertexIndex++] = maxX;
        quadCoordinates[currentVertexIndex++] = maxY;
        
        quadCoordinates[currentVertexIndex++] = maxX;
        quadCoordinates[currentVertexIndex++] = maxY;
        quadCoordinates[currentVertexIndex++] = maxX;
        quadCoordinates[currentVertexIndex++] = minY;
        
        quadCoordinates[currentVertexIndex++] = maxX;
        quadCoordinates[currentVertexIndex++] = minY;
        quadCoordinates[currentVertexIndex++] = minX;
        quadCoordinates[currentVertexIndex++] = minY;
    }

    
    runSynchronouslyOnVideoProcessingQueue(^{
        [GPUImageContext setActiveShaderProgram:filterProgram];
        
        [self setFilterFBO];
        
        glClearColor(0.0, 0.0, 0.0, 0.0);
        glClear(GL_COLOR_BUFFER_BIT);
        
        glBlendEquation(GL_FUNC_ADD);
        glBlendFunc(GL_ONE, GL_ONE);
        glEnable(GL_BLEND);
        
        currentBoxIndex=0;
        /*
        while(currentBoxIndex < maxBoxesIndex)
        {
            GLfloat minX , minY,maxX, maxY ;
           minX= quadCoordinates[currentBoxIndex++] ;
           minY= quadCoordinates[currentBoxIndex++] ;
           maxX= quadCoordinates[currentBoxIndex++] ;
           maxY= quadCoordinates[currentBoxIndex++] ;
           if(minX>0&&maxY>0){
            //NSLog(@"glViewport XY WH : %f %f %f %f", minX, minY,maxX-minX, maxY-minY);
            //    NSLog(@" glViewport XY WH : %d/%d %f %f %f %f",currentBoxIndex, maxBoxesIndex, minX, minY,maxX-minX, maxY-minY);
            glViewport(minX, minY,maxX-minX, maxY-minY);
            glVertexAttribPointer(filterPositionAttribute, 2, GL_FLOAT, 0, 0, g_vertex_buffer_data);
            glDrawArrays(GL_LINE_STRIP, 0, 5);
            }else{
                currentBoxIndex+=4;
            }
        }
        */
        glVertexAttribPointer(filterPositionAttribute, 2, GL_FLOAT, 0, 0, quadCoordinates);
        glDrawArrays(GL_LINES, 0, currentVertexIndex/2);
        
       /* for(int i=0;i<100;i++){
        glViewport(100+i, 200+i,30, 30);
        glVertexAttribPointer(filterPositionAttribute, 2, GL_FLOAT, 0, 0, g_vertex_buffer_data);
        glDrawArrays(GL_LINE_STRIP, 0, 5);
        }*/
        glDisable(GL_BLEND);

        [self informTargetsAboutNewFrameAtTime:frameTime];
    });
}
- (void)renderToTextureWithVertices:(const GLfloat *)vertices textureCoordinates:(const GLfloat *)textureCoordinates sourceTexture:(GLuint)sourceTexture;
{
    // Prevent rendering of the frame by normal means
}

#pragma mark -
#pragma mark Accessors

- (void)setQuadWidth:(CGFloat)newValue;
{
    _quadWidth = newValue;
    [GPUImageContext setActiveShaderProgram:filterProgram];
    glLineWidth(newValue);
}

- (void)setQuadColorRed:(GLfloat)redComponent green:(GLfloat)greenComponent blue:(GLfloat)blueComponent;
{
    GPUVector3 quadColor = {redComponent, greenComponent, blueComponent};
    
    [self setVec3:quadColor forUniform:quadColorUniform program:filterProgram];
}


@end

