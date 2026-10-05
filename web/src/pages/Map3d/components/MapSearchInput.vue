<template>
	<div class="absolute left-1/2 top-6 z-[3] w-[28rem] -translate-x-1/2">
		<div class="map-bar relative h-10 w-full ring-1 ring-inset ring-white/15">
			<input
				v-model="query"
				type="text"
				:placeholder="_t('ui.map.search', 'Search for a location')"
				class="h-full w-full bg-transparent py-0 pl-4 pr-9 text-sm text-white outline-none placeholder:text-white/40" />
			<Search :size="iS(16)" class="pointer-events-none absolute right-2.5 top-1/2 -translate-y-1/2 text-white/45" />
		</div>
		<div
			v-if="results.length"
			class="absolute left-0 right-0 top-full z-20 mt-0.5 flex flex-col gap-0.5">
			<button
				v-for="point in results"
				:key="point.id"
				type="button"
				class="map-bar flex h-11 w-full cursor-pointer items-center gap-2 px-3 text-left text-sm active:scale-[0.98]"
				@click="pick(point.id)">
				<BlipIcon :sprite="point.sprite" :colour="blipColourHex(point.blipColour ?? 3)" :size="iS(22)" />
				<span class="min-w-0 flex-1 truncate">{{ _t(point.label, point.label) }}</span>
				<span class="ml-auto shrink-0 tabular-nums text-white/70">{{ point.metres }}m</span>
			</button>
		</div>
	</div>
</template>

<script setup lang="ts">
import { Search } from "@lucide/vue";

const markers = useMarkersStore();
const { points } = storeToRefs(markers);
const query = ref("");

const results = computed(() => {
	const needle = query.value.trim().toLocaleLowerCase();
	if (!needle) return [];
	return points.value
		.filter((point) => _t(point.label, point.label).toLocaleLowerCase().includes(needle))
		.sort((a, b) => a.metres - b.metres)
		.slice(0, 3);
});

watch(
	results,
	(hits) => {
		const needle = query.value.trim();
		markers.setSearchHits(needle ? hits.map((point) => point.id) : null);
	},
	{ immediate: true },
);

onUnmounted(() => {
	markers.setSearchHits(null);
});

const pick = (id: string) => {
	markers.select(id);
	query.value = "";
	fetchNui("ThreeDMapFocus", { id }, "ok");
};
</script>
