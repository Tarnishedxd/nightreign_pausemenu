<template>
	<div class="pointer-events-none absolute inset-0 z-[4]">
		<Transition
			enter-active-class="transition duration-300 ease-out"
			enter-from-class="translate-x-3 opacity-0"
			enter-to-class="translate-x-0 opacity-100"
			leave-active-class="transition duration-200 ease-in"
			leave-from-class="translate-x-0 opacity-100"
			leave-to-class="translate-x-3 opacity-0">
			<button
				v-if="!open"
				type="button"
				class="map-key pointer-events-auto absolute right-6 top-6 grid !min-h-10 !min-w-10 place-items-center !px-0 !py-0 !text-base active:scale-[0.98]"
				@click="open = true">
				<Eye :size="iS(18)" />
			</button>
		</Transition>

		<Transition
			enter-active-class="transition duration-300 ease-out"
			enter-from-class="translate-x-3 opacity-0"
			enter-to-class="translate-x-0 opacity-100"
			leave-active-class="transition duration-200 ease-in"
			leave-from-class="translate-x-0 opacity-100"
			leave-to-class="translate-x-3 opacity-0">
			<div
				v-if="open"
				class="pointer-events-auto absolute bottom-6 right-6 top-20 flex w-[24rem] min-h-0 flex-col items-end gap-0.5">
				<aside class="flex min-h-0 w-full flex-1 flex-col gap-0.5 overflow-hidden">
					<div class="map-bar-on flex h-10 w-full shrink-0 items-center justify-between gap-2 rounded-sm pl-4 pr-2">
						<p class="flex items-center gap-2 text-sm font-semibold text-black">
							<MapPinned :size="iS(16)" />
							{{ _t("ui.map3d.blips", "Blips") }}
						</p>
						<button
							type="button"
							class="grid h-7 w-7 place-items-center text-black/55 transition-opacity duration-150 hover:opacity-100"
							@click="open = false">
							<EyeOff :size="iS(16)" />
						</button>
					</div>

					<div
						class="flex min-h-0 w-full flex-1 flex-col items-end gap-0.5 overflow-y-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
						<p v-if="!hasRows" class="map-bar w-full rounded-sm px-4 py-3 text-sm text-white/55">
							{{ _t("ui.map.empty", "Nothing matches") }}
						</p>
						<section v-for="group in visibleGroups" :key="group.id" class="flex w-full flex-col items-end gap-0.5">
							<button
								type="button"
								class="map-bar flex h-9 w-full items-center gap-2 rounded-sm px-3 text-left text-sm font-medium text-white/70 active:scale-[0.98]"
								@click="collapsed[group.id] = !collapsed[group.id]">
								<ChevronDown
									:size="iS(16)"
									class="shrink-0 transition-transform duration-200"
									:class="collapsed[group.id] ? '-rotate-90' : ''" />
								<span class="truncate">{{ _t(group.label, group.label) }}</span>
							</button>
							<div v-if="!collapsed[group.id]" class="flex w-full flex-col items-end gap-0.5">
								<div
									v-for="stack in stacksIn(group.id)"
									:key="stack.key"
									class="map-skew group flex h-11 w-fit max-w-full shrink-0 cursor-pointer items-center gap-2 pl-3 pr-2 text-sm active:scale-[0.98]"
									:class="inStack(stack) ? 'map-bar-on' : 'map-bar'">
									<button
										type="button"
										class="flex min-w-0 flex-1 cursor-pointer items-center gap-2 text-left"
										@click="focus(current(stack).id)"
										@dblclick="setWaypoint(current(stack).id)">
										<BlipIcon
											:sprite="current(stack).sprite"
											:colour="blipColourHex(current(stack).blipColour ?? 3)"
											:size="iS(22)" />
										<span class="min-w-0 flex-1 truncate">{{
											_t(current(stack).label, current(stack).label)
										}}</span>
									</button>
									<div
										v-if="inStack(stack) && stack.points.length > 1"
										class="flex shrink-0 items-center gap-0.5 tabular-nums">
										<button
											type="button"
											class="grid h-6 w-6 place-items-center opacity-70 transition-opacity duration-150 hover:opacity-100"
											@click="step(stack, -1)">
											<ChevronLeft :size="iS(14)" />
										</button>
										<span class="min-w-7 text-center text-xs"
											>{{ indexOf(stack) + 1 }}/{{ stack.points.length }}</span
										>
										<button
											type="button"
											class="grid h-6 w-6 place-items-center opacity-70 transition-opacity duration-150 hover:opacity-100"
											@click="step(stack, 1)">
											<ChevronRight :size="iS(14)" />
										</button>
									</div>
									<button
										type="button"
										class="grid h-6 w-6 shrink-0 place-items-center opacity-70 transition-opacity duration-150 hover:opacity-100"
										@click="toggleHidden(stack)">
										<EyeOff v-if="hiddenRows[stack.key]" :size="iS(14)" />
										<Eye v-else :size="iS(14)" />
									</button>
								</div>
							</div>
						</section>
					</div>
				</aside>

				<div class="w-full shrink-0 overflow-hidden transition-[height] duration-300 ease-out" :style="{ height: infoHeight }">
					<div class="min-h-0">
						<section
							v-if="detail"
							ref="infoCard"
							class="map-bar px-3 py-2 transition-transform duration-300 ease-out"
							:class="infoShown ? 'translate-y-0' : 'translate-y-full'">
							<div class="flex items-center gap-2 text-sm">
								<BlipIcon :sprite="detail.sprite" :colour="blipColourHex(detail.blipColour ?? 3)" :size="iS(22)" />
								<span class="min-w-0 flex-1 truncate">{{ _t(detail.label, detail.label) }}</span>
								<span class="shrink-0 tabular-nums text-white/55">{{ detail.metres }}m</span>
								<button
									v-if="detail.canDelete && !sheet.placing"
									type="button"
									class="grid h-6 w-6 shrink-0 place-items-center opacity-70 transition-opacity duration-150 hover:opacity-100"
									@click="deletePoint">
									<Trash2 :size="iS(14)" />
								</button>
							</div>
							<template v-if="detail.owned">
								<p class="mt-2 flex items-center gap-1.5 text-sm font-medium text-white/55">
									<Share2 :size="iS(14)" />
									{{ _t("ui.map3d.shared", "Shared") }}
								</p>
								<p v-if="detailShares.length === 0" class="mt-1 text-sm text-white/55">
									{{ _t("ui.map3d.empty", "Nothing here") }}
								</p>
								<div v-else class="mt-1 flex flex-col gap-0.5">
									<div
										v-for="person in detailShares"
										:key="person.identifier"
										class="flex items-center gap-2 text-sm text-white/85">
										<span class="min-w-0 flex-1 truncate">{{ person.name }}</span>
										<button
											type="button"
											class="grid h-6 w-6 shrink-0 place-items-center opacity-70 transition-opacity duration-150 hover:opacity-100"
											@click="revokeShare(person.identifier)">
											<X :size="iS(14)" />
										</button>
									</div>
								</div>
							</template>
							<p v-else-if="detail.group === 'shared' && sharedLine" class="mt-1 text-sm text-white/55">
								{{ sharedLine }}
							</p>
						</section>
					</div>
				</div>

				<div
					v-if="requests.length"
					class="flex max-h-36 w-full shrink-0 flex-col gap-0.5 overflow-y-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
					<div
						v-for="request in requests"
						:key="request.id"
						class="map-bar flex items-center gap-2 px-3 py-1.5">
						<BlipIcon :sprite="request.sprite" :colour="blipColourHex(request.blipColour ?? 3)" :size="iS(22)" />
						<div class="min-w-0 flex-1">
							<p class="truncate text-sm text-white">{{ request.label }}</p>
							<p class="truncate text-xs text-white/45">{{ request.from }}</p>
						</div>
						<button type="button" :class="primaryBtn" @click="fetchNui('ThreeDMapAccept', { id: request.id }, 'ok')">
							{{ _t("ui.map3d.accept", "Accept") }}
						</button>
						<button type="button" :class="secondaryBtn" @click="fetchNui('ThreeDMapDecline', { id: request.id }, 'ok')">
							{{ _t("ui.map3d.decline", "Decline") }}
						</button>
					</div>
				</div>

				<div class="w-full shrink-0">
					<div v-if="sheet.placing || copyDraft" class="grid grid-cols-1 gap-0.5">
						<button type="button" :class="[secondaryBtn, 'flex w-full items-center justify-center gap-1.5']" @click="cancelPlace">
							<X :size="iS(16)" />
							{{ _t("ui.map3d.cancel", "Cancel") }}
						</button>
					</div>
					<div v-else-if="selectedPoint && selectedFooterCount > 0" :class="selectedFooterClass">
						<button
							v-if="canSetWaypoint"
							type="button"
							:class="[primaryBtn, 'flex w-full items-center justify-center gap-1.5']"
							@click="setWaypoint()">
							<span class="inline-flex items-center justify-center gap-1.5">
								<Check v-if="waypointShown" :size="iS(16)" />
								<MapPin v-else :size="iS(16)" />
								{{
									waypointShown
										? _t("ui.map3d.waypointSet", "Waypoint set")
										: _t("ui.map3d.waypoint", "Set waypoint")
								}}
							</span>
						</button>
						<button
							v-if="showShare"
							type="button"
							:class="[primaryBtn, 'flex w-full items-center justify-center gap-1.5']"
							@click="openShare">
							<Share2 :size="iS(16)" />
							{{ _t("ui.map3d.share", "Share") }}
						</button>
						<button
							v-if="canCopyGlobal"
							type="button"
							:class="[primaryBtn, 'flex w-full items-center justify-center gap-1.5']"
							@click="beginCopy">
							<Copy :size="iS(16)" />
							{{ _t("ui.map3d.copyBlip", "Copy Blip") }}
						</button>
					</div>
					<div v-else-if="showCreateRow" :class="createFooterClass">
						<button
							v-if="playerCreator"
							type="button"
							:class="[primaryBtn, 'flex w-full items-center justify-center gap-1.5']"
							@click="beginPlace('personal')">
							<Plus :size="iS(16)" />
							{{ _t("ui.map3d.create", "Create") }}
						</button>
						<button
							v-if="showGlobalCreate"
							type="button"
							:class="[primaryBtn, 'flex w-full items-center justify-center gap-1.5']"
							@click="beginPlace('global')">
							<Globe :size="iS(16)" />
							{{ _t("ui.map3d.createGlobal", "Create Global") }}
						</button>
					</div>
				</div>
			</div>
		</Transition>

		<Teleport to="body">
			<Transition
				enter-active-class="transition duration-200 ease-out"
				enter-from-class="opacity-0"
				enter-to-class="opacity-100"
				leave-active-class="transition duration-200 ease-in"
				leave-from-class="opacity-100"
				leave-to-class="opacity-0">
				<div v-if="drafting" class="fixed inset-0 z-40 grid place-items-center bg-black/40 px-6" :style="panelStyle">
					<section
						class="w-full max-w-xl overflow-hidden rounded-sm bg-black/80 ring-1 ring-white/15 backdrop-blur-xl"
						role="dialog"
						aria-modal="true">
						<div class="map-bar-on flex h-11 items-center gap-2 px-4">
							<Globe v-if="isGlobalDraft" :size="iS(18)" class="text-black" />
							<MapPin v-else :size="iS(18)" class="text-black" />
							<p class="text-base font-semibold text-black">
								{{
									isGlobalDraft
										? _t("ui.map3d.createGlobalBlip", "Create a global blip")
										: _t("ui.map3d.createBlip", "Create a blip")
								}}
							</p>
						</div>
						<div class="max-h-[min(80vh,44rem)] overflow-y-auto px-5 py-4 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
							<template v-if="isGlobalDraft && categoryPick === null">
								<label class="flex items-center gap-1.5 text-sm text-white/55">
									<Folder :size="iS(14)" />
									{{ _t("ui.map3d.category", "Category") }}
								</label>
								<div class="mt-1.5 flex flex-col gap-0.5">
									<button
										v-for="category in globalCategories"
										:key="category.id"
										type="button"
										class="map-bar flex h-10 w-full items-center rounded-sm px-3 text-left text-sm text-white ring-1 ring-inset ring-white/15 transition duration-150 hover:ring-white/30 active:scale-[0.98]"
										@click="categoryPick = category.id">
										<span class="truncate">{{ category.label }}</span>
									</button>
									<button
										type="button"
										class="map-bar flex h-10 w-full items-center gap-2 rounded-sm px-3 text-left text-sm text-white/80 ring-1 ring-inset ring-white/15 transition duration-150 hover:ring-white/30 active:scale-[0.98]"
										@click="categoryPick = 'new'">
										<Plus :size="iS(14)" />
										{{ _t("ui.map3d.newCategory", "New category") }}
									</button>
								</div>
							</template>
							<template v-else>
								<template v-if="isGlobalDraft && categoryPick === 'new'">
									<label class="flex items-center gap-1.5 text-sm text-white/55">
										<Folder :size="iS(14)" />
										{{ _t("ui.map3d.categoryName", "Category name") }}
									</label>
									<input
										v-model="categoryName"
										type="text"
										maxlength="48"
										:placeholder="_t('ui.map3d.categoryPlaceholder', 'Garages')"
										class="map-bar mt-1.5 h-10 w-full rounded-sm px-3 text-sm text-white outline-none ring-1 ring-inset ring-white/15 placeholder:text-white/35 focus:ring-white/30" />
								</template>
								<label
									class="flex items-center gap-1.5 text-sm text-white/55"
									:class="isGlobalDraft && categoryPick === 'new' ? 'mt-4' : ''">
									<Type :size="iS(14)" />
									{{ _t("ui.map3d.blipName", "Blip Name") }}
								</label>
								<input
									ref="nameInput"
									v-model="blipLabel"
									type="text"
									maxlength="48"
									:placeholder="
										isGlobalDraft
											? _t('ui.map3d.pointPlaceholder', 'Legion Square')
											: _t('ui.map3d.blipPlaceholder', 'Meet point')
									"
									class="map-bar mt-1.5 h-10 w-full rounded-sm px-3 text-sm text-white outline-none ring-1 ring-inset ring-white/15 placeholder:text-white/35 focus:ring-white/30" />
								<div class="mt-4">
									<BlipPicker v-model="sprite" :colour="colourHex" />
								</div>
								<div class="mt-3">
									<BlipColourId v-model="blipColour" />
								</div>
								<div class="relative z-10 mt-3 border-t border-white/10 pt-3">
									<label
										class="map-bar flex cursor-pointer items-center justify-between gap-4 rounded-sm px-4 py-3 ring-1 ring-inset ring-white/15">
										<span class="flex items-center gap-2 text-sm font-medium text-white/90">
											<MapIcon :size="iS(16)" />
											{{ _t("ui.map3d.showOn2d", "Show on 2D Map") }}
										</span>
										<span
											class="grid h-5 w-5 shrink-0 place-items-center rounded-sm border transition-colors duration-150"
											:class="
												showOn2d
													? 'border-[#22c55e] bg-[#22c55e]'
													: 'border-white/35 bg-black/40'
											">
											<input v-model="showOn2d" type="checkbox" class="sr-only" />
											<Check v-if="showOn2d" :size="iS(12)" class="text-white" />
										</span>
									</label>
									<div
										class="overflow-hidden transition-[max-height,opacity] duration-300 ease-out"
										:class="showOn2d ? 'max-h-[48rem] opacity-100' : 'max-h-0 opacity-0'">
										<div class="mt-0.5 flex flex-col gap-0.5">
											<div class="map-bar relative z-0 rounded-sm px-4 py-3 ring-1 ring-inset ring-white/15">
												<div class="flex items-center justify-between gap-2 text-sm text-white/55">
													<span class="inline-flex items-center gap-1.5">
														<Scaling :size="iS(14)" />
														{{ _t("ui.map3d.blipScale", "Scale") }}
													</span>
													<span class="tabular-nums text-white/80">{{ blipScale.toFixed(1) }}</span>
												</div>
												<div
													class="relative mt-3 h-2 cursor-pointer rounded-full bg-white/15"
													@pointerdown="dragScale">
													<div
														class="absolute inset-y-0 left-0 rounded-full bg-[var(--panel-primary)]"
														:style="{ width: `${scalePct}%` }" />
													<span
														class="absolute top-1/2 h-4 w-4 -translate-x-1/2 -translate-y-1/2 rounded-sm bg-white ring-1 ring-black/20"
														:style="{ left: `${scalePct}%` }" />
												</div>
											</div>
											<label
												class="map-bar relative z-0 flex cursor-pointer items-center justify-between gap-3 rounded-sm px-4 py-3 ring-1 ring-inset ring-white/15">
												<span class="text-sm font-medium text-white/90">
													{{ _t("ui.map3d.shortRange", "Short range") }}
												</span>
												<span
													class="grid h-5 w-5 shrink-0 place-items-center rounded-sm border transition-colors duration-150"
													:class="
														shortRange
															? 'border-[#22c55e] bg-[#22c55e]'
															: 'border-white/35 bg-black/40'
													">
													<input v-model="shortRange" type="checkbox" class="sr-only" />
													<Check v-if="shortRange" :size="iS(12)" class="text-white" />
												</span>
											</label>
										</div>
									</div>
								</div>
							</template>
							<div class="mt-5 flex flex-nowrap items-center justify-end gap-2 border-t border-white/10 pt-4">
								<button type="button" :class="secondaryBtn" @click="cancelPlace">
									{{ _t("ui.map3d.cancel", "Cancel") }}
								</button>
								<button
									v-if="!isGlobalDraft || categoryPick !== null"
									type="button"
									:class="[primaryBtn, 'inline-flex items-center gap-1.5']"
									@click="confirmDraft">
									<MapPin :size="iS(16)" />
									{{ _t("ui.map3d.confirm", "Place") }}
								</button>
							</div>
						</div>
					</section>
				</div>
			</Transition>
		</Teleport>

		<MapBlipShareDialog
			v-model:target-id="targetId"
			:open="shareOpen"
			:panel-style="panelStyle"
			:primary-btn="primaryBtn"
			:secondary-btn="secondaryBtn"
			@close="closeShare"
			@send="sendShare" />
	</div>
