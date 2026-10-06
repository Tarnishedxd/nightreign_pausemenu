<template>
	<div class="flex flex-col w-full h-full min-h-0 overflow-hidden bg-transparent" v-if="visible">
		<div class="relative z-[1] flex flex-col w-full h-full min-h-0">
			<PauseHome v-if="currentPage === 'pause'" />
			<Map3d v-else-if="currentPage === 'map'" />
			<GtaMap v-else-if="currentPage === 'gtaMap'" />
			<SettingsPage v-else-if="currentPage === 'settings'" />
			<Stats v-else-if="currentPage === 'stats'" />
		</div>
		<GtaAlertModal />
		<Transition
			enter-active-class="veil-fade"
			enter-from-class="opacity-0"
			enter-to-class="opacity-100"
			leave-active-class="veil-fade"
			leave-from-class="opacity-100"
			leave-to-class="opacity-0">
			<div v-if="settings.veil" class="fixed inset-0 z-[80] grid place-items-center bg-black">
				<div class="flex items-center gap-3">
					<span class="h-5 w-5 animate-spin rounded-full border-2 border-white/20 border-t-white" />
				</div>
			</div>
		</Transition>
		<div v-if="settings.keyPrompt" class="fixed inset-0 z-[90] grid place-items-center bg-black">
			<div class="flex flex-col items-center gap-6">
				<div class="flex items-center gap-4">
					<span
						v-if="settings.listenPhase !== 'press'"
						class="h-8 w-8 animate-spin rounded-full border-2 border-white/20 border-t-white" />
					<p
						class="text-5xl font-medium tracking-wide text-white"
						:class="settings.listenPhase === 'press' ? 'key-prompt-blink' : ''">
						{{
							settings.listenPhase === "press"
								? _t("ui.settings.keys.press", "Press a key")
								: _t("ui.settings.keys.wait", "Wait")
						}}
					</p>
				</div>
			</div>
		</div>
	</div>
	<!-- Draw the pause screen once, invisibly, as soon as the translations arrive: the first ESC
	     then opens as fast as every later one (no cold component, font or image work). -->
	<div v-if="prewarm && !visible" class="pointer-events-none fixed inset-0 invisible" aria-hidden="true">
		<PauseHome prewarm />
	</div>
</template>

<script setup lang="ts">
import PauseHome from "@/pages/Pause/PauseHome.vue";
import GtaMap from "@/pages/GtaMap/GtaMap.vue";
import SettingsPage from "@/pages/Settings/Settings.vue";
import GtaAlertModal from "@/components/GtaAlertModal.vue";
import { announceReady } from "@/services/api";

const store = useMainStore();
const { visible, currentPage } = storeToRefs(store);
const settingsStore = useSettingsStore();
const { settings } = storeToRefs(settingsStore);

useScaler(100);
onMounted(() => {
	announceReady();
});

const localeStore = useLocaleStore();
const prewarm = ref(false);
let prewarmed = false;
watch(
	() => localeStore.translations,
	(translations) => {
		if (prewarmed || visible.value || !translations || !Object.keys(translations).length) return;
		prewarmed = true;
		prewarm.value = true;
		// a few frames are enough for layout, fonts and the logo; then drop it again
		window.setTimeout(() => {
			prewarm.value = false;
		}, 250);
	},
);
</script>
