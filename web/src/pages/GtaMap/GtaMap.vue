<template>
	<div class="gta-map relative h-full w-full select-none overflow-hidden text-white" :style="panelStyle">
		<aside
			v-if="showPanel"
			class="pointer-events-auto absolute right-6 top-20 z-[2] flex w-fit max-w-[22rem] flex-col items-end gap-0.5"
			@pointerenter="setOver(true)"
			@pointerleave="setOver(false)">
			<div class="map-skew relative h-10 w-[15.625rem] shrink-0 rounded-sm bg-white">
				<input
					v-model="query"
					type="text"
					:placeholder="_t('ui.map.search', 'Search for a location')"
					class="h-full w-full bg-transparent py-0 pl-4 pr-9 text-sm text-black outline-none placeholder:text-black/50"
					@focus="setTyping(true)"
					@blur="setTyping(false)" />
				<Search :size="iS(16)" class="pointer-events-none absolute right-2.5 top-1/2 -translate-y-1/2 text-black/50" />
			</div>

			<div v-if="legend.status === 'loading'" class="flex max-h-[calc(100vh-16rem)] flex-col items-end gap-0.5">
				<div
					v-for="(width, index) in [10, 7]"
					:key="index"
					class="map-skew map-bar flex h-11 shrink-0 items-center px-3"
					:style="{ width: `${width}rem` }">
					<div class="h-3.5 w-2/3 animate-pulse rounded-sm bg-white/25" />
				</div>
			</div>

			<div
				v-else
				class="flex max-h-[calc(100vh-16rem)] flex-col items-end gap-0.5 overflow-y-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
				<p v-if="!hasRows" class="px-4 py-3 text-sm text-white/55">
					{{ _t("ui.map.empty", "Nothing matches") }}
				</p>

				<div
					v-for="row in filteredRows"
					:key="row.id"
					:ref="(el) => setRowEl(row.id, el as Element | null)"
					class="map-skew group flex h-11 w-fit max-w-full shrink-0 cursor-pointer items-center gap-2 pl-4 pr-2.5 text-sm active:scale-[0.98]"
					:class="isActive(row) ? 'map-bar-on' : 'map-bar'">
					<button
						type="button"
						class="flex h-full w-fit max-w-[16rem] cursor-pointer items-center gap-2 text-left"
						@click="selectRow(row.id)">
						<span class="truncate">{{ rowLabel(row) }}</span>
						<BlipIcon :sprite="row.sprite" :colour="row.colour" :size="iS(22)" />
					</button>
					<div v-if="isActive(row) && row.count > 1 && !row.fixed" class="flex shrink-0 items-center gap-0.5 tabular-nums">
						<button
							type="button"
							class="grid h-6 w-6 place-items-center opacity-70 transition-opacity duration-150 hover:opacity-100"
							@click="stepRow(row.id, -1)">
							<ChevronLeft :size="iS(16)" />
						</button>
						<span class="min-w-7 text-center text-xs">{{ row.cycle }}/{{ row.count }}</span>
						<button
							type="button"
							class="grid h-6 w-6 place-items-center opacity-70 transition-opacity duration-150 hover:opacity-100"
							@click="stepRow(row.id, 1)">
							<ChevronRight :size="iS(16)" />
						</button>
					</div>
				</div>
			</div>
		</aside>

		<div
			class="pointer-events-auto absolute bottom-6 right-6 z-[2] flex w-max items-center gap-3 whitespace-nowrap text-sm text-white/70"
			@pointerenter="setOver(true)"
			@pointerleave="setOver(false)">
			<span class="flex shrink-0 items-center gap-1.5">
				<span class="flex items-center gap-1">
					<span class="map-key-icon">
						<ArrowUpDown :size="iS(14)" />
					</span>
					<span class="map-key-icon">
						<ArrowLeftRight :size="iS(14)" />
					</span>
				</span>
				<span>{{ _t("ui.map.selectBlip", "Select Blip") }}</span>
			</span>
			<button type="button" class="flex shrink-0 items-center gap-1.5" @click="placeWaypoint">
				<span class="map-key">ENTER</span>
				<span>{{ _t("ui.map3d.waypoint", "Waypoint") }}</span>
			</button>
			<button type="button" class="flex shrink-0 items-center gap-1.5" @click="closeMap">
				<span class="map-key">ESC</span>
				<span>{{ _t("ui.settings.close", "Close") }}</span>
			</button>
		</div>

		<div class="pointer-events-none fixed bottom-8 left-1/2 z-[6] -translate-x-1/2">
			<Transition
				enter-active-class="transition duration-200 ease-out"
				enter-from-class="translate-y-3 opacity-0"
				enter-to-class="translate-y-0 opacity-100"
				leave-active-class="transition duration-200 ease-in"
				leave-from-class="translate-y-0 opacity-100"
				leave-to-class="translate-y-3 opacity-0">
				<div v-if="toastText" class="map-bar flex max-w-md items-center gap-3 rounded-sm px-4 py-3 text-sm text-white">
					<CircleCheck v-if="toastOk" :size="iS(18)" class="shrink-0 text-emerald-300" />
					<CircleAlert v-else :size="iS(18)" class="shrink-0 text-red-300" />
					<span class="min-w-0">{{ toastText }}</span>
				</div>
			</Transition>
		</div>
	</div>
</template>

<script setup lang="ts">
import { ArrowLeftRight, ArrowUpDown, ChevronLeft, ChevronRight, CircleAlert, CircleCheck, Search } from "@lucide/vue";
import type { LegendRow } from "@/types";

