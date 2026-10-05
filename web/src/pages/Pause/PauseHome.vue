<template>
	<div class="relative h-full w-full select-none text-white">
		<div class="vignette pointer-events-none"></div>

		<div
			v-if="player.showBranding"
			class="pause-brand-in absolute left-8 top-8 z-[2] flex items-center gap-3.5">
			<BrandLogo class="h-11 w-11 shrink-0" />
			<p class="text-xl font-semibold leading-none tracking-widest text-white">{{ player.serverName }}</p>
		</div>

		<div class="pause-player-in absolute right-8 top-8 z-[2] flex flex-col items-end">
			<p class="max-w-[24rem] truncate text-lg font-semibold leading-tight">
				{{ player.name }}
				<span class="ml-1.5 text-sm font-medium text-white/50">#{{ player.source }}</span>
			</p>
			<p class="mt-1 text-sm text-white/55">
				<span class="text-[11px] uppercase tracking-wide">{{ _t("ui.pause.cash", "Cash") }}</span>
				<span class="ml-1.5 tabular-nums text-white/85">{{ cashLabel }}</span>
				<span class="mx-2 text-white/25">|</span>
				<span class="text-[11px] uppercase tracking-wide">{{ _t("ui.pause.bank", "Bank") }}</span>
				<span class="ml-1.5 tabular-nums text-white/85">{{ bankLabel }}</span>
			</p>
			<p class="mt-1 text-sm text-white/55">
				<span class="text-[11px] uppercase tracking-wide">{{ _t("ui.pause.players", "Players") }}</span>
				<span class="ml-1.5 tabular-nums text-white/85">{{ player.players }} / {{ player.maxPlayers }}</span>
			</p>
		</div>

		<div
			class="pointer-events-none absolute bottom-16 left-4 z-0 h-[38rem] w-[32rem] rounded-tr-full bg-black/65 blur-3xl"
			aria-hidden="true"></div>

		<div class="absolute bottom-28 left-10 z-[1] flex w-[24rem] flex-col gap-2">
			<p class="pause-row tracking-widest text-5xl mb-3 italic leading-none">
				{{ _t("ui.pause.paused", "PAUSED") }}
			</p>
			<button
				v-for="(item, index) in items"
				:key="item.id"
				type="button"
				class="pause-row rounded-r-md border-l-2 bg-gradient-to-r h-16 flex items-center gap-4 pl-6 pr-4 transition-all duration-150 hover:translate-x-1 active:scale-[1.02]"
				:class="rowClass(item.id, index)"
				:style="{ animationDelay: `${(index + 1) * 40}ms` }"
				@mouseenter="selected = index"
				@click="item.action">
				<span :class="item.id === 'quit' ? '!text-red-400/85' : 'text-white/85'">
					<component :is="item.icon" :stroke-width="1.25" :size="iS(21)" />
				</span>
				<span class="flex flex-col text-left min-w-0 flex-1">
					<span class="block truncate text-lg" :class="item.id === 'quit' ? '!text-red-400/85' : 'text-white/85'">{{
						item.label
					}}</span>
					<span
						v-if="item.hint"
						class="block truncate text-[12px] font-light"
						:class="item.id === 'quit' ? '!text-red-400/50' : 'text-white/50'"
						>{{ item.hint }}</span
					>
				</span>
				<span
					v-if="item.id === 'continue'"
					class="grid min-h-6 min-w-6 shrink-0 place-items-center rounded-sm bg-white/10 px-2 py-1 text-xs font-medium tracking-wide text-white ring-1 ring-inset ring-white/15"
					@click.stop="onContinue">
					ESC
				</span>
			</button>
		</div>

		<!-- Quit Confirm Modal -->
		<Transition
			enter-active-class="transition duration-300 ease-out"
			enter-from-class="opacity-0"
			enter-to-class="opacity-100"
			leave-active-class="transition duration-200 ease-in"
			leave-from-class="opacity-100"
			leave-to-class="opacity-0">
			<div v-if="quitConfirm" class="absolute inset-0 z-[5] grid place-items-center bg-black/40 px-6" @click.self="onQuitCancel">
				<div class="pause-alert w-full max-w-[24rem] rounded-lg border border-white/[0.08] bg-white/10 px-5 py-5">
					<p class="text-xl font-semibold">{{ _t("ui.pause.quitConfirm", "Leave the server?") }}</p>
					<p class="mt-1 text-sm text-white/55">{{ _t("ui.pause.quitSure", "Are you sure you want to disconnect?") }}</p>
					<div class="mt-5 flex gap-2">
						<button
							type="button"
							class="flex-1 rounded-lg border border-white/[0.08] px-3 py-2.5 text-sm font-medium transition duration-150 active:scale-[0.98]"
							:class="quitChoice === 0 ? 'bg-white/20 text-white' : 'bg-white/10 text-white/70 hover:bg-white/15'"
							@mouseenter="quitChoice = 0"
							@click="onQuitCancel">
							{{ _t("ui.pause.quitNo", "No") }}
						</button>
						<button
							type="button"
							class="flex-1 rounded-lg border border-white/[0.08] px-3 py-2.5 text-sm font-medium transition duration-150 active:scale-[0.98]"
							:class="quitChoice === 1 ? 'bg-red-400/25 text-white' : 'bg-red-400/15 text-white/85 hover:bg-red-400/20'"
							@mouseenter="quitChoice = 1"
							@click="onQuitConfirm">
							{{ _t("ui.pause.quitYes", "Yes") }}
						</button>
					</div>
				</div>
			</div>
		</Transition>
	</div>