</template>

<script setup lang="ts">
import {
	Check,
	ChevronDown,
	ChevronLeft,
	ChevronRight,
	Copy,
	Eye,
	EyeOff,
	Folder,
	Globe,
	Map as MapIcon,
	MapPin,
	MapPinned,
	Plus,
	Scaling,
	Share2,
	Trash2,
	Type,
	X,
} from "@lucide/vue";
const { panelStyle } = usePreferences();
const markers = useMarkersStore();
const { sheet, notice, noticeSerial, selected, points, groups, requests } = storeToRefs(markers);

const open = ref(true);
let noticeTimer = 0;
const collapsed = ref<Record<string, boolean>>({});
const hiddenRows = ref<Record<string, boolean>>({});
const cycle = ref<Record<string, number>>({});
const shareOpen = ref(false);
const targetId = ref("");
const blipLabel = ref("");
const categoryName = ref("");
const categoryPick = ref<null | string | "new">(null);
type CopyDraft = {
	category: string;
	label: string;
	sprite: string;
	blipColour: number;
	showOn2d: boolean;
	scale: number;
	shortRange: boolean;
};
const copyDraft = ref<CopyDraft | null>(null);
const nameInput = ref<HTMLInputElement | null>(null);
const sprite = ref("radar_level");
const showOn2d = ref(false);
const blipColour = ref(3);
const blipScale = ref(0.8);
const shortRange = ref(true);
const saving = ref(false);
const colourHex = computed(() => blipColourHex(blipColour.value));