const { panelStyle } = usePreferences();
const { legend } = storeToRefs(useLegendStore());
const query = ref("");

const showPanel = computed(() => legend.value.status === "loading" || legend.value.status === "ready");

// GTA names the fixed rows itself, in the game's language: use ours.
const rowLabel = (row: LegendRow) => {
	if (row.kind === "waypoint") return _t("ui.map3d.waypointName", "Waypoint");
	if (row.kind === "player") return _t("ui.map3d.you", "You");
	return row.label;
};

const filteredRows = computed(() => {
	const needle = query.value.trim().toLocaleLowerCase();
	if (!needle) return legend.value.rows;
	return legend.value.rows.filter((row) => `${rowLabel(row)} ${row.label}`.toLocaleLowerCase().includes(needle));
});

const hasRows = computed(() => filteredRows.value.length > 0);

const selectedId = ref<string | null>(null);
const rowEls = new Map<string, HTMLElement>();

const isActive = (row: LegendRow) => {
	if (legend.value.focus >= 0) return row.index === legend.value.focus;
	return selectedId.value === row.id;
};

const setOver = (over: boolean) => {
	fetchNui("GtaMapPointer", { over }, "ok");
};

const setTyping = (typing: boolean) => {
	fetchNui("GtaMapTyping", { typing }, "ok");
};

const setRowEl = (id: string, el: Element | null) => {
	if (el instanceof HTMLElement) rowEls.set(id, el);
	else rowEls.delete(id);
};

watch(
	() => legend.value.focus,
	async (focus) => {
		if (focus < 0) return;
		const row = legend.value.rows.find((item) => item.index === focus);
		if (!row) return;
		selectedId.value = row.id;
		await nextTick();
		rowEls.get(row.id)?.scrollIntoView({ block: "nearest" });
	},
);

const selectRow = (id: string) => {
	const place = selectedId.value === id;
	selectedId.value = id;
	fetchNui("GtaMapSelect", { id, place }, "ok");
};

const focusRow = async (id: string) => {
	selectedId.value = id;
	fetchNui("GtaMapSelect", { id, place: false }, "ok");
	await nextTick();
	rowEls.get(id)?.scrollIntoView({ block: "nearest" });
};

const stepRow = (id: string, dir: number) => {
	fetchNui("GtaMapStep", { id, dir }, "ok");
};

const activeId = () => {
	const focus = legend.value.focus;
	if (focus >= 0) {
		return legend.value.rows.find((row) => row.index === focus)?.id ?? null;
	}
	return selectedId.value;
};

const placeWaypoint = () => {
	const id = activeId();
	if (!id) return;
	selectedId.value = id;
	fetchNui("GtaMapSelect", { id, place: true }, "ok");
};

const closeMap = () => {
	fetchNui("GtaMapClose", {}, "ok");
};

// Waypoint feedback pushed by the client (legend.toast); each push bumps the token.
const toastText = ref("");
const toastOk = ref(true);
let toastTimer = 0;

watch(
	() => legend.value.toast.token,
	(token) => {
		const toast = legend.value.toast;
		if (!token || !toast.kind) return;
		window.clearTimeout(toastTimer);
		if (toast.kind === "set") {
			toastText.value =
				toast.count > 1
					? _t("ui.map.waypointSetCount", "Waypoint set · %s %d/%d", toast.label, toast.cycle, toast.count)
					: _t("ui.map.waypointSet", "Waypoint set · %s", toast.label);
			toastOk.value = true;
		} else if (toast.kind === "removed") {
			toastText.value = _t("ui.map.waypointRemoved", "Waypoint removed");
			toastOk.value = true;
		} else {
			toastText.value = _t("ui.map.noBlip", "No blip to route to");
			toastOk.value = false;
		}
		toastTimer = window.setTimeout(() => {
			toastText.value = "";
		}, 2400);
	},
);

const onKeyDown = (event: KeyboardEvent) => {
	if (event.key === "Escape") {
		closeMap();
		return;
	}

	const typing = event.target instanceof HTMLInputElement;

	if (event.key === "Enter" && !typing) {
		event.preventDefault();
		placeWaypoint();
		return;
	}
	if (event.key === "Backspace" && !typing) {
		closeMap();
		return;
	}
	if (typing) return;

	const rows = filteredRows.value;
	if (rows.length === 0) return;
	const idx = rows.findIndex((row) => row.id === selectedId.value);

	if (event.key === "ArrowUp" || event.key === "ArrowDown") {
		event.preventDefault();
		const next =
			event.key === "ArrowDown"
				? idx < 0
					? 0
					: (idx + 1) % rows.length
				: idx < 0
					? rows.length - 1
					: (idx - 1 + rows.length) % rows.length;
		const row = rows[next];
		if (row) void focusRow(row.id);
		return;
	}

	if (event.key === "ArrowLeft" || event.key === "ArrowRight") {
		event.preventDefault();
		const id = selectedId.value ?? rows[0]?.id;
		if (!id) return;
		if (selectedId.value !== id) void focusRow(id);
		const row = rows.find((item) => item.id === id);
		if (row && row.count > 1 && !row.fixed) stepRow(id, event.key === "ArrowRight" ? 1 : -1);
	}
};

onMounted(() => {
	window.addEventListener("keydown", onKeyDown);
});

onUnmounted(() => {
	window.clearTimeout(toastTimer);
	window.removeEventListener("keydown", onKeyDown);
	setOver(false);
	setTyping(false);
});
</script>
