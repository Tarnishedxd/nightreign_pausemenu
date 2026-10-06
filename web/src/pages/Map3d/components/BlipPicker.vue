<template>
	<div class="flex min-h-0 flex-col gap-2">
		<div class="relative h-10 w-full shrink-0 rounded-sm bg-black/75 ring-1 ring-inset ring-white/15">
			<input
				v-model="query"
				type="text"
				:placeholder="_t('ui.map3d.search', 'Search blips')"
				class="h-full w-full bg-transparent py-0 pl-3 pr-9 text-sm text-white outline-none placeholder:text-white/35" />
			<Search :size="iS(16)" class="pointer-events-none absolute right-2.5 top-1/2 -translate-y-1/2 text-white/45" />
		</div>
		<p v-if="filtered.length === 0" class="py-6 text-center text-sm text-white/45">
			{{ _t("ui.map3d.noBlips", "No blips found") }}
		</p>
		<!-- ~870 icons, about 24 on screen: only the rows in view (plus one either side) are rendered -->
		<div
			v-else
			ref="scroller"
			class="max-h-36 overflow-y-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
			@scroll.passive="onScroll">
			<div class="relative" :style="{ height: `${totalHeight}px` }">
				<div class="absolute inset-x-0 top-0 grid grid-cols-6 gap-1" :style="{ transform: `translateY(${offsetY}px)` }">
					<button
						v-for="blip in visible"
						:key="blip.name"
						type="button"
						class="grid h-9 w-full place-items-center rounded-sm transition duration-150 active:scale-[0.98]"
						:class="
							blip.name === modelValue
								? 'bg-[var(--panel-primary)] text-[var(--panel-ink)]'
								: 'map-bar ring-1 ring-inset ring-white/15'
						"
						@click="emit('update:modelValue', blip.name)">
						<BlipIcon :sprite="blip.name" :colour="colour" :size="iS(20)" />
					</button>
				</div>
			</div>
		</div>
	</div>
</template>

<script setup lang="ts">
import { Search } from "@lucide/vue";

withDefaults(
	defineProps<{
		modelValue: string;
		colour?: string;
	}>(),
	{ colour: "#ffffff" },
);

const emit = defineEmits<{
	"update:modelValue": [value: string];
}>();

const query = ref("");

const COLUMNS = 6;
const scroller = ref<HTMLElement | null>(null);
const scrollTop = ref(0);
const viewHeight = ref(0);
const remPx = ref(16);

// h-9 buttons with a gap-1 between rows: 2.5rem per row, in the current UI scale
const rowPitch = computed(() => remPx.value * 2.5);
const rowGap = computed(() => remPx.value * 0.25);

const measure = () => {
	remPx.value = Number.parseFloat(getComputedStyle(document.documentElement).fontSize) || 16;
	viewHeight.value = scroller.value?.clientHeight || remPx.value * 9;
};
const onScroll = () => {
	scrollTop.value = scroller.value?.scrollTop ?? 0;
};

const filtered = computed(() => {
	const needle = query.value.trim().toLowerCase();
	const list = needle
		? blipMetas.filter((blip) => {
				if (blip.name.toLowerCase().includes(needle)) return true;
				if (blip.id !== null && String(blip.id).includes(needle)) return true;
				return false;
			})
		: blipMetas;
	return [...list].sort((a, b) => {
		if (a.id !== null && b.id !== null) return a.id - b.id;
		if (a.id !== null) return -1;
		if (b.id !== null) return 1;
		return a.name.localeCompare(b.name);
	});
});

const rowCount = computed(() => Math.ceil(filtered.value.length / COLUMNS));
const totalHeight = computed(() => Math.max(0, rowCount.value * rowPitch.value - rowGap.value));
const firstRow = computed(() => Math.max(0, Math.floor(scrollTop.value / rowPitch.value) - 1));
const lastRow = computed(() =>
	Math.min(rowCount.value, Math.ceil((scrollTop.value + (viewHeight.value || remPx.value * 9)) / rowPitch.value) + 1),
);
const offsetY = computed(() => firstRow.value * rowPitch.value);
const visible = computed(() => filtered.value.slice(firstRow.value * COLUMNS, lastRow.value * COLUMNS));

watch(query, () => {
	scrollTop.value = 0;
	if (scroller.value) scroller.value.scrollTop = 0;
});
watch(scroller, () => measure());

onMounted(() => {
	measure();
	window.addEventListener("resize", measure);
});
onUnmounted(() => {
	window.removeEventListener("resize", measure);
});
</script>