const primaryBtn =
	"shrink-0 whitespace-nowrap bg-[var(--panel-primary)] px-3 py-2 text-sm text-[var(--panel-ink)] transition duration-150 active:scale-[0.98] disabled:opacity-40";
const secondaryBtn =
	"map-bar shrink-0 whitespace-nowrap px-3 py-2 text-sm ring-1 ring-inset ring-white/15 transition duration-150 active:scale-[0.98]";

const drafting = computed(() => Boolean(sheet.value.draft) && !copyDraft.value);
const isGlobalDraft = computed(() => sheet.value.placingMode === "global");
const scalePct = computed(() => ((blipScale.value - 0.1) / 3.9) * 100);
const playerCreator = computed(() => sheet.value.playerCreator !== false);
const showGlobalCreate = computed(() => sheet.value.adminCreator !== false && sheet.value.isAdmin === true);
const showCreateRow = computed(() => playerCreator.value || showGlobalCreate.value);
const globalCategories = computed(() =>
	Array.isArray(sheet.value.globalCategories) ? sheet.value.globalCategories : [],
);

const createFooterClass = computed(() =>
	playerCreator.value && showGlobalCreate.value ? "grid grid-cols-2 gap-0.5" : "grid grid-cols-1 gap-0.5",
);

const rowsIn = (groupId: string) => points.value.filter((point) => point.group === groupId);

