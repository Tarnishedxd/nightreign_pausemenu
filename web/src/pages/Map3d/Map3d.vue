<template>
	<div
		class="relative flex h-full w-full select-none flex-col overflow-hidden p-6 text-white transition-opacity duration-[250ms] ease-out"
		:class="uiReady ? 'opacity-100' : 'opacity-0'"
		:style="panelStyle">
		<!-- Interaction layer -->
		<div
			class="absolute inset-0 z-0"
			:class="cursorClass"
			@pointerdown="onPointerDown"
			@pointermove="onPointerMove"
			@pointerup="onPointerUp"
			@pointercancel="onPointerUp"
			@wheel.prevent="onWheel"
			@contextmenu.prevent />

		<!-- Vignette -->
		<div class="vignette z-[0] pointer-events-none"></div>

		<div class="z-[3] pointer-events-none [&>*]:pointer-events-auto">
			<!-- Server Logo -->
			<BrandLogo class="h-16 absolute top-5 left-5 pointer-events-none" />

			<Transition
				enter-active-class="transition duration-200 ease-out"
				enter-from-class="opacity-0"
				enter-to-class="opacity-100"
				leave-active-class="transition duration-150 ease-in"
				leave-from-class="opacity-100"
				leave-to-class="opacity-0">
				<p
					v-if="sheet.placing"
					class="pointer-events-none absolute bottom-[10rem] left-1/2 -translate-x-1/2 text-sm font-medium text-white/85">
					{{ _t("ui.map3d.place", "Click the map to place a blip.") }}
				</p>
			</Transition>
			<div class="pointer-events-none fixed bottom-[12rem] left-1/2 z-[6] -translate-x-1/2">
				<Transition
					enter-active-class="transition duration-200 ease-out"
					enter-from-class="translate-y-3 opacity-0"
					enter-to-class="translate-y-0 opacity-100"
					leave-active-class="transition duration-200 ease-in"
					leave-from-class="translate-y-0 opacity-100"
					leave-to-class="translate-y-3 opacity-0">
					<div v-if="notice" class="map-bar flex max-w-md items-center gap-3 rounded-sm px-4 py-3 text-sm text-white">
						<CircleCheck v-if="noticeKind === 'success'" :size="iS(18)" class="shrink-0 text-emerald-300" />
						<CircleAlert v-else :size="iS(18)" class="shrink-0 text-red-300" />
						<span class="min-w-0">{{ notice }}</span>
					</div>
				</Transition>
			</div>

			<!-- Search Input -->
			<MapSearchInput />

			<!-- Map info + controls: one column that wraps instead of running under the blip panel -->
			<div class="!pointer-events-none absolute bottom-6 left-6 flex max-w-[calc(100%-28rem)] flex-col items-start gap-4">
				<MapInfo />
				<MapControls />
			</div>
		</div>

		<MapMarkers />
		<MapBlipPanel />
	</div>
</template>

<script setup lang="ts">
import { CircleAlert, CircleCheck } from "@lucide/vue";

type DragMode = "none" | "pan" | "rotate";

const { panelStyle } = usePreferences();
const markers = useMarkersStore();
const { sheet, notice, noticeKind } = storeToRefs(markers);
const FADE_MS = 250;

const uiReady = ref(false);
const closing = ref(false);
const dragMode = ref<DragMode>("none");
let pendingDx = 0;
let pendingDy = 0;
let rafId = 0;
let pointerStartX = 0;
let pointerStartY = 0;
let pointerButton = -1;
let rotateGrabNx = 0.5;
let rotateGrabNy = 0.5;
let lastTapAt = 0;
let lastTapX = 0;
let lastTapY = 0;
const DOUBLE_TAP_MS = 350;
const DOUBLE_TAP_PX = 12;

const cursorClass = computed(() => {
	if (sheet.value.placing) return "cursor-crosshair";
	if (dragMode.value === "pan" || dragMode.value === "rotate") return "cursor-grabbing";
	return "cursor-grab";
});

const flushPointer = () => {
	rafId = 0;
	const dx = pendingDx;
	const dy = pendingDy;
	pendingDx = 0;
	pendingDy = 0;
	if (dx === 0 && dy === 0) return;
	if (dragMode.value === "pan") {
		fetchNui("MapPan", { dx, dy }, "ok");
	} else if (dragMode.value === "rotate") {
		fetchNui("MapRotate", { dx, dy, nx: rotateGrabNx, ny: rotateGrabNy }, "ok");
	}
};

