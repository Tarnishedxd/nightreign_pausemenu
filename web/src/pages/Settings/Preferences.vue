<template>
	<div
		class="flex min-h-0 flex-1 flex-col gap-2 overflow-y-auto pr-3 [scrollbar-color:rgb(255_255_255/0.22)_transparent] [scrollbar-width:thin] [&::-webkit-scrollbar-thumb]:rounded-full [&::-webkit-scrollbar-thumb]:bg-white/20 [&::-webkit-scrollbar]:w-1.5">
		<article
			data-focus="color"
			class="relative rounded-md border border-[color:var(--panel-row-border)] bg-[var(--panel-row-bg)] px-4 py-3 shadow-[var(--panel-row-shadow)]"
			:class="[focusId === 'color' ? '!bg-[var(--panel-row-bg-focus)]' : '', pickerOpen ? 'z-40' : '']">
			<div class="flex items-center justify-between gap-8">
				<div class="min-w-0">
					<p class="text-base text-white/90">{{ _t("ui.settings.preferences.accent.title", "Accent Color") }}</p>
					<p class="mt-1 text-sm leading-5 text-white/50">
						{{ _t("ui.settings.preferences.accent.hint", "Tints the active category, sliders, and Apply.") }}
					</p>
				</div>
				<div ref="pickerRoot" class="relative flex shrink-0 items-center gap-2">
					<button
						v-for="swatch in swatches"
						:key="swatch"
						type="button"
						class="h-8 w-8 rounded-md border border-white/15 transition-transform duration-200"
						:class="primary === swatch ? 'scale-110' : ''"
						:style="{ background: swatch }"
						@click="primary = swatch" />
					<span class="mx-1 h-5 w-px bg-white/20" aria-hidden="true" />
					<button
						type="button"
						class="grid h-8 w-8 place-items-center rounded-md border border-white/15 bg-white/10 text-white/80 transition-colors duration-200 hover:bg-white/15 hover:text-white"
						:aria-expanded="pickerOpen"
						@click="pickerOpen = !pickerOpen">
						<Paintbrush :size="iS(16)" />
					</button>
					<div
						v-if="pickerOpen"
						class="absolute right-0 top-full z-50 mt-2 w-64 rounded-md border border-white/10 bg-white/15 p-3 shadow-[inset_0_0_6px_rgb(255_255_255/0.04)]">
						<div
							class="relative h-32 w-full cursor-crosshair overflow-hidden rounded-md"
							:style="{ backgroundColor: `hsl(${hue} 100% 50%)` }"
							@pointerdown="dragSv">
							<div class="pointer-events-none absolute inset-0 bg-gradient-to-r from-white to-transparent" />
							<div class="pointer-events-none absolute inset-0 bg-gradient-to-t from-black to-transparent" />
							<span
								class="pointer-events-none absolute h-3.5 w-3.5 -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-white shadow"
								:style="{ left: `${sat * 100}%`, top: `${(1 - val) * 100}%` }" />
						</div>
						<div
							class="relative mt-2 h-3 w-full cursor-pointer rounded-md"
							style="
								background: linear-gradient(to right, #ff0000, #ffff00, #00ff00, #00ffff, #0000ff, #ff00ff, #ff0000);
							"
							@pointerdown="dragHue">
							<span
								class="pointer-events-none absolute top-1/2 h-4 w-4 -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-white bg-white/30 shadow"
								:style="{ left: `${(hue / 360) * 100}%` }" />
						</div>
						<input
							v-model="hexDraft"
							type="text"
							spellcheck="false"
							class="mt-3 w-full rounded-md border border-white/10 bg-black/20 px-3 py-2 text-sm text-white"
							@change="onHex" />
					</div>
				</div>
			</div>
		</article>
		<article
			data-focus="labels"
			class="flex min-h-14 items-center justify-between gap-6 rounded-md border border-[color:var(--panel-row-border)] bg-[var(--panel-row-bg)] px-4 py-3 shadow-[var(--panel-row-shadow)]"
			:class="focusId === 'labels' ? '!bg-[var(--panel-row-bg-focus)]' : ''">
			<div class="min-w-0">
				<p class="text-base text-white/90">
					{{
						_t("ui.settings.preferences.experimental.title", "Experimental %s Translation", _t("ui.localeName", "English"))
					}}
				</p>
				<p class="mt-1 text-sm leading-5 text-white/50">
					{{ _t("ui.settings.preferences.experimental.hint", "Replaces known setting names with locale labels.") }}
				</p>
			</div>
			<div class="flex shrink-0 items-center gap-1">
				<button
					type="button"
					class="grid h-8 w-8 place-items-center rounded-md border border-white/10 bg-white/10 text-white/80 shadow-[inset_0_0_6px_rgb(255_255_255/0.04)] transition duration-150 hover:bg-white/20 hover:text-white active:scale-[0.98]"
					@click="experimentalLabels = false">
					<ChevronLeft :size="iS(16)" />
				</button>
				<button
					type="button"
					class="min-w-16 px-2 text-center text-base text-white/85 transition duration-150 active:scale-[0.98]"
					@click="experimentalLabels = !experimentalLabels">
					{{ experimentalLabels ? _t("ui.settings.on", "On") : _t("ui.settings.off", "Off") }}
				</button>
				<button
					type="button"
					class="grid h-8 w-8 place-items-center rounded-md border border-white/10 bg-white/10 text-white/80 shadow-[inset_0_0_6px_rgb(255_255_255/0.04)] transition duration-150 hover:bg-white/20 hover:text-white active:scale-[0.98]"
					@click="experimentalLabels = true">
					<ChevronRight :size="iS(16)" />
				</button>
			</div>
		</article>
		<article
			data-focus="darkMode"
			class="flex min-h-14 items-center justify-between gap-6 rounded-md border border-[color:var(--panel-row-border)] bg-[var(--panel-row-bg)] px-4 py-3 shadow-[var(--panel-row-shadow)]"
			:class="focusId === 'darkMode' ? '!bg-[var(--panel-row-bg-focus)]' : ''">
			<div class="min-w-0">
				<p class="text-base text-white/90">{{ _t("ui.settings.preferences.darkMode.title", "Dark Mode") }}</p>
				<p class="mt-1 text-sm leading-5 text-white/50">
					{{ _t("ui.settings.preferences.darkMode.hint", "Uses darker backgrounds on settings rows.") }}
				</p>
			</div>
			<div class="flex shrink-0 items-center gap-1">
				<button
					type="button"
					class="grid h-8 w-8 place-items-center rounded-md border border-white/10 bg-white/10 text-white/80 shadow-[inset_0_0_6px_rgb(255_255_255/0.04)] transition duration-150 hover:bg-white/20 hover:text-white active:scale-[0.98]"
					@click="darkMode = false">
					<ChevronLeft :size="iS(16)" />
				</button>
				<button type="button" class="min-w-16 px-2 text-center text-base text-white/85 transition duration-150 active:scale-[0.98]" @click="darkMode = !darkMode">
					{{ darkMode ? _t("ui.settings.on", "On") : _t("ui.settings.off", "Off") }}
				</button>
				<button
					type="button"
					class="grid h-8 w-8 place-items-center rounded-md border border-white/10 bg-white/10 text-white/80 shadow-[inset_0_0_6px_rgb(255_255_255/0.04)] transition duration-150 hover:bg-white/20 hover:text-white active:scale-[0.98]"
					@click="darkMode = true">
					<ChevronRight :size="iS(16)" />
				</button>
			</div>
		</article>
		<article
			data-focus="portrait"
			class="flex min-h-14 items-center justify-between gap-6 rounded-md border border-[color:var(--panel-row-border)] bg-[var(--panel-row-bg)] px-4 py-3 shadow-[var(--panel-row-shadow)]"
			:class="focusId === 'portrait' ? '!bg-[var(--panel-row-bg-focus)]' : ''">
			<div class="min-w-0">
				<p class="text-base text-white/90">{{ _t("ui.settings.preferences.portrait.title", "Portrait Mode") }}</p>
				<p class="mt-1 text-sm leading-5 text-white/50">
					{{ _t("ui.settings.preferences.portrait.hint", "Character camera while the pause menu is open.") }}
				</p>
			</div>
			<div class="flex shrink-0 items-center gap-1">
				<button
					type="button"
					class="grid h-8 w-8 place-items-center rounded-md border border-white/10 bg-white/10 text-white/80 shadow-[inset_0_0_6px_rgb(255_255_255/0.04)] transition duration-150 hover:bg-white/20 hover:text-white active:scale-[0.98]"
					@click="setPortraitMode(false)">
					<ChevronLeft :size="iS(16)" />
				</button>
				<button
					type="button"
					class="min-w-16 px-2 text-center text-base text-white/85 transition duration-150 active:scale-[0.98]"
					@click="setPortraitMode(!portraitMode)">
					{{ portraitMode ? _t("ui.settings.on", "On") : _t("ui.settings.off", "Off") }}
				</button>
				<button
					type="button"
					class="grid h-8 w-8 place-items-center rounded-md border border-white/10 bg-white/10 text-white/80 shadow-[inset_0_0_6px_rgb(255_255_255/0.04)] transition duration-150 hover:bg-white/20 hover:text-white active:scale-[0.98]"
					@click="setPortraitMode(true)">
					<ChevronRight :size="iS(16)" />
				</button>
			</div>
		</article>
		<article
			data-focus="return3dAnim"
			class="flex min-h-14 items-center justify-between gap-6 rounded-md border border-[color:var(--panel-row-border)] bg-[var(--panel-row-bg)] px-4 py-3 shadow-[var(--panel-row-shadow)]"
			:class="focusId === 'return3dAnim' ? '!bg-[var(--panel-row-bg-focus)]' : ''">
			<div class="min-w-0">
				<p class="text-base text-white/90">{{ _t("ui.settings.preferences.return3dAnim.title", "Return Animation") }}</p>
				<p class="mt-1 text-sm leading-5 text-white/50">
					{{
						_t(
							"ui.settings.preferences.return3dAnim.hint",
							"Fly back to the player when closing the 3D map. Off uses a screen fade instead.",
						)
					}}
				</p>
			</div>
			<div class="flex shrink-0 items-center gap-1">
				<button
					type="button"
					class="grid h-8 w-8 place-items-center rounded-md border border-white/10 bg-white/10 text-white/80 shadow-[inset_0_0_6px_rgb(255_255_255/0.04)] transition duration-150 hover:bg-white/20 hover:text-white active:scale-[0.98]"
					@click="setReturn3dAnim(false)">
					<ChevronLeft :size="iS(16)" />
				</button>
				<button
					type="button"
					class="min-w-16 px-2 text-center text-base text-white/85 transition duration-150 active:scale-[0.98]"
					@click="setReturn3dAnim(!return3dAnim)">
					{{ return3dAnim ? _t("ui.settings.on", "On") : _t("ui.settings.off", "Off") }}
				</button>
				<button
					type="button"
					class="grid h-8 w-8 place-items-center rounded-md border border-white/10 bg-white/10 text-white/80 shadow-[inset_0_0_6px_rgb(255_255_255/0.04)] transition duration-150 hover:bg-white/20 hover:text-white active:scale-[0.98]"
					@click="setReturn3dAnim(true)">
					<ChevronRight :size="iS(16)" />
				</button>
			</div>
		</article>
		<article
			data-focus="reset"
			class="flex min-h-14 items-center justify-between gap-6 rounded-md border border-[color:var(--panel-row-border)] bg-[var(--panel-row-bg)] px-4 py-3 shadow-[var(--panel-row-shadow)]"
			:class="focusId === 'reset' ? '!bg-[var(--panel-row-bg-focus)]' : ''">
			<div class="min-w-0">
				<p class="text-base text-white/90">{{ _t("ui.settings.preferences.reset.title", "Reset Appearance") }}</p>
				<p class="mt-1 text-sm leading-5 text-white/50">
					{{ _t("ui.settings.preferences.reset.hint", "Restores all appearance preferences to their defaults.") }}
				</p>
			</div>
			<button
				type="button"
				class="shrink-0 rounded-md border border-white/10 bg-white/10 px-3 py-1.5 text-base text-white/80 shadow-[inset_0_0_6px_rgb(255_255_255/0.04)] transition-colors duration-200 hover:bg-white/15"
				@click="resetAppearance">
				{{ _t("ui.settings.preferences.reset.action", "Reset") }}
			</button>
		</article>
	</div>
</template>

<script setup lang="ts">
import { ChevronLeft, ChevronRight, Paintbrush } from "@lucide/vue";

const props = defineProps<{
	focusId: string;
}>();

const { primary, experimentalLabels, darkMode, resetPanelTheme } = usePreferences();

const swatches = ["#ffffff", "#0a84ff", "#30d158", "#ff9f0a", "#ff375f"];
const hue = ref(0);
const sat = ref(0);
const val = ref(1);
const pickerOpen = ref(false);
const pickerRoot = ref<HTMLElement | null>(null);
const hexDraft = ref("");
const portraitMode = ref(true);
const return3dAnim = ref(true);
let dragging = false;

const setPortraitMode = (enabled: boolean) => {
	if (portraitMode.value === enabled) return;
	portraitMode.value = enabled;
	void fetchNui<{ enabled: boolean }>("SetPortraitMode", { enabled }, { enabled }).then((result) => {
		portraitMode.value = result.enabled === true;
	});
};

const setReturn3dAnim = (enabled: boolean) => {
	if (return3dAnim.value === enabled) return;
	return3dAnim.value = enabled;
	void fetchNui<{ enabled: boolean }>("SetReturn3dAnim", { enabled }, { enabled }).then((result) => {
		return3dAnim.value = result.enabled === true;
	});
};

const resetAppearance = () => {
	resetPanelTheme();
	setPortraitMode(true);
	setReturn3dAnim(true);
};

const commit = () => {
	primary.value = hsvToHex(hue.value, sat.value, val.value);
};

const onHex = () => {
	const value = hexDraft.value.trim();
	if (/^#[0-9a-fA-F]{6}$/.test(value)) primary.value = value;
	else hexDraft.value = primary.value;
};

const onPointerDown = (event: PointerEvent) => {
	if (!pickerOpen.value) return;
	const root = pickerRoot.value;
	if (root && event.target instanceof Node && root.contains(event.target)) return;
	pickerOpen.value = false;
};

watch(
	primary,
	(value) => {
		hexDraft.value = value;
		if (dragging) return;
		const next = hexToHsv(value);
		hue.value = next.h;
		sat.value = next.s;
		val.value = next.v;
	},
	{ immediate: true },
);

onMounted(() => {
	window.addEventListener("pointerdown", onPointerDown);
	void fetchNui<{ enabled: boolean }>("GetPortraitMode", {}, { enabled: true }).then((result) => {
		portraitMode.value = result.enabled !== false;
	});
	void fetchNui<{ enabled: boolean }>("GetReturn3dAnim", {}, { enabled: true }).then((result) => {
		return3dAnim.value = result.enabled !== false;
	});
});
onUnmounted(() => window.removeEventListener("pointerdown", onPointerDown));

const ratio = (event: PointerEvent, element: HTMLElement) => {
	const rect = element.getBoundingClientRect();
	return {
		x: rect.width <= 0 ? 0 : Math.min(1, Math.max(0, (event.clientX - rect.left) / rect.width)),
		y: rect.height <= 0 ? 0 : Math.min(1, Math.max(0, (event.clientY - rect.top) / rect.height)),
	};
};

const track = (event: PointerEvent, move: (next: PointerEvent, element: HTMLElement) => void) => {
	const target = event.currentTarget as HTMLElement;
	target.setPointerCapture(event.pointerId);
	dragging = true;
	move(event, target);
	const onMove = (next: PointerEvent) => move(next, target);
	const stop = () => {
		dragging = false;
		commit();
		target.removeEventListener("pointermove", onMove);
		target.removeEventListener("pointerup", stop);
	};
	target.addEventListener("pointermove", onMove);
	target.addEventListener("pointerup", stop);
};

const dragSv = (event: PointerEvent) => {
	track(event, (next, element) => {
		const point = ratio(next, element);
		sat.value = point.x;
		val.value = 1 - point.y;
		commit();
	});
};

const dragHue = (event: PointerEvent) => {
	track(event, (next, element) => {
		hue.value = ratio(next, element).x * 360;
		commit();
	});
};

const nudge = (direction: number) => {
	if (props.focusId === "labels") experimentalLabels.value = direction > 0;
	if (props.focusId === "darkMode") darkMode.value = direction > 0;
	if (props.focusId === "portrait") setPortraitMode(direction > 0);
	if (props.focusId === "return3dAnim") setReturn3dAnim(direction > 0);
	if (props.focusId !== "color") return;
	const index = Math.max(0, swatches.indexOf(primary.value));
	primary.value = swatches[(index + direction + swatches.length) % swatches.length] ?? primary.value;
};

const activate = () => {
	if (props.focusId === "labels") experimentalLabels.value = !experimentalLabels.value;
	if (props.focusId === "darkMode") darkMode.value = !darkMode.value;
	if (props.focusId === "portrait") setPortraitMode(!portraitMode.value);
	if (props.focusId === "return3dAnim") setReturn3dAnim(!return3dAnim.value);
	if (props.focusId === "reset") resetAppearance();
};

defineExpose({ nudge, activate });
</script>
