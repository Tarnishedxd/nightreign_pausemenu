<template>
	<div class="pointer-events-none absolute inset-0 z-[1] contain-strict">
		<button
			v-for="point in visiblePoints"
			:key="point.id"
			:ref="(el) => setNode(point.id, el as Element | null)"
			type="button"
			class="marker pointer-events-auto absolute left-0 top-0 flex flex-col items-center"
			:class="selected === point.id ? 'is-on' : ''"
			:style="{ zIndex: markerZ(point.id) }"
			@click.stop="pick(point.id)"
			@dblclick.stop="setWaypoint(point.id)">
			<span class="chip grid h-8 w-8 place-items-center rounded-sm bg-black/75 ring-1 ring-inset ring-white/15">
				<BlipIcon :sprite="point.sprite" :colour="pointColour(point)" :size="iS(18)" plain />
			</span>
			<span class="stem" />
			<span class="dot" />
		</button>
	</div>
</template>

<script setup lang="ts">
const markers = useMarkersStore();
const { points, selected, searchHits } = storeToRefs(markers);

/**
 * Only markers that have been on screen get a node, added a few per frame: a big server has
 * hundreds of blips, and building them all at once stalls the page while the map opens.
 */
const MOUNT_PER_FRAME = 40;
const mounted = shallowRef(new Set<string>());
const mountQueue: string[] = [];
let mountFrame = 0;

const mountSome = () => {
	mountFrame = 0;
	const next = new Set(mounted.value);
	// one that left the screen meanwhile waits until it is back
	for (const id of mountQueue.splice(0, MOUNT_PER_FRAME)) if (last.has(id)) next.add(id);
	mounted.value = next;
	if (mountQueue.length) mountFrame = requestAnimationFrame(mountSome);
};

const queueMount = (id: string) => {
	if (mounted.value.has(id) || mountQueue.includes(id)) return;
	mountQueue.push(id);
	if (!mountFrame) mountFrame = requestAnimationFrame(mountSome);
};

const visiblePoints = computed(() => {
	const hits = searchHits.value;
	const allow = hits ? new Set(hits) : null;
	const ready = mounted.value;
	return points.value.filter((point) => ready.has(point.id) && (!allow || allow.has(point.id)));
});

const markerZ = (id: string) => {
	if (id === "mine:self") return 3;
	if (id === "gps:waypoint") return 1;
	return 2;
};

const nodes = new Map<string, HTMLElement>();
const last = new Map<string, { x: number; y: number; scale: number }>();
const parked = "translate3d(-10000px, -10000px, 0)";

/** Screen pos, then scale around tip, then tip offset. Origin must stay 0 0. */
const pinAt = (x: number, y: number, scale: number) =>
	`translate3d(${(x * 100).toFixed(3)}vw, ${(y * 100).toFixed(3)}vh, 0) scale(${scale.toFixed(3)}) translate3d(-50%, -100%, 0)`;

const pick = (id: string) => {
	markers.select(id);
	fetchNui("ThreeDMapFocus", { id }, "ok");
};

const setWaypoint = (id: string) => {
	markers.select(id);
	if (id === "gps:waypoint") {
		fetchNui("ThreeDMapDelete", { id }, "ok");
		return;
	}
	fetchNui("ThreeDMapWaypoint", { id }, "ok");
};

const setNode = (id: string, el: Element | null) => {
	if (el instanceof HTMLElement) {
		nodes.set(id, el);
		const prev = last.get(id);
		el.style.transform = prev ? pinAt(prev.x, prev.y, prev.scale) : parked;
		return;
	}
	nodes.delete(id);
	last.delete(id);
};

const applyPositions = (positions: { id: string; x: number; y: number; scale: number }[]) => {
	const seen = new Set<string>();
	for (const pos of positions) {
		seen.add(pos.id);
		const el = nodes.get(pos.id);
		const scale = Number.isFinite(pos.scale) ? pos.scale : 1;
		if (!el) {
			// placed where it belongs as soon as its node exists (setNode reads `last`)
			last.set(pos.id, { x: pos.x, y: pos.y, scale });
			queueMount(pos.id);
			continue;
		}
		const prev = last.get(pos.id);
		if (prev && Math.abs(prev.x - pos.x) < 0.0005 && Math.abs(prev.y - pos.y) < 0.0005 && Math.abs(prev.scale - scale) < 0.01) {
			continue;
		}
		el.style.transform = pinAt(pos.x, pos.y, scale);
		last.set(pos.id, { x: pos.x, y: pos.y, scale });
	}
	for (const [id, el] of nodes) {
		if (seen.has(id)) continue;
		el.style.transform = parked;
		last.delete(id);
	}
	for (const id of last.keys()) {
		if (!seen.has(id) && !nodes.has(id)) last.delete(id);
	}
};

const stop = onNuiAction("UpdateMarkerPositions", (data) => {
	const payload = data as { positions?: { id: string; x: number; y: number; scale: number }[] };
	applyPositions(payload.positions ?? []);
});

onMounted(() => {
	fetchNui("ThreeDMapReady", {}, "ok");
});

onUnmounted(() => {
	stop();
	if (mountFrame) cancelAnimationFrame(mountFrame);
});
</script>

<style scoped>
.marker {
	transform: translate3d(-10000px, -10000px, 0);
	transform-origin: 0 0;
	will-change: transform;
	contain: layout style;
}

.chip {
	overflow: visible;
}

.marker.is-on > .chip {
	background: rgb(0 0 0 / 0.9);
	box-shadow: inset 0 0 0 1px rgb(255 255 255 / 0.85);
}

.stem {
	width: 1px;
	height: 10px;
	background: #fff;
}

.dot {
	width: 4px;
	height: 4px;
	border-radius: 999px;
	background: #fff;
}
</style>