</template>

<script setup lang="ts">
import { Play, Map as MapIcon, Box, Settings, LogOut, ChartColumn } from "@lucide/vue";

const store = useMainStore();
const { begin, accept } = useStats();
const { quitConfirm, player } = storeToRefs(store);
const selected = ref(0);
const quitChoice = ref(0);

const money = (amount: number) => {
	const value = Number(amount) || 0;
	const currency = player.value.currency || "USD";
	const format = player.value.currencyFormat || "en-US";
	try {
		return new Intl.NumberFormat(format, {
			style: "currency",
			currency,
			maximumFractionDigits: 0,
		}).format(value);
	} catch {
		// Invalid currency / currencyFormat in config must not break the pause screen.
		return `${Math.round(value).toLocaleString("en-US")} ${currency}`;
	}
};

const cashLabel = computed(() => money(player.value.cash));
const bankLabel = computed(() => money(player.value.bank));

const rowClass = (id: string, index: number) => {
	const on = index === selected.value;
	if (id === "quit") {
		return on
			? "from-red-950/75 via-red-950/55 to-transparent border-l-red-600"
			: "from-red-950/65 via-red-950/45 to-transparent border-l-red-500";
	}
	return on
		? "from-white/15 via-white/5 to-transparent ring-1 ring-inset ring-white/15"
		: "from-white/5 to-transparent border-l-white/50";
};

const items = computed(() => [
	{
		id: "continue",
		label: _t("ui.pause.continue", "Continue"),
		hint: _t("ui.pause.continueHint", "Pick up where you left off"),
		icon: Play,
		action: onContinue,
	},
	{
		id: "map",
		label: _t("ui.pause.map", "Map"),
		hint: _t("ui.pause.mapHint", "Open the city map"),
		icon: MapIcon,
		action: onMap,
	},
	...(player.value.enable3DMap
		? [
				{
					id: "map3d",
					label: _t("ui.pause.map3d", "3D Map"),
					hint: _t("ui.pause.map3dHint", "Look down over the city"),
					icon: Box,
					action: onMap3d,
				},
			]
		: []),
	{
		id: "stats",
		label: _t("ui.pause.stats", "Stats"),
		hint: _t("ui.pause.statsHint", "Skills and progress"),
		icon: ChartColumn,
		action: onStats,
	},
	{
		id: "settings",
		label: _t("ui.pause.settings", "Settings"),
		hint: _t("ui.pause.settingsHint", "Display, audio and keys"),
		icon: Settings,
		action: onSettings,
	},
	{
		id: "quit",
		label: _t("ui.pause.quit", "Quit"),
		icon: LogOut,
		action: onQuitRequest,
	},
]);

