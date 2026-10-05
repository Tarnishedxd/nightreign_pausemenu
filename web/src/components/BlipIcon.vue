<template>
	<span class="inline-grid shrink-0 place-items-center" :style="{ width: `${face}px`, height: `${face}px` }">
		<img v-if="src" :src="src" alt="" class="hidden" @load="failed = false" @error="failed = true" />
		<span
			v-if="src && !failed"
			class="blip-face"
			:style="{ width: `${face}px`, height: `${face}px`, filter: plain ? undefined : stroke }">
			<span class="blip-mask block h-full w-full" :style="[maskStyle, { backgroundImage: fill }]" />
		</span>
		<span
			v-else
			class="rounded-full"
			:style="{ width: `${dot}px`, height: `${dot}px`, backgroundImage: fill, filter: plain ? undefined : stroke }" />
	</span>
</template>

<script setup lang="ts">
const props = withDefaults(
	defineProps<{
		sprite: string;
		colour: string;
		size?: number;
		/** Skip drop-shadow stroke (cheaper for dense map overlays). */
		plain?: boolean;
	}>(),
	{ size: 24, plain: false },
);

const face = computed(() => props.size);
const dot = computed(() => Math.max(6, Math.round(props.size * 0.5)));

const failed = ref(false);

const src = computed(() => {
	const name = props.sprite.replace(/\.png$/i, "").trim();
	if (!name) return "";
	return blipSrc(name);
});

const channelsOf = (hex: string): [number, number, number] => {
	const raw = hex.replace("#", "");
	const full = raw.length === 3 ? raw.replace(/./g, (char) => char + char) : raw;
	const value = Number.parseInt(full, 16);
	if (Number.isNaN(value)) return [255, 255, 255];
	return [(value >> 16) & 255, (value >> 8) & 255, value & 255];
};

const mix = (source: string, target: string, amount: number) => {
	const from = channelsOf(source);
	const to = channelsOf(target);
	const channels = from.map((channel, index) => Math.round(channel + ((to[index] ?? channel) - channel) * amount));
	return `rgb(${channels[0] ?? 0}, ${channels[1] ?? 0}, ${channels[2] ?? 0})`;
};

const darkInk = computed(() => {
	const [red, green, blue] = channelsOf(props.colour);
	return relativeLuminance(red, green, blue) < 0.28;
});

const fill = computed(() => {
	const dark = mix(props.colour, "#000000", 0.55);
	const light = mix(props.colour, "#ffffff", 0.45);
	return `linear-gradient(to bottom, ${dark} 0%, ${props.colour} 34%, ${props.colour} 52%, ${light} 100%)`;
});

const stroke = computed(() => {
	const ink = darkInk.value ? "#fff" : "#000";
	return `drop-shadow(0 1px 0 ${ink}) drop-shadow(0 -1px 0 ${ink}) drop-shadow(1px 0 0 ${ink}) drop-shadow(-1px 0 0 ${ink})`;
});

const maskStyle = computed(() => ({
	WebkitMaskImage: `url(${src.value})`,
	maskImage: `url(${src.value})`,
}));

watch(
	() => props.sprite,
	() => {
		failed.value = false;
	},
);
</script>

<style scoped>
.blip-face {
	display: block;
	overflow: visible;
}

.blip-mask {
	-webkit-mask-size: contain;
	mask-size: contain;
	-webkit-mask-repeat: no-repeat;
	mask-repeat: no-repeat;
	-webkit-mask-position: center;
	mask-position: center;
}
</style>
