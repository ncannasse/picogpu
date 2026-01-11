<canvas id="webgl" style="width:640px;height:480px;align:middle"></canvas>

<script>
	var id;
	function onReady() {
		clearTimeout(id);
		if( !window.picoGpuStart() )
			window.location.reload();
	}
	if( typeof window != 'undefined' )
		id = setTimeout(onReady,100);
</script>