const scheduleFlush = () => {
	if (rafId) return;
	rafId = requestAnimationFrame(flushPointer);
};

const onPointerDown = (e: PointerEvent) => {
	if (closing.value) return;
	pointerStartX = e.clientX;
	pointerStartY = e.clientY;
	pointerButton = e.button;
	if (sheet.value.placing && e.button === 0) {
		fetchNui(
			"ThreeDMapPlace",
			{
				nx: e.clientX / window.innerWidth,
				ny: e.clientY / window.innerHeight,
			},
			"ok",
		);
		return;
	}
	if (e.button === 0) {
		dragMode.value = "pan";
		(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
	} else if (e.button === 2) {
		rotateGrabNx = e.clientX / window.innerWidth;
		rotateGrabNy = e.clientY / window.innerHeight;
		dragMode.value = "rotate";
		(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
	}
};

const onPointerMove = (e: PointerEvent) => {
	if (dragMode.value === "none") return;
	pendingDx += e.movementX;
	pendingDy += e.movementY;
	scheduleFlush();
};

const onPointerUp = (e: PointerEvent) => {
	const moved = Math.hypot(e.clientX - pointerStartX, e.clientY - pointerStartY);
	const tap = pointerButton === 0 && moved < 4 && !sheet.value.placing;
	if (rafId) {
		cancelAnimationFrame(rafId);
		flushPointer();
	}
	dragMode.value = "none";
	if (!tap) {
		lastTapAt = 0;
		return;
	}

	const now = performance.now();
	const near =
		Math.hypot(e.clientX - lastTapX, e.clientY - lastTapY) <= DOUBLE_TAP_PX && now - lastTapAt <= DOUBLE_TAP_MS;
	if (near) {
		lastTapAt = 0;
		fetchNui(
			"ThreeDMapWaypointAt",
			{
				nx: e.clientX / window.innerWidth,
				ny: e.clientY / window.innerHeight,
			},
			"ok",
		);
		return;
	}

	lastTapAt = now;
	lastTapX = e.clientX;
	lastTapY = e.clientY;
	markers.select(null);
};

const onWheel = (e: WheelEvent) => {
	if (closing.value) return;
	const delta = Math.sign(e.deltaY);
	if (delta === 0) return;
	fetchNui(
		"MapZoom",
		{
			delta,
			nx: e.clientX / window.innerWidth,
			ny: e.clientY / window.innerHeight,
		},
		"ok",
	);
};

const closeMap = () => {
	if (closing.value) return;
	closing.value = true;
	uiReady.value = false;
	setTimeout(() => {
		fetchNui("CloseMap", {}, "ok");
	}, FADE_MS);
};

const isField = (target: EventTarget | null) => target instanceof HTMLInputElement || target instanceof HTMLTextAreaElement;

const onKeyDown = (e: KeyboardEvent) => {
	if (closing.value || isField(e.target)) return;
	if (e.key === "Escape") {
		if (sheet.value.placing || sheet.value.draft) {
			fetchNui("ThreeDMapCancel", {}, "ok");
			return;
		}
		closeMap();
		return;
	}
	if (e.code === "Space" || e.key === " ") {
		e.preventDefault();
		fetchNui("MapFocusPlayer", {}, "ok");
	}
};

const setTyping = (typing: boolean) => {
	void fetchNui("MapTyping", { typing }, "ok").catch(() => {});
};

const onFocusIn = (e: FocusEvent) => {
	if (!isField(e.target)) return;
	setTyping(true);
};

const onFocusOut = (e: FocusEvent) => {
	if (!isField(e.target) || isField(e.relatedTarget)) return;
	setTyping(false);
};

onMounted(() => {
	window.addEventListener("keydown", onKeyDown);
	window.addEventListener("focusin", onFocusIn);
	window.addEventListener("focusout", onFocusOut);
	requestAnimationFrame(() => {
		uiReady.value = true;
	});
});

onUnmounted(() => {
	window.removeEventListener("keydown", onKeyDown);
	window.removeEventListener("focusin", onFocusIn);
	window.removeEventListener("focusout", onFocusOut);
	setTyping(false);
	if (rafId) cancelAnimationFrame(rafId);
});
</script>

<style scoped>
.vignette {
	position: fixed;
	top: 0;
	left: 0;
	width: 100%;
	height: 100%;
	box-shadow: 0 0 150px rgba(15, 15, 15, 1) inset;
}
</style>
