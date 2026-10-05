<template>
	<img v-if="showBranding" :src="src" alt="" :class="props.class" @error="onError" />
</template>

<script setup lang="ts">
const props = defineProps<{
	class?: string;
}>();

const store = useMainStore();
const { player } = storeToRefs(store);
const showBranding = computed(() => player.value.showBranding !== false);

const src = ref(assetURL("branding/logo.svg"));

const onError = () => {
	const png = assetURL("branding/logo.png");
	if (src.value !== png) src.value = png;
};
</script>
