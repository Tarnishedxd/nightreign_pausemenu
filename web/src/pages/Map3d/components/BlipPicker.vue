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
		<div
			v-else
			class="grid max-h-36 grid-cols-6 gap-1 overflow-y-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
			<button
				v-for="blip in filtered"
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
</script>