const visibleGroups = computed(() => groups.value.filter((group) => rowsIn(group.id).length > 0 || group.id === "mine"));

const hasRows = computed(() => points.value.length > 0 || visibleGroups.value.length > 0);

const selectedPoint = computed(() => points.value.find((point) => point.id === selected.value) ?? null);

const canCopyGlobal = computed(
	() =>
		Boolean(
			selectedPoint.value?.global &&
				selectedPoint.value.db &&
				selectedPoint.value.category &&
				showGlobalCreate.value &&
				!sheet.value.placing &&
				!copyDraft.value,
		),
);

const detail = ref<(typeof points.value)[number] | null>(null);
const infoCard = ref<HTMLElement | null>(null);
const infoHeight = ref("0px");
const infoShown = ref(false);

watch(selectedPoint, async (point, previous) => {
	if (point) detail.value = point;
	const opening = Boolean(point) && !previous;
	if (opening) infoShown.value = false;
	await nextTick();
	infoHeight.value = point && infoCard.value ? `${infoCard.value.offsetHeight}px` : "0px";
	if (!opening) {
		infoShown.value = Boolean(point);
		return;
	}
	requestAnimationFrame(() => {
		infoShown.value = true;
	});
});

const showShare = computed(() => Boolean(selectedPoint.value?.owned && !sheet.value.placing));

