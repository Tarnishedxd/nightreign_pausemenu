<template>
	<div class="absolute bottom-6 left-6 text-white">
		<div class="flex flex-wrap items-center gap-3">
			<div v-for="control in CONTROLS" :key="control.id" class="flex items-center gap-1.5 text-sm text-white/70">
				<span class="map-key">{{ control.key }}</span>
				<span>{{ control.label }}</span>
			</div>
		</div>
	</div>
</template>

<script setup lang="ts">
type Control = {
	id: string;
	key?: string;
	label: string;
};

const CONTROLS: Control[] = [
	{
		id: "pan",
		key: "LMB",
		label: _t("ui.controls.pan", "Pan"),
	},
	{
		id: "waypoint",
		key: "2 x LMB",
		label: _t("ui.controls.waypoint", "Set waypoint"),
	},
	{
		id: "rotate",
		key: "RMB",
		label: _t("ui.controls.rotate", "Rotate"),
	},
	{
		id: "zoom",
		key: "WHEEL",
		label: _t("ui.controls.zoom", "Zoom In/Out"),
	},
	{
		id: "focus",
		key: "SPACE",
		label: _t("ui.controls.focusPlayer", "Focus Player"),
	},
];
</script>
