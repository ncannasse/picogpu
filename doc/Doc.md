# Documentation

In order to get started with Pico GPU, let's explain the main interface elements first (see picture above);

- **Code**: this allows you to edit your CPU code. The CPU code is run once when you start your app, then the `update()` function is called every frame. The CPU code will execute GPU draw calls in order to display things on screen.

- **Render** : in the top right of the window, you can see your app being rendered. The app will restart when you change the code, a shader, the memory, etc.

- **Log** : at the bottom right of the window, you can log what you want using the `trace()` command in your CPU code.

- **Shaders** : in this section, you can edit your different shaders. You can have up to 16 different shaders, and they can be referenced by number in your CPU code when using `setShader()` or `setShaders()` functions. Pico GPU uses runtime shader assembling you can actually have more than 16 shaders by combining different shaders when performing a draw. See *Shaders* section below for more details.

- **Memory** : your Pico GPU can use up to 300KB of memory. You can have up to 16 different memory buffers to store textures, vertex or index buffers, but also render targets or depth textures. See *Memory* section below for more details.

- **Samples** : Pico GPU comes with some samples that you can edit and modify freely to experiment with shaders.

- **Run** : you can press `F5` to run your app at any time, it will start immediately. Use `Esc` to exit and return to edit mode. Using Ctrl+F5 can start it in fullscreen (if run with HashLink).

- **Save/Load** : you can load & save your app as a PNG file that will contain all your app source data. If you want to Save as a new file you can hold Ctrl when clicking Save. You can also use Ctrl+S at any time to save your app.

## Code