const canSetWaypoint = computed(() => selectedPoint.value?.id !== "gps:waypoint");

const selectedFooterCount = computed(
	() => (canSetWaypoint.value ? 1 : 0) + (showShare.value ? 1 : 0) + (canCopyGlobal.value ? 1 : 0),
);

const selectedFooterClass = computed(() => {
	const count = selectedFooterCount.value;
	if (count >= 3) return "grid grid-cols-3 gap-0.5";
	if (count === 2) return "grid grid-cols-2 gap-0.5";
	return "grid grid-cols-1 gap-0.5";
});

const detailShares = computed(() => {
	const list = detail.value?.shares;
	if (!Array.isArray(list)) return [];
	return list.filter((person) => person && typeof person.name === "string" && person.name !== "");
});

const sharedWhen = (at?: number) => {
	if (!at) return "";
	const date = new Date(at * 1000);
	if (Number.isNaN(date.getTime())) return "";
	try {
		return date.toLocaleDateString(localeTag(), { day: "numeric", month: "short", year: "numeric" });
	} catch {
		return date.toLocaleDateString();
	}
};

const sharedLine = computed(() => {
	const point = detail.value;
	if (!point || point.group !== "shared") return "";
	const name = point.from?.trim() ?? "";
	const when = sharedWhen(point.sharedAt);
	if (name && when) return `${name} · ${when}`;
	return name || when;
});

