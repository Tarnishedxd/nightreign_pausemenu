<template>
	<div class="flex h-full min-h-0 flex-col bg-black/75 px-14 py-7 text-white" :style="panelStyle">
		<header class="flex shrink-0 items-center gap-3 border-b border-white/10 pb-5">
			<BrandLogo class="h-10 w-auto shrink-0" />
			<h1 class="min-w-0 truncate text-2xl font-semibold tracking-tight">{{ _t("ui.stats.title", "Stats") }}</h1>
		</header>

		<main class="flex min-h-0 flex-1 flex-col pt-6">
			<Transition
				mode="out-in"
				enter-active-class="transition duration-300 ease-out"
				enter-from-class="translate-y-2 opacity-0"
				enter-to-class="translate-y-0 opacity-100"
				leave-active-class="transition duration-150 ease-in"
				leave-from-class="opacity-100"
				leave-to-class="opacity-0">
				<div v-if="showSkeleton" key="skeleton" class="grid h-full min-h-0 grid-cols-[minmax(0,1fr)_26rem] gap-8">
					<div
						class="flex min-h-0 flex-col gap-2 overflow-y-auto pr-1 [scrollbar-color:rgb(255_255_255/0.22)_transparent] [scrollbar-width:thin] [&::-webkit-scrollbar-thumb]:rounded-full [&::-webkit-scrollbar-thumb]:bg-white/20 [&::-webkit-scrollbar]:w-1.5">
						<article
							v-for="(width, index) in skillSkeletonWidths"
							:key="index"
							class="flex min-h-14 items-center gap-4 rounded-md border border-[color:var(--panel-row-border)] bg-[var(--panel-row-bg)] px-4 py-3 shadow-[var(--panel-row-shadow)]">
							<div class="size-10 shrink-0 animate-pulse rounded-md bg-white/20" />
							<div class="min-w-0 flex-1">
								<div class="h-5 animate-pulse rounded bg-white/25" :style="{ width: `${width}%` }" />
							</div>
							<div class="flex w-[26rem] shrink-0 items-center gap-1.5">
								<div v-for="segment in 5" :key="segment" class="h-2.5 flex-1 animate-pulse rounded-sm bg-white/20" />
							</div>
							<div class="h-5 w-8 shrink-0 animate-pulse rounded bg-white/20" />
						</article>
					</div>
					<aside class="flex min-h-0 flex-col gap-6">
						<article
							class="rounded-md border border-[color:var(--panel-row-border)] bg-[var(--panel-row-bg)] px-5 py-5 shadow-[var(--panel-row-shadow)]">
							<div class="flex items-center justify-between gap-4">
								<div class="h-8 w-40 animate-pulse rounded bg-white/25" />
								<div class="size-12 shrink-0 animate-pulse rounded-md bg-white/20" />
							</div>
							<div class="mx-auto mt-6 h-10 w-28 animate-pulse rounded bg-white/25" />
							<div class="mt-5 h-4 w-full animate-pulse rounded bg-white/15" />
							<div class="mt-2 h-4 w-4/5 animate-pulse rounded bg-white/15" />
						</article>
						<article
							class="rounded-md border border-[color:var(--panel-row-border)] bg-[var(--panel-row-bg)] px-5 shadow-[var(--panel-row-shadow)]">
							<div class="py-4">
								<div class="h-5 w-24 animate-pulse rounded bg-white/25" />
							</div>
							<div
								v-for="(width, index) in careerSkeletonWidths"
								:key="index"
								class="flex items-center justify-between gap-4 border-t border-white/10 py-3.5">
								<div class="h-4 animate-pulse rounded bg-white/25" :style="{ width: `${width}%` }" />
								<div class="h-4 w-16 shrink-0 animate-pulse rounded bg-white/20" />
							</div>
						</article>
					</aside>
				</div>
				<div v-else key="stats" class="grid h-full min-h-0 grid-cols-[minmax(0,1fr)_26rem] gap-8">
					<div
						class="flex min-h-0 flex-col gap-2 overflow-y-auto pr-1 [scrollbar-color:rgb(255_255_255/0.22)_transparent] [scrollbar-width:thin] [&::-webkit-scrollbar-thumb]:rounded-full [&::-webkit-scrollbar-thumb]:bg-white/20 [&::-webkit-scrollbar]:w-1.5">
						<article
							v-for="(skill, index) in skills"
							:key="skill.id"
							:data-skill="index"
							class="flex min-h-14 cursor-pointer items-center gap-4 rounded-md border border-[color:var(--panel-row-border)] bg-[var(--panel-row-bg)] px-4 py-3 shadow-[var(--panel-row-shadow)] transition-colors duration-200"
							:class="index === selected ? '!bg-[var(--panel-row-bg-focus)]' : 'hover:bg-[var(--panel-row-bg-hover)]'"
							@click="selected = index">
							<span
								class="grid size-10 shrink-0 place-items-center rounded-md bg-black/40 ring-1 ring-inset ring-white/15">
								<component :is="skillIcon(skill.id)" :size="iS(18)" class="opacity-80" />
							</span>
							<p class="min-w-0 flex-1 truncate text-lg text-white/90">{{ skillLabel(skill.id) }}</p>
							<div
								class="flex w-[26rem] shrink-0 items-center gap-1.5"
								:aria-label="`${skillLabel(skill.id)} ${skill.value}`">
								<div v-for="segment in 5" :key="segment" class="h-2.5 flex-1 overflow-hidden rounded-sm bg-white/15">
									<div
										class="h-full rounded-sm bg-[var(--panel-primary)] transition-[width] duration-200"
										:style="{ width: segmentWidth(skill.value, segment - 1) }" />
								</div>
							</div>
							<span class="w-10 shrink-0 text-right text-base tabular-nums text-white/75">{{ skill.value }}</span>
						</article>
					</div>
					<aside v-if="selectedSkill" class="flex min-h-0 flex-col gap-6">
						<article
							class="rounded-md border border-[color:var(--panel-row-border)] bg-[var(--panel-row-bg)] px-5 py-5 shadow-[var(--panel-row-shadow)]">
							<div class="flex items-center justify-between gap-4">
								<h2 class="min-w-0 truncate text-3xl font-semibold leading-tight tracking-tight">
									{{ skillLabel(selectedSkill.id) }}
								</h2>
								<span
									class="grid size-12 shrink-0 place-items-center rounded-md bg-black/40 ring-1 ring-inset ring-white/15">
									<component :is="skillIcon(selectedSkill.id)" :size="iS(22)" class="opacity-80" />
								</span>
							</div>
							<p class="mt-6 text-center text-5xl font-semibold tabular-nums leading-none">
								{{ selectedSkill.value }}<span class="text-white/45">/100</span>
							</p>
							<p class="mt-5 text-base leading-6 text-white/70">{{ selectedHint }}</p>
						</article>
						<article
							class="rounded-md border border-[color:var(--panel-row-border)] bg-[var(--panel-row-bg)] px-5 shadow-[var(--panel-row-shadow)]">
							<p class="py-4 text-lg font-semibold">{{ _t("ui.stats.career", "Other Stats") }}</p>
							<div
								v-for="row in careerRows"
								:key="row.id"
								class="flex items-center justify-between gap-4 border-t border-white/10 py-3.5">
								<p class="min-w-0 truncate text-base text-white/80">{{ row.label }}</p>
								<span class="shrink-0 text-base tabular-nums text-white/60">{{ row.value }}</span>
							</div>
						</article>
					</aside>
				</div>
			</Transition>
		</main>

		<footer class="mt-5 flex shrink-0 items-center justify-end gap-3 border-t border-white/10 pt-4">
			<span v-for="hint in keyHints" :key="hint.locale" class="flex items-center gap-1.5 text-sm text-white/70">
				<span
					class="grid min-h-7 min-w-7 place-items-center rounded-md border border-white/10 bg-white/10 px-2 py-1 font-medium tracking-wide text-white shadow-[inset_0_0_6px_rgb(255_255_255/0.04)]">
					<component :is="hint.icon" v-if="hint.icon" :size="iS(16)" />
					<template v-else>{{ hint.key }}</template>
				</span>
				{{ hint.label }}
			</span>
		</footer>
	</div>