The code input follows the [Haxe](https://haxe.org) syntax and is run using the [HScript](https://github.com/HaxeFoundation/hscript) interpreter.

### Syntax

You can read a complete syntax guide in [haxe manual](https://haxe.org/manual/expression.html), but if you are familiar with C or Javascript, this should be pretty straightforward.

Please note that PicoGPU code is type checked, so you will get an error if you use an invalid identifier or make type errors additionally to syntax errors. The errors are displayed in real time as you type, so no need for compilation.

### Execution

When something is modified, the PicoGPU code will get executed. Then every frame the `update()` function will be called, so you can display one frame. Here's a small example that will simply clear the screen every frame:

```haxe
var time = 0.;
function update() {
    time += 1/60;
    clear(vec4(time%1));
}
```

### Drawing

In order to draw things on screen, you need to do the following:
- configure your draw call with functions such as `cull()`
- select your shaders using `selectShader` or `selectShaders`. See *Shaders* section below for more details. 
- set the shader parameters with `setParam` and `setGlobal`
- set the camera with `setCamera`
- perform one or several draw calls with `draw()` or `drawInstance()` using one or several buffers that contains your GPU data.

### API

In order to know what are the functions you can use, you have access to the following:
- all methods that are part of the `PicoApi` class can be accessed globally. See list [here](#code-api)
- The `Key`, `Blend`, `Compare`, `Stencil` and `Math` classes are also globally accessible
- The `trace()` function can add something to the log, for debugging purposes.

### Screenshot

When saving, the `function screenshot() {}` function will be called instead of `update()` if it exists, allowing you to display a custom screen that will be used for your save PNG.

## Code API

This is a complete list of the available API functions:

### Memory

- `loadBuffer(buffer:Int):Buffer`<br>Load the memory buffer at the given Memory index [0-15].
- `loadTexture(buffer:Int):Texture`<br>Load the texture from the memory buffer at the given Memory index.
- `loadStorage(name:String):Buffer`<br>Load a 256 bytes persistent storage buffer with the given unique name. This can be used to save your game progression. The buffer will be saved on the local browser/computer for all apps and can be read or written by other apps so make sure to have a unique specific name such as `author(game-name)`.

### System

- `trace(arg1:*,?arg2:*,...)`<br>Output any number of values to the log. This will also display the current script line number.
- `error(value:*)`<br>Output an error in red in the log. Do not repeat if the same error is already the latest log message.
- `stop()`<br>Stop the app execution.
- `time() : Float`<br>Return the time in seconds since the app started.
- `date() : Float`<br>Return the current date in seconds since January 1st 1970.

### Shaders

- `setShader(shader:Int)`<br>Set the current shader used for drawing. The `shader` index is a [0-15] integer, one of the 16 shaders defined for your program.
- `setShaders(shaders:Array<Int>)`<br>Set the current shaders a combination of several shaders. This can be used to separate vertex & fragment shaders, or add special effects that only affect some intermediary calculus.
- `setParam(name:String,value:*)`<br>Set the parameter for current shader(s) that was set with `setShader`. Parameters are declared in shaders with `@param` and served as configuring the shader. The value can be an Int, Float, Vector, Matrix, Texture, Buffer, etc. It must match the shader declaration type or an error might occur when drawing. It is not possible to set a sound shader parameter, so use setGlobal instead.
- `setGlobal(name:String,value:*)`<br>This is similar to shader parameters except that globals are shared among all shaders and must be declared in shaders with `@global`.
- `setCamera(m:Matrix,?fovY:Float=25)`<br>This will set the global `cameraViewProj` with a correct perspective matrix with given vertical field of view angle (`fovY`). The `m` matrix gives the camera position and rotation. This is an utility function and you can directly set the `cameraViewProj` yourself.

### Controls

- `button() : Bool`<br>Tells if the main button is active. This can be the `E` or `Space` keys, or the pad `A` or `X` buttons, or the left mouse click.
- `button2() : Bool`<br>Tells if the secondary button is active. This can be the `R` or `Enter` keys, or the pad `B` or `Y` buttons, or the right mouse click.
- `dirX() : Float`<br>Tells the X direction we are moving. This can be with horizontal movement with keyboard `WASD` or arrow keys, or the game pad analog control (which will return values that can be < 1) or dpad.
- `dirY() : Float`<br>Similar to `dirX()` but gives the vertical direction.
- `mouseX() : Int`<br>Gives the mouse X position on screen.
- `mouseY() : Int`<br>Gives the mouse Y position on screen.

### Drawing

- `draw(buffer:Buffer)`<br>perform a draw call using the current selected shader and the given vertex buffer that contains vertex data. See [shaders](#shaders-1) to understand the structure of the buffer.
- `draw(buffer:Buffer,index:Buffer)`<br>same a `draw(buffer)` but use a index buffer that will store three I32 for each triangle. This allows to reuse the vertices in several triangles without having them repeated in the vertex buffer.
- `draw(buffer:Buffer,?index:Buffer,?startTri:Int=0,?drawTri:Int=-1)`<br>This is the complete signature of the `draw()` function, you can additionally draw a sub part of the buffer by specifying a starting triangle as `startTri` and the number of triangles to draw in `drawTri`
- `drawText(text:String)`<br>This will create a buffer of glyphs with (position:XY,uv:UV) format and draw it on screen. Positions are in screen pixel format and needs to be converted to screen position, and UV are used to sample the global `textFont` texture. See the sample **TextHelloWorld** for a full sample.
- `drawInstance(buffer:Buffer,instanceBuffer:Buffer,count:Int,?index:Buffer)`<br>This allows you to perform several draw in a single call. All `@perInstance` shader parameters are stored in the `instanceBuffer` and `count` tells how many instances to draw. See the `DrawInstanced` sample for a complete tutorial. The main advantage of `drawInstance` is better performances for static data that needs to be draw every frame.
- `clear(color:Vec4)`<br>Clear the current target texture with the given RGBA color value.
- `clearDS(?depth:Float,?stencil:Int)`<br>Clear, the depth and/or stencil values for the current target texture.

### Drawing Configuration

These functions allow you to customize the way the drawing calls will render on the screen.

- `cull(face:Int)`<br>Change the face culling for the draw calls. You can use `cull(0)` to disable culling, so your triangle will be draw from both faces, or `cull(1)` so that all forward facing triangles will be discarded, or `cull(-1)` to discard backward facing triangles.
- `alpha(b:Bool)`<br>Enable or disable alpha blending (transparency). You can customize blending even further with the `blend()` function.
- `clip(x:Int=0,y:Int=0,width:Int=-1,height:Int-1)`<br>Set a rectangle that will restrict all draw calls to this area. Every pixel outside will be discarded.
- `depth(b:Bool)`<br>Enable or disable depth comparison. When enabled, fragment pixels which have a higher Z will be discarded if there was a previous pixel with same or lower Z (more in front of the camera). When disabled, all pixels are always drawn and the draw call doesn't write into the depth buffer. You can customize even further with the `depthComp` function.
- `showTexture(tex:Texture)`<br>After finishing the update, will display the given texture on screen instead of the default output. This can be used as a shortcut to show a texture without a draw() or for debugging purposes to display what was draw into a render target.

### Advanced configuration

These functions allow you to further configuration the graphics rendering, but are more advanced/complex:

- `blend(src:Blend,dst:Blend)`<br>change the blending between the source (your shader pixel) and the destination (the target pixel it blends with).<br>
  This will do the formula `outputColor = shaderPixel * srcBlend + currentPixel * dstBlend`.<br>
  For instance to have opaque pixels, you can do `blend(Blend.ONE,Blend.ZERO)` which will do `outputColor = shaderPixel * 1 + currentPixel * 0 = shaderPixel`.<br>
  Or if you want to perform transparency based on the alpha value of your shader pixel, use `blend(Blend.SRC_ALPHA,Blend.ONE_MINUS_SRC_ALPHA)` which will do `outputColor = shaderPixel * shaderPixel.a + currentPixel * (1 - shaderPixel.a)`.<br>
  There are many other combinations available with the different blending values.
- `depthComp(comp:Compare,write:Bool=true)`<br>Set the depth comparison function, which will tell how to discard pixels. Also indicate if the draw call will or will not write into the depth buffer.
- `colorMask(mask:Int)`<br>Change which RGBA channels are written in the output texture. For instance `colorMask(1)` will only write the red channel, `colorMask(10)` will write the alpha (8) and green (2) channels, and `colorMask(15)` will write all RGBA channels.
- `stencil(op:StencilOp,fail:StencilOp,pass:StencilOp,front:Bool=true)`<br>Change the stencil operations for one of the two faces. Stencil operation are a complex but powerful way to display or hide some pixels based on previous draw calls. We won't document here the details on how to use stencil in details, but you can easily find some tutorials on the web.
- `stencilFunc(comp:Compare,reference:Int=0,readMask:Int=0xFF,writeMask:Int=0xFF)`)`<br>Change the stencil comparison function, reference value and read & write bit masks.
- `setTarget(?t:Texture,?depth:Buffer)`<br>Change the rendering so all further draw operations are done on the target texture. If `depth` is specified, then this will also attach a depth buffer to the target texture.<br>Use `setTarget()` to return to the drawing on screen and default depth buffer.
 

### Sound

- `setChannel(channel:Int,shader:Int)`<br>Set the shader for the given sound channel. `channel` is a [0-3] index for one of the 4 sound channels. `shader` is an index for a shader writing the `sound` Float variable. You can set the shader to `-1` to disable the sound channel.

### Maths

- `mat4(?arr:Array<Float>):Matrix`<br>Create a new 4x4 Matrix. This can be used to return an identity matrix with `mat4()` or load a matrix from 16 floats as a array.
- `vec4(?x:Float=0,?y:Float,?z:Float,?w:Float):Vector4`<br>Create a new 4-components vector. This can be used to create a single vector which all values have the same float value with `vec4(1)` for example.
- `vec3(?x:Float=0,?y:Float,?z:Float):Vector`<br>Create a new 3-components vector. This can be used to create a single vector which all values have the same float value with `vec3(1)` for example.
- `quat(?x:Float=0,?y:Float,?z:Float,?w:Float):Quat`<br>Create a 4-components Quaternion that can be used to represent a 3D rotation.
- `rnd(max:Float=1.0):Float`<br>Return a random Float number between 0 and the max specified (1 by default).
- `random(max:Int):Int`<br>Return a random integer number between 0 and the max specified.
abs(v:Float) : Float;

### Standard math functions

These are not documented as they are pretty straightforward. If you want some details you can them on [this page](https://api.haxe.org/Math.html)

- `cos(v:Float) : Float`
- `sin(v:Float) : Float`
- `tan(v:Float) : Float`
- `acos(v:Float) : Float`
- `asin(v:Float) : Float`
- `atan(v:Float) : Float`
- `atan2(y:Float,x:Float) : Float`
- `ceil(v:Float) : Float`
- `floor(v:Float) : Float`
- `round(v:Float) : Float`
- `exp(v:Float) : Float`
- `log(v:Float) : Float`
- `min(a:Float,b:Float) : Float`
- `max(a:Float,b:Float) : Float`
- `imin(a:Int,b:Int) : Int`
- `imax(a:Int,b:Int) : Int`
- `pow(a:Float,b:Float) : Float`
- `sqrt(v:Float) : Float`

### Buffer Object

- `buf.length : Int`<br>The buffer length in number of bytes. Read only.
- `buf.getI32(n:Int):Int`<br>Read the n-th int32 and returns it.
- `buf.getF32(n:Int):Float`<br>Read the n-th float32 and returns it.
- `buf.setI32(n:Int,v:Int)`<br>Set the n-th int32 value. Changing the buffer data will require setting it again for shaders.
- `buf.setF32(n:Int,v:Float)`<br>Set the n-th float32 value. Changing the buffer data will require setting it again for shaders.
- `buf.setVec(n:Int,v:Vec4)`<br>Shortcut to set the four consecutive Floats components of the Vec4
- `buf.setMat(n:Int,m:Matrix)`<br>Shortcut to set the 16 consecutive Floats components of the Matrix.
- `buf.setMat3x4(n:Int,m:Matrix)`<br>Shortcut to set the 12 consecutive Floats components of the Matrix.
- `buf.getTexture(?fmt:Format):Texture`<br>Converts the buffer into a texture with the given format.

### Texture Object

- `tex.width : Int`<br>The width in pixels of the texture. Read only.
- `tex.height : Int`<br>The height in pixels of the texture. Read only.
- `tex.format : Format`<br>The format of the texture. Read only.
- `tex.filter(b:Bool)`<br>Change the filtering mode of the texture. When enable, the texture samples will use bilinear filtering. When disabled (default), it will return the nearest pixel.
- `tex.wrap(b:Bool)`<br>Change the wrapping mode of the texture. When enable (default), sampling the texture outside of the [0-1] coordinates will wrap. When disabled, it will clamp to the border pixel.
- `tex.isDisposed() : Bool`<br>Tells if the texture has been disposed (because its corresponding buffer has been modified).

## Memory

PicoGPU allows to create up to 16 cpu-gpu data banks, with up to 300KB of total memory.
These data banks can be used:
- as CPU memory, they can be read and written
- as GPU memory, for representing a vertex or index buffer
- as GPU memory, for representing a texture

<img width="646" height="495" alt="image" src="https://github.com/user-attachments/assets/09f23286-d455-4bfa-aae9-ad3459085e76" />

There are several types of data banks:
- **Undef** is empty data bank that can be initialized
- **I32** contains an array of 32 bit integer values.
- **F32** contains an array of 32 bit float values.
- **Texture** is a reference to texture pixels, additionally to a width,height and pixel format.

You can initialize a memory bank by switching its type. Click on the **Undef** (or other type) button and select the type you want.

You can also select **Import** in order to import either a WAV file (which will be converted to a 48Khz F32 buffer) or any binary file (which will be kept as raw **I32** bytes).

In **I32** and **F32** mode, there are two possible syntax: either `[1,-1,0,4...]` with one number per element or `[0][256]` for an array of 256 elements all initialized with 0. If you are using one number per element, you can adjust the display stride (number of elements per line) with the `+` and `-` buttons.

The **Size** is the amount of memory for this bank. It will be 4 bytes per array element or texture pixel.

### Loading Memory

You can load your memory bank in code using `loadMemory(index)` with index being 0 to 15 slot index of your memory bank.
Once a memory bank is loaded, you can read/write it with CPU code `setI32/setF32` and other methods. You can then convert the memory bank to a texture using `bank.getTexture()`, or use the shortcut `loadTexture(index)` which is similar to `loadMemory(index).getTexture()`.

### Memory buffers

When drawing, your buffer memory layout must match your shader input. So if you have two inputs `@input var pos : Vec3` and `@input var uv : Vec2` then you need to have 5 float32 per pertex, in the order declared in your shader. For index buffers, it's one I32 per index.

## Shaders

This is a simple shader:

```haxe
@input var pos : Vec3;
@global var cameraViewProj : Mat4;

var outputPosition : Vec4;
var outputColor : Vec4;

function vertex() {
	outputPosition = vec4(pos,1) * cameraViewProj;
}

function fragment() {
	outputColor = vec4(1);
}
```

Drawing 3D content on screen will be performed in several steps:

First, the **vertexes buffer** that you pass as parameter to the `draw()` call contain several vertex. Each of these vertex will go through the **vertex shader** first.

For each vertex, the data is extracted from the vertexes buffer based on the `@input` shader variables. In this shader case, we expect the vertex buffer to contain three floats (X,Y,Z) per vertex, which will be loaded into the `pos` variable.

Then for each vertex, the `function vertex()` is called inside the shader. This is called the **vertex shader**. Please note that shaders are executed by the GPU, so the code here is slightly different than in your application code.

The role of the **vertex shader** is to transform each vertex coordinate from a 3D position into a 2D one that is on screen. This is performed by the operation `vec4(pos,1) * cameraViewProj` which will expand the (X,Y,Z) into (X,Y,Z,1) vector, then multiply it by the camera view and projection matrix to get a new 2D position (X,Y,Z,W). The X and Y coordinates are screen coordinates in the [-1,1] range, (0,0) beeing the center of the screen. And the Z and W coordinates are used for perspective correction and depth calculus. Once you have written the `outputPosition` the vertex shader has finished its job.

Once three vertex have been projected in 2D screen coordinates, they form a triangle and this triangle will be rasterized on screen, pixel by pixel. In order to compute the color of each pixel, we need to use a **fragment shader** (also called *pixel shader*).

In our example, for each pixel we will return the white opaque pixel which is (1,1,1,1), as four values between [0-1] in RGBA values.
You can change it to `vec4(1,0,0,1)` to have an opaque red for example.

### Testing

In order to test this shader, you can use the following code:

```haxe
// setup the camera
var m = mat4();
m.rotate(1,2,3);
m.translate(0,0,4);
setCamera(m);
// draw every frame
function update() {
	var buf = loadBuffer(0);
	setShader(0);
	draw(buf);
}
```

And you need to set the Memory 0 bank to F32 and enter the following value that will represent a 3D cube (X,Y,Z) x 12 faces = 36 values.

```
[
-0.5, -0.5, -0.5, 0.5, -0.5, -0.5, 0.5, -0.5, 0.5, 
-0.5, -0.5, -0.5, 0.5, -0.5, 0.5, -0.5, -0.5, 0.5, 
0.5, -0.5, -0.5, 0.5, 0.5, -0.5, 0.5, 0.5, 0.5, 
0.5, -0.5, -0.5, 0.5, 0.5, 0.5, 0.5, -0.5, 0.5, 
-0.5, -0.5, 0.5, 0.5, -0.5, 0.5, 0.5, 0.5, 0.5, 
-0.5, -0.5, 0.5, 0.5, 0.5, 0.5, -0.5, 0.5, 0.5, 
-0.5, -0.5, -0.5, -0.5, 0.5, 0.5, -0.5, 0.5, -0.5, 
-0.5, -0.5, -0.5, -0.5, -0.5, 0.5, -0.5, 0.5, 0.5, 
-0.5, 0.5, -0.5, 0.5, 0.5, 0.5, 0.5, 0.5, -0.5, 
-0.5, 0.5, -0.5, -0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 
-0.5, -0.5, -0.5, 0.5, 0.5, -0.5, 0.5, -0.5, -0.5, 
-0.5, -0.5, -0.5, -0.5, 0.5, -0.5, 0.5, 0.5, -0.5, 
]
```

### Textures

Texture are images that are stored on the GPU that can be read, usually in the fragment shader, in order to display some pixels on the triangle.

In order to read a texture, you need first to add an image to the Memory bank #1. Open it and change from `Undef` to `Texture`. Choose a texture that is not too big for PicoGPU memory. Then add the following line in your `update()` function before the `draw()` and after the `setShader(0)`:

```haxe
setParam("tex",loadTexture(1));
```

And change your fragment shader with the following code:

```haxe
@param var tex : Sampler2D;

function fragment() {
	outputColor = tex.get(vec2(0,0));
}
```

This will change the color of your cube. However you will notice that the color is uniform. This is because for each pixel calculated by the fragment shader, we are only reading the top left pixel of the texture at (0,0). If we want to map the texture to our cube face, we need to use **texture coordinates** (also called *UV coordinates*).

These can be written into variable by the **vertex shader** (one value per each vertex). They will then get *interpolated* for each pixel so you will get a unique per pixel value in the fragment shader. 

Here's our final shader code:

```haxe
@input var pos : Vec3;
@global var cameraViewProj : Mat4;

var outputPosition : Vec4;
var outputColor : Vec4;
var uv : Vec2;

function vertex() {
	outputPosition = vec4(pos,1) * cameraViewProj;
	uv = pos.zy + vec2(0.5);
}

@param var tex : Sampler2D;

function fragment() {
	outputColor = tex.get(uv);
}
```

In order to correctly map all of the faces of your cube, you will need appropriate UV coordinates per vertex in your **vertexes buffer**.

## Sound

In order to synthetize sound & musics, you have a single function that allows you to assign a shader to one of the four sound channels:
`setChannel(0,1)` will assign the shader 1 to the sound channel 0.

The shader will then need to generate some data by writing the `sound` variable with a value between -1 and 1.

Here's a very simple single-note 440Hz sound shader:

```haxe
var time : Float;
var sound : Float;
function fragment() {
    var t = time * 440;
    sound = sin(t.fract() * 2 * PI);
}
```

### Playing notes

And here's a more complex one playing several notes:

```haxe
var time : Float;
var sound : Float;

// the partition (3 notes)
var notes = [0,1,2,2,0,1,2,2,0,2,1,0,1,2];
// the frequency of each note
var freq = [440,349,293];
// the number of notes played per second
var bpm = 4;

function fragment() {
	var n = notes[int(time*bpm)%notes.length];
	var t = freq[n] * time;
	sound = sin(t.fract() * PI * 2);
}
```

You can try this sample by loading the **Sound** sample.

Or if you prefer a more old 8-bit style square wave:

```haxe
sound = step(0.5,t.fract());
```

### Playing custom sounds

In order to play WAV sounds, you must first import them into a Memory Buffer. Use the Memory **Import** function to convert the WAV into the corresponding 32 bit F32 buffer. Then you can read this buffer in your shader to output it into the sound channel. An example of this can be found in the `Sound` Sample.