const revokeShare = (identifier: string) => {
	if (!selectedPoint.value?.owned || !identifier) return;
	fetchNui("ThreeDMapUnshare", { id: selectedPoint.value.id, identifier }, "ok");
};

type Stack = { key: string; points: (typeof points.value)[number][] };

const stackKey = (groupId: string, point: (typeof points.value)[number]) =>
	[
		groupId,
		point.label,
		point.sprite,
		point.showOn2d === true ? "1" : "0",
		String(point.spriteId ?? ""),
		String(point.blipColour ?? ""),
		String(point.scale ?? ""),
		point.shortRange === false ? "0" : "1",
	].join("\0");

const stacksIn = (groupId: string): Stack[] => {
	const rows = rowsIn(groupId);
	if (groupId === "mine" || groupId === "shared") {
		return rows.map((point) => ({ key: point.id, points: [point] }));
	}
	const stacks = new Map<string, Stack>();
	for (const point of rows) {
		const key = stackKey(groupId, point);
		const stack = stacks.get(key);
		if (stack) stack.points.push(point);
		else stacks.set(key, { key, points: [point] });
	}
	return [...stacks.values()];
};

const indexOf = (stack: Stack) => {
	const index = cycle.value[stack.key] ?? 0;
	const count = stack.points.length;
	return ((index % count) + count) % count;
};

