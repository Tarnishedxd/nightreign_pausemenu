<template>
	<div class="pointer-events-none flex flex-col items-start text-white">
		<span class="text-lg font-semibold leading-tight">{{ title }}</span>
		<p class="mt-1 text-sm text-white/55">
			<span>{{ subtitle }}</span>
			<span class="mx-2 text-white/25">|</span>
			<span class="tabular-nums">{{ altitudeLabel }}</span>
		</p>
	</div>
</template>

<script setup lang="ts">
const store = useMainStore();
const { map } = storeToRefs(store);

const title = computed(() => map.value.zone || _t("ui.map3d.unknown", "Unknown"));
const subtitle = computed(() => map.value.street || _t("ui.map3d.unknown", "Unknown"));
const altitudeLabel = computed(() => `${map.value.altitude}m`);
</script>
