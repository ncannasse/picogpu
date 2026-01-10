# Pico GPU

Pico GPU is a 300KB memory GPU intended to learn, experiment and have fun with shaders. It is perfect to easily create small demos or games involving 3D rendering.

<img width="640" height="480" alt="image" src="https://github.com/user-attachments/assets/252542a2-fb4d-48bd-a4f9-e15ec9916a24" />

# Specifications

Pico GPU specification are:
- 640x480 resolution at 60FPS, with 24 bit depth and 8 bit stencil
- 300KB gpu memory to load your textures, buffers, code and shaders
- 4 channels Mono 32 bit sound synthesis at 48 KHz (using GPU shaders)
- complete support for vertex & fragment buffers
- support blending, culling, depth, stencil, color mask, clipping
- support render targets and instancing
- maths matrix, vector, quaternion support
- save & load as a 640x480 PNG screenshot that contains all your data
- share your apps with the community!

# Introduction

In order to get started with Pico GPU, let's explain the main interface elements first (see picture above);

- **Code**: this allows you to edit your CPU code. The CPU code is run once when you start your app, then the `update()` function is called every frame. The CPU code will execute GPU draw calls in order to display things on screen.
- **Render** : in the top right of the window, you can see your app being rendered. The app will restart when you change the code, a shader, the memory, etc.
- **Log** : at the bottom right of the window, you can log what you want using the `trace()` command in your CPU code.
- **Shaders** : in this section, you can edit your different shaders. You can have up to 16 different shaders, and they can be referenced by number in your CPU code when using `setShader()` or `setShaders()` functions. Pico GPU uses runtime shader assembling you can actually have more than 16 shaders by combining different shaders when performing a draw. See *Shaders* section below for more details.
- **Memory** : your Pico GPU can use up to 300KB of memory. You can have up to 16 different memory buffers to store textures, vertex or index buffers, but also render targets or depth textures. See *Memory* section below for more details.
- **Samples** : Pico GPU comes with some samples that you can edit and modify freely to experiment with shaders.
- **Run** : you can press `F5` to run your app at any time, it will start immediately. Use `Esc` to exit and return to edit mode. Using Ctrl+F5 can start it in fullscreen (if run with HashLink).
- **Save/Load** : you can load & save your app as a PNG file that will contain all your app source data. If you want to Save as a new file you can hold Ctrl when clicking Save. You can also use Ctrl+S at any time to save your app.

# Code

The code input follows the [Haxe](https://haxe.org) syntax and is run using the [HScript](https://github.com/HaxeFoundation/hscript) interpreter.

### Syntax

You can read a complete syntax guide in [haxe manual](https://haxe.org/manual/expression.html), but if you are familiar with C or Javascript, this should be pretty straightforward.

Please note that PicoGPU code is type checked, so you will get an error if you use an invalid identifier or make type errors additionally to syntax errors. The errors are displayed in real time as you type, so no need for compilation.

### Execution

When something is modified, the PicoGPU code will get executed. Then every frame the `update()` function will be called, so you can display one frame. Here's a small example that will simply clear the screen every frame:

```
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

# Code API

This is a complete list of the available API functions:

### Memory

- `loadBuffer(buffer:Int):Buffer`<br>Load the memory buffer at the given Memory index [0-15].
- `loadTexture(buffer:Int):Texture`<br>Load the texture from the memory buffer at the given Memory index.
- `loadStorage(name:String):Buffer`<br>Load a 256 bytes persistent storage buffer with the given unique name. This can be used to save your game progression. The buffer will be saved on the local browser/computer for all apps and can be read or written by other apps so make sure to have a unique specific name such as `author(game-name)`.

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
- `drawInstance(buffer:Buffer,instanceBuffer:Buffer,count:Int,?index:Buffer)`<br>This allows you to perform several draw in a single call. All `@perInstance` shader parameters are stored in the `instanceBuffer` and `count` tells how many instances to draw. See the `DrawInstanced` sample for a complete tutorial. The main advantage of `drawInstance` is better performances for static data that needs to be draw every frame.
- `clear(color:Vec4)`<br>Clear the current target texture with the given RGBA color value.
- `clearDS(?depth:Float,?stencil:Int)`<br>Clear, the depth and/or stencil values for the current target texture.

### Drawing Configuration

These functions allow you to customize the way the drawing calls will render on the screen.

- `cull(face:Int)`<br>Change the face culling for the draw calls. You can use `cull(0)` to disable culling, so your triangle will be draw from both faces, or `cull(1)` so that all forward facing triangles will be discarded, or `cull(-1)` to discard backward facing triangles.
- `blend(src:Blend,dst:Blend)`<br>change the blending between the source (your shader pixel) and the destination (the target pixel it blends with).<br>
  This will do the formula `outputColor = shaderPixel * srcBlend + currentPixel * dstBlend`.<br>
  For instance to have opaque pixels, you can do `blend(Blend.ONE,Blend.ZERO)` which will do `outputColor = shaderPixel * 1 + currentPixel * 0 = shaderPixel`.<br>
  Or if you want to perform transparency based on the alpha value of your shader pixel, use `blend(Blend.SRC_ALPHA,Blend.ONE_MINUS_SRC_ALPHA)` which will do `outputColor = shaderPixel * shaderPixel.a + currentPixel * (1 - shaderPixel.a)`.<br>
  There are many other combinations available with the different blending values.
- `colorMask(mask:Int)`<br>Change which RGBA channels are written in the output texture. For instance `colorMask(1)` will only write the red channel, `colorMask(10)` will write the alpha (8) and green (2) channels, and `colorMask(15)` will write all RGBA channels.
- `clip(x:Int=0,y:Int=0,width:Int=-1,height:Int-1)`<br>Set a rectangle that will restrict all draw calls to this area. Every pixel outside will be discarded.
- `depth(comp:Compare,write:Bool=true)`
- `stencil(op:StencilOp,fail:StencilOp,pass:StencilOp,front:Bool=true)`
- `stencilFunc(comp:Compare,reference:Int=0,readMask:Int=0xFF,writeMask:Int=0xFF)`
- `setTarget(?t:Texture,?depth:Buffer)`<br>Change the rendering so all further draw operations are done on the target texture. If `depth` is specified, then this will also attach a depth buffer to the target texture.<br>Use `setTarget()` to return to the drawing on screen and default depth buffer.

### Sound

- `setChannel(channel:Int,shader:Int)`<br>Set the shader for the given sound channel. `channel` is a [0-3] index for one of the 4 sound channels. `shader` is an index for a shader writing the `sound` Float variable. You can set the shader to `-1` to disable the sound channel.

### Maths

### Buffer Object

### Texture Object


# Memory

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

# Shaders

TBC

# Sound

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