const current = (stack: Stack) => stack.points[indexOf(stack)]!;

const inStack = (stack: Stack) => Boolean(selected.value && stack.points.some((point) => point.id === selected.value));

const syncCycle = (id: string | null) => {
	if (!id) return;
	const point = points.value.find((entry) => entry.id === id);
	if (!point) return;
	for (const stack of stacksIn(point.group)) {
		const index = stack.points.findIndex((entry) => entry.id === id);
		if (index < 0) continue;
		cycle.value[stack.key] = index;
		return;
	}
};

const step = (stack: Stack, dir: number) => {
	cycle.value[stack.key] = indexOf(stack) + dir;
	focus(current(stack).id);
};

const focus = (id: string) => {
	markers.select(id);
	fetchNui("ThreeDMapFocus", { id }, "ok");
};

const waypointAck = ref<string | null>(null);
let waypointTimer = 0;

const clearWaypointAck = () => {
	window.clearTimeout(waypointTimer);
	waypointAck.value = null;
};

const waypointShown = computed(() =>
	Boolean(selectedPoint.value && waypointAck.value === selectedPoint.value.id && !sheet.value.placing),
);

const setWaypoint = (pointId?: string) => {
	const id = typeof pointId === "string" ? pointId : selectedPoint.value?.id;
	if (!id) return;
	if (typeof pointId === "string") markers.select(pointId);
	fetchNui("ThreeDMapWaypoint", { id }, "ok");
	waypointAck.value = id;
	window.clearTimeout(waypointTimer);
	waypointTimer = window.setTimeout(() => {
		if (waypointAck.value === id) waypointAck.value = null;
	}, 1400);
};

const beginPlace = (mode: "personal" | "global") => {
	shareOpen.value = false;
	copyDraft.value = null;
	fetchNui("ThreeDMapBegin", { mode }, "ok");
};

const beginCopy = () => {
	const point = selectedPoint.value;
	if (!point?.db || !point.category || !point.label) return;
	shareOpen.value = false;
	copyDraft.value = {
		category: point.category,
		label: point.label,
		sprite: point.sprite,
		blipColour: point.blipColour ?? 3,
		showOn2d: point.showOn2d === true,
		scale: point.scale ?? 0.8,
		shortRange: point.shortRange !== false,
	};
	fetchNui("ThreeDMapBegin", { mode: "global" }, "ok");
};

const cancelPlace = () => {
	copyDraft.value = null;
	fetchNui("ThreeDMapCancel", {}, "ok");
};

const deletePoint = () => {
	if (!selectedPoint.value?.canDelete) return;
	fetchNui("ThreeDMapDelete", { id: selectedPoint.value.id }, "ok");
};

const resetDraftForm = () => {
	blipLabel.value = "";
	categoryName.value = "";
	categoryPick.value = null;
	sprite.value = "radar_level";
	showOn2d.value = false;
	blipColour.value = 3;
	blipScale.value = 0.8;
	shortRange.value = true;
	saving.value = false;
};

const draftFields = () => ({
	label: blipLabel.value.trim(),
	sprite: sprite.value,
	blipColour: blipColour.value,
	showOn2d: showOn2d.value,
	scale: blipScale.value,
	shortRange: shortRange.value,
});

