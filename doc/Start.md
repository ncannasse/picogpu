
<canvas id="webgl" style="width:100%;height:100%"></canvas>

<script setup>
	var id;
	function onReady() {
		var dpr = window.devicePixelRatio || 1;
		document.getElementById("webgl").style.minWidth = Math.round((window.innerWidth * 0.5) / dpr) + "px";
		document.getElementById("webgl").style.minHeight = Math.round((window.innerHeight * 0.8) / dpr) + "px";
		clearTimeout(id);
		if( !window.picoGpuStart() )
			window.location.reload();
	}
	if( typeof window != 'undefined' )
		id = setTimeout(onReady,100);
</script>
