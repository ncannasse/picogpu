class PicoChannel {

	public static var BUFFER_SIZE = 3000;
	public static var FREQ = 48000;

	public var cpuBuffer : haxe.io.Bytes;
	public var bufferCount : Int = 0;

	var snd : hxd.snd.Driver;
	var buffer : hxd.snd.Driver.BufferHandle;
	var nextBuffer : hxd.snd.Driver.BufferHandle;
	var source : hxd.snd.Driver.SourceHandle;
	var consume : Int = 0;

	public function new(snd) {
		this.snd = snd;
		cpuBuffer = haxe.io.Bytes.alloc(BUFFER_SIZE << 2);
		buffer = snd.createBuffer();
		nextBuffer = snd.createBuffer();
		source = snd.createSource();
		start();
	}

	public function start() {
		consume = 0;
		snd.setBufferData(buffer, cpuBuffer, cpuBuffer.length>>1, F32, 1, FREQ);
		snd.setBufferData(nextBuffer, cpuBuffer.sub(cpuBuffer.length>>1,cpuBuffer.length>>1), cpuBuffer.length>>1, F32, 1, FREQ);
		snd.queueBuffer(source, buffer, 0, false);
		snd.queueBuffer(source, nextBuffer, 0, false);
		snd.playSource(source);
	}

	public function next() {
		consume = 0;
	}

	public function stop() {
		cpuBuffer.fill(0,cpuBuffer.length,0);
		bufferCount = 0;
	}

	public function update() {
		var n = snd.getProcessedBuffers(source);
		if( n == 0 )
			return consume >= 2;
		if( n == 2 ) {
			snd.unqueueBuffer(source, buffer);
			snd.unqueueBuffer(source, nextBuffer);
			// oops ! we are late
			snd.setBufferData(buffer, cpuBuffer, cpuBuffer.length>>1, F32, 1, FREQ);
			snd.setBufferData(nextBuffer, cpuBuffer.sub(cpuBuffer.length>>1,cpuBuffer.length>>1), cpuBuffer.length>>1, F32, 1, FREQ);
			snd.queueBuffer(source, buffer, 0, false);
			snd.queueBuffer(source, nextBuffer, 0, false);
			consume = 2;
		} else {
			snd.unqueueBuffer(source, buffer);
			// buffer was processed
			if( consume == 0 )
				snd.setBufferData(buffer, cpuBuffer, cpuBuffer.length>>1, F32, 1, FREQ);
			else
				snd.setBufferData(buffer, cpuBuffer.sub(cpuBuffer.length>>1,cpuBuffer.length>>1), cpuBuffer.length>>1, F32, 1, FREQ);
			consume++;
			snd.queueBuffer(source, buffer, 0, false);
			var n = nextBuffer;
			nextBuffer = buffer;
			buffer = n;
		}
		return consume >= 2;
	}

}