</template>

<script setup lang="ts">
import { ArrowUpDown, Car, Crosshair, Dumbbell, EyeOff, HeartPulse, Plane, Wind } from "@lucide/vue";

const { panelStyle } = usePreferences();
const { payload } = useStats();

const skillSkeletonWidths = [46, 38, 52, 34, 44, 40, 58];
const careerSkeletonWidths = [40, 48, 28, 56, 50];
const selected = ref(0);
const revealHold = ref(true);
let revealTimer = 0;
let revealStarted = 0;

const icons: Record<StatSkillId, Component> = {
	stamina: HeartPulse,
	shooting: Crosshair,
	strength: Dumbbell,
	stealth: EyeOff,
	flying: Plane,
	driving: Car,
	lung: Wind,
};

const labels: Record<StatSkillId, string> = {
	stamina: "Stamina",
	shooting: "Shooting",
	strength: "Strength",
	stealth: "Stealth",
	flying: "Flying",
	driving: "Driving",
	lung: "Lung Capacity",
};

const hints: Record<StatSkillId, string> = {
	stamina: "How long you can sprint, swim, and cycle. Raise it by running, swimming, and riding.",
	shooting: "How steady your aim is. Raise it by landing shots.",
	strength: "Melee power and climbing. Raise it by fighting up close.",
	stealth: "How quiet you move. Raise it by staying out of sight.",
	flying: "How well you handle aircraft. Raise it by flying.",
	driving: "How well you handle ground vehicles. Raise it by driving.",
	lung: "How long you can stay underwater. Raise it by swimming below the surface.",
};

