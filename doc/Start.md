
<canvas id="webgl" style="width:100%;height:100%"></canvas>

<script setup>
	var id;
	function onReady() {
		var dpr = window.devicePixelRatio || 1;
		document.getElementById("content").parentElement.removeAttribute("vp-content");
		clearTimeout(id);
		if( !window.picoGpuStart() )
			window.location.reload();
	}
	if( typeof window != 'undefined' )
		id = setTimeout(onReady,100);
</script>
