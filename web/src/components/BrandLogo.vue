<template>
	<img v-if="showBranding && !failed" :src="src" alt="" :class="props.class" @error="failed = true" />
</template>

<script setup lang="ts">
const props = defineProps<{ class?: string; }>();
const store = useMainStore();
const { player } = storeToRefs(store);
const showBranding = computed(() => player.value.showBranding !== false);
const src = assetURL("branding/logo.webp");
// A missing logo file must not leave a broken-image icon on screen.
const failed = ref(false);
</script>
