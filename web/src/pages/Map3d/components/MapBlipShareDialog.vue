<template>
	<Teleport to="body">
		<Transition
			enter-active-class="transition duration-200 ease-out"
			enter-from-class="opacity-0"
			enter-to-class="opacity-100"
			leave-active-class="transition duration-200 ease-in"
			leave-from-class="opacity-100"
			leave-to-class="opacity-0">
			<div v-if="open" class="fixed inset-0 z-40 grid place-items-center bg-black/40 px-6" :style="panelStyle">
				<section
					class="w-full max-w-sm overflow-hidden rounded-sm bg-black/80 ring-1 ring-white/15 backdrop-blur-xl"
					role="dialog"
					aria-modal="true">
					<div class="map-bar-on flex h-11 items-center gap-2 px-4">
						<Share2 :size="iS(18)" class="text-black" />
						<p class="text-base font-semibold text-black">{{ _t("ui.map3d.shareTitle", "Share the blip") }}</p>
					</div>
					<div class="px-4 py-4">
						<label class="flex items-center gap-1.5 text-sm text-white/55">
							<Hash :size="iS(14)" />
							{{ _t("ui.map3d.playerId", "Server ID") }}
						</label>
						<input
							v-model="targetId"
							type="text"
							inputmode="numeric"
							:placeholder="_t('ui.map3d.playerPlaceholder', 'Server ID (e.g. 1)')"
							class="map-bar mt-1.5 h-10 w-full rounded-sm px-3 text-sm text-white outline-none ring-1 ring-inset ring-white/15 placeholder:text-white/35 focus:ring-white/30" />
						<div class="mt-4 flex flex-nowrap items-center justify-end gap-2 border-t border-white/10 pt-3">
							<button type="button" :class="secondaryBtn" @click="emit('close')">
								{{ _t("ui.map3d.cancel", "Cancel") }}
							</button>
							<button type="button" :class="[primaryBtn, 'inline-flex items-center gap-1.5']" @click="emit('send')">
								<Share2 :size="iS(16)" />
								{{ _t("ui.map3d.share", "Share") }}
							</button>
						</div>
					</div>
				</section>
			</div>
		</Transition>
	</Teleport>
</template>

<script setup lang="ts">
import { Hash, Share2 } from "@lucide/vue";
import type { CSSProperties } from "vue";

defineProps<{
	open: boolean;
	panelStyle: CSSProperties;
	primaryBtn: string;
	secondaryBtn: string;
}>();

const emit = defineEmits<{
	close: [];
	send: [];
}>();

const targetId = defineModel<string>("targetId", { required: true });
</script>