const dragScale = (event: PointerEvent) => {
	const target = event.currentTarget as HTMLElement;
	target.setPointerCapture(event.pointerId);
	const apply = (clientX: number) => {
		const rect = target.getBoundingClientRect();
		const ratio = rect.width <= 0 ? 0 : Math.min(1, Math.max(0, (clientX - rect.left) / rect.width));
		blipScale.value = Math.round((0.1 + ratio * 3.9) * 10) / 10;
	};
	apply(event.clientX);
	const onMove = (next: PointerEvent) => apply(next.clientX);
	const stop = () => {
		target.removeEventListener("pointermove", onMove);
		target.removeEventListener("pointerup", stop);
	};
	target.addEventListener("pointermove", onMove);
	target.addEventListener("pointerup", stop);
};

const confirmDraft = () => {
	if (saving.value) return;
	const fields = draftFields();
	if (!fields.label) {
		nameInput.value?.focus();
		return;
	}
	if (isGlobalDraft.value) {
		const category =
			categoryPick.value === "new"
				? categoryName.value.trim()
				: typeof categoryPick.value === "string"
					? categoryPick.value
					: "";
		if (!category) return;
		saving.value = true;
		markers.clearNotice();
		fetchNui("ThreeDMapCreateGlobal", buildGlobalBlipPayload({ category, ...fields }), "ok");
		return;
	}
	saving.value = true;
	markers.clearNotice();
	fetchNui("ThreeDMapCreate", buildBlipPayload(fields), "ok");
};

const openShare = () => {
	if (!selectedPoint.value?.owned) return;
	shareOpen.value = true;
	targetId.value = "";
};

const closeShare = () => {
	shareOpen.value = false;
	targetId.value = "";
};

const sendShare = () => {
	if (!selectedPoint.value) return;
	const target = Number.parseInt(targetId.value, 10);
	if (!Number.isInteger(target) || target < 1) return;
	fetchNui("ThreeDMapShare", { id: selectedPoint.value.id, target }, "ok");
	closeShare();
};

const onEscape = (event: KeyboardEvent) => {
	if (event.key !== "Escape" || !shareOpen.value) return;
	closeShare();
	event.stopImmediatePropagation();
};

const toggleHidden = (stack: Stack) => {
	const hidden = !hiddenRows.value[stack.key];
	hiddenRows.value[stack.key] = hidden;
	for (const point of stack.points) {
		hiddenRows.value[point.id] = hidden;
		fetchNui("ThreeDMapHide", { id: point.id, row: true, hidden }, "ok");
	}
};

onMounted(() => window.addEventListener("keydown", onEscape, true));
onUnmounted(() => {
	window.removeEventListener("keydown", onEscape, true);
	clearWaypointAck();
});

watch(selected, (id) => {
	shareOpen.value = false;
	clearWaypointAck();
	syncCycle(id);
});

watch(
	() => sheet.value.placing,
	(placing) => {
		if (placing) clearWaypointAck();
	},
);

watch(points, (next) => {
	markers.deselectIfMissing(next.map((point) => point.id));
});

// Watch the serial too: the same notice twice in a row (e.g. two cooldown errors) must still unlock the form.
watch([notice, noticeSerial], ([text]) => {
	window.clearTimeout(noticeTimer);
	if (text) {
		saving.value = false;
		if (copyDraft.value) {
			copyDraft.value = null;
			fetchNui("ThreeDMapCancel", {}, "ok");
		}
	}
	if (!text) return;
	noticeTimer = window.setTimeout(() => {
		markers.clearNotice();
	}, 2800);
});

watch(
	() => sheet.value.draft,
	(draft, previous) => {
		if (draft && !previous && copyDraft.value) {
			const copy = copyDraft.value;
			saving.value = true;
			markers.clearNotice();
			fetchNui("ThreeDMapCreateGlobal", buildGlobalBlipPayload(copy), "ok");
			return;
		}
		if (draft && !previous) resetDraftForm();
		if (!draft && previous) {
			copyDraft.value = null;
			resetDraftForm();
		}
	},
);
</script>