const keyHints = computed(() => [
	{ icon: ArrowUpDown, locale: "move", label: _t("ui.stats.move", "Move") },
	{ key: "ESC", locale: "close", label: _t("ui.stats.close", "Close") },
]);

const skills = computed(() => payload.value?.skills ?? []);
const showSkeleton = computed(() => revealHold.value || payload.value === null);
const selectedSkill = computed(() => skills.value[selected.value] ?? null);

const skillIcon = (id: StatSkillId) => icons[id];
const skillLabel = (id: StatSkillId) => _t(`ui.stats.${id}`, labels[id]);
const skillHint = (id: StatSkillId) => _t(`ui.stats.${id}Hint`, hints[id]);

const selectedHint = computed(() => {
	const skill = skills.value[selected.value];
	return skill ? skillHint(skill.id) : "";
});

const formatDuration = (ms: number) => {
	const totalMinutes = Math.floor(Math.max(0, ms) / 60000);
	const hours = Math.floor(totalMinutes / 60);
	const minutes = totalMinutes % 60;
	if (hours > 0) return _t("ui.stats.hours", "%dh %dm", hours, minutes);
	return _t("ui.stats.minutes", "%dm", minutes);
};

const formatDistance = (metres: number) => {
	const value = Math.max(0, metres);
	if (value >= 1000) {
		const km = value / 1000;
		const digits = km >= 10 ? 0 : 1;
		const text = new Intl.NumberFormat(localeTag(), { minimumFractionDigits: digits, maximumFractionDigits: digits }).format(km);
		return _t("ui.stats.kilometres", "%s km", text);
	}
	return _t("ui.stats.metres", "%d m", Math.round(value));
};

const careerRows = computed(() => {
	const career = payload.value?.career;
	if (!career) return [];
	return [
		{ id: "session", label: _t("ui.stats.session", "This session"), value: formatDuration(career.session) },
		{ id: "played", label: _t("ui.stats.played", "Time played"), value: formatDuration(career.played) },
		{ id: "deaths", label: _t("ui.stats.deaths", "Deaths"), value: String(career.deaths) },
		{ id: "onFoot", label: _t("ui.stats.onFoot", "Distance on foot"), value: formatDistance(career.onFoot) },
		{ id: "driven", label: _t("ui.stats.driven", "Distance driven"), value: formatDistance(career.driven) },
	];
});

const segmentWidth = (value: number, index: number) => {
	const amount = value - index * 20;
	if (amount >= 20) return "100%";
	if (amount <= 0) return "0%";
	return `${(amount / 20) * 100}%`;
};

const scheduleReveal = () => {
	window.clearTimeout(revealTimer);
	if (!payload.value) return;
	const remain = 350 - (Date.now() - revealStarted);
	revealTimer = window.setTimeout(
		() => {
			if (payload.value) revealHold.value = false;
		},
		Math.max(0, remain),
	);
};

const onBack = () => {
	void fetchNui("PauseCloseStats", {}, "ok");
};

const onKeyDown = (event: KeyboardEvent) => {
	if (event.key === "Escape") {
		event.preventDefault();
		onBack();
		return;
	}
	if (showSkeleton.value || !skills.value.length) return;
	if (event.key === "ArrowDown" || event.key === "ArrowUp") {
		event.preventDefault();
		const direction = event.key === "ArrowDown" ? 1 : -1;
		selected.value = (selected.value + direction + skills.value.length) % skills.value.length;
	}
};

watch(skills, (rows) => {
	if (selected.value >= rows.length) selected.value = 0;
});

watch(payload, () => {
	scheduleReveal();
});

watch(selected, async (index) => {
	if (showSkeleton.value) return;
	await nextTick();
	document.querySelector(`[data-skill="${index}"]`)?.scrollIntoView({ block: "nearest" });
});

onMounted(() => {
	revealStarted = Date.now();
	revealHold.value = true;
	scheduleReveal();
	window.addEventListener("keydown", onKeyDown);
});

onUnmounted(() => {
	window.clearTimeout(revealTimer);
	window.removeEventListener("keydown", onKeyDown);
});
</script>
