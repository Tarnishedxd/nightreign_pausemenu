<template>
	<div class="relative z-30">
		<button
			type="button"
			class="map-bar flex w-full items-center justify-between gap-4 rounded-sm px-4 py-3 text-left ring-1 ring-inset ring-white/15 active:scale-[0.98]"
			@click="open = !open">
			<span class="flex items-center gap-2 text-sm font-medium text-white/90">
				<Palette :size="iS(16)" />
				{{ _t("ui.map3d.blipColourId", "Blip colour") }}
			</span>
			<span class="flex items-center gap-2">
				<span class="h-7 w-7 shrink-0 rounded-sm ring-1 ring-inset ring-white/20" :style="{ background: current.hex }" />
				<span class="tabular-nums text-sm text-white/55">{{ modelValue }}</span>
			</span>
		</button>
		<div
			class="overflow-hidden transition-[max-height,opacity] duration-300 ease-out"
			:class="open ? 'max-h-72 opacity-100' : 'max-h-0 opacity-0'">
			<div
				class="map-bar mt-0.5 max-h-64 overflow-y-auto rounded-sm p-3 ring-1 ring-inset ring-white/15 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
				<div class="grid grid-cols-8 gap-1">
					<button
						v-for="swatch in BLIP_COLOUR_SWATCHES"
						:key="swatch.id"
						type="button"
						class="relative aspect-square rounded-sm ring-1 ring-inset transition duration-150 active:scale-[0.96]"
						:class="swatch.id === modelValue ? 'ring-2 ring-white' : 'ring-white/20'"
						:style="{ background: swatch.hex }"
						:title="`${swatch.id} · ${swatch.name}`"
						@click="pick(swatch.id)">
						<span
							v-if="swatch.id === modelValue"
							class="absolute inset-0 grid place-items-center text-[10px] font-semibold text-black/80 mix-blend-difference">
							{{ swatch.id }}
						</span>
					</button>
				</div>
			</div>
		</div>
	</div>
</template>

<script setup lang="ts">
import { Palette } from "@lucide/vue";

const props = defineProps<{
	modelValue: number;
}>();

const emit = defineEmits<{
	"update:modelValue": [value: number];
}>();

const open = ref(false);

const current = computed(() => ({
	id: props.modelValue,
	hex: blipColourHex(props.modelValue),
}));

const pick = (id: number) => {
	emit("update:modelValue", id);
	open.value = false;
};
</script>