const onContinue = () => {
	fetchNui("PauseContinue", {}, "ok");
};
const onMap = () => {
	fetchNui("PauseOpenMap", {}, "ok");
};
const onMap3d = () => {
	fetchNui("PauseOpenMap3d", {}, "ok");
};
const onStats = () => {
	const request = begin();
	void fetchNui<StatsPayload>("PauseOpenStats", {}).then((data) => accept(request, data));
};
const onSettings = () => {
	fetchNui("PauseOpenSettings", {}, "ok");
};
const onQuitRequest = () => {
	fetchNui("PauseQuitRequest", {}, "ok");
};
const onQuitCancel = () => {
	fetchNui("PauseQuitCancel", {}, "ok");
};
const onQuitConfirm = () => {
	fetchNui("PauseQuitConfirm", {}, "ok");
};

const onKeyDown = (e: KeyboardEvent) => {
	if (e.key === "Escape") {
		e.preventDefault();
		if (quitConfirm.value) onQuitCancel();
		else onContinue();
		return;
	}

	if (quitConfirm.value) {
		if (e.key === "ArrowLeft" || e.key === "ArrowUp") {
			e.preventDefault();
			quitChoice.value = 0;
		} else if (e.key === "ArrowRight" || e.key === "ArrowDown") {
			e.preventDefault();
			quitChoice.value = 1;
		} else if (e.key === "Enter") {
			e.preventDefault();
			if (quitChoice.value === 1) onQuitConfirm();
			else onQuitCancel();
		}
		return;
	}

	if (e.key === "ArrowUp") {
		e.preventDefault();
		selected.value = (selected.value + items.value.length - 1) % items.value.length;
	} else if (e.key === "ArrowDown") {
		e.preventDefault();
		selected.value = (selected.value + 1) % items.value.length;
	} else if (e.key === "Enter") {
		e.preventDefault();
		items.value[selected.value]?.action();
	}
};

watch(quitConfirm, (open) => {
	if (open) quitChoice.value = 0;
});

watch(
	() => items.value.length,
	(count) => {
		if (selected.value >= count) selected.value = 0;
	},
);

onMounted(() => {
	window.addEventListener("keydown", onKeyDown);
});
onUnmounted(() => {
	window.removeEventListener("keydown", onKeyDown);
});
</script>

<style scoped>
.vignette {
	position: fixed;
	top: 0;
	left: 0;
	width: 100%;
	height: 100%;
	box-shadow: 0 0 320px 80px rgba(10, 10, 10, 0.92) inset;
}

.pause-brand-in {
	animation: pause-brand-in 360ms ease-out both;
}

.pause-player-in {
	animation: pause-player-in 360ms ease-out both;
}

.pause-title {
	font-style: italic;
	font-weight: 600;
	text-shadow:
		0 2px 16px rgba(0, 0, 0, 0.95),
		0 0 36px rgba(0, 0, 0, 0.8);
}

.pause-alert {
	animation: pause-alert-in 320ms ease-out both;
}

@keyframes pause-alert-in {
	from {
		opacity: 0;
		transform: translateY(16px);
	}
	to {
		opacity: 1;
		transform: none;
	}
}

.pause-row {
	animation: pause-row-in 280ms ease-out backwards;
}

@keyframes pause-brand-in {
	from {
		opacity: 0;
		transform: translateX(-12px);
	}
	to {
		opacity: 1;
		transform: none;
	}
}

@keyframes pause-player-in {
	from {
		opacity: 0;
		transform: translateX(12px);
	}
	to {
		opacity: 1;
		transform: none;
	}
}

@keyframes pause-row-in {
	from {
		opacity: 0;
		transform: translateY(8px);
	}
	to {
		opacity: 1;
		transform: none;
	}
}
</style>
