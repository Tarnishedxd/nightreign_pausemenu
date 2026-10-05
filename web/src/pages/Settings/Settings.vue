<template>
	<div class="flex h-full min-h-0 flex-col px-14 py-7 text-white bg-black/75" :style="panelStyle">
		<header class="flex shrink-0 items-center justify-between gap-4 border-b border-white/10 pb-5">
			<div class="flex min-w-0 items-center gap-3">
				<BrandLogo class="h-8 w-auto shrink-0" />
				<h1 class="min-w-0 truncate text-2xl font-semibold tracking-tight">{{ _t("ui.pause.settings", "Settings") }}</h1>
			</div>
			<div v-if="settings.vram && settings.vramPercent >= 0" class="flex shrink-0 items-center gap-2">
				<div class="h-1.5 w-28 overflow-hidden rounded-md bg-white/15" :aria-label="`${settings.vramPercent}%`">
					<div
						class="h-full rounded-md bg-[var(--panel-primary)] transition-[width] duration-200"
						:style="{ width: `${Math.min(100, Math.max(0, settings.vramPercent))}%` }" />
				</div>
				<span class="text-sm text-white/75">{{ settings.vram }}</span>
				<span class="text-sm tabular-nums text-white/50">{{ settings.vramPercent }}%</span>
			</div>
		</header>

		<div
			class="grid min-h-0 flex-1 pt-6"
			:class="
				settings.keyBindings && view === 'settings'
					? 'grid-cols-[17rem_16rem_minmax(0,1fr)]'
					: 'grid-cols-[17rem_minmax(0,1fr)]'
			">
			<aside
				class="min-h-0 overflow-y-auto border-r border-white/15 pr-5 [scrollbar-color:rgb(255_255_255/0.22)_transparent] [scrollbar-width:thin] [&::-webkit-scrollbar-thumb]:rounded-full [&::-webkit-scrollbar-thumb]:bg-white/20 [&::-webkit-scrollbar]:w-1.5">
				<Transition
					appear
					mode="out-in"
					enter-active-class="transition duration-300 ease-out"
					enter-from-class="translate-y-2 opacity-0"
					enter-to-class="translate-y-0 opacity-100"
					leave-active-class="transition duration-150 ease-in"
					leave-from-class="opacity-100"
					leave-to-class="opacity-0">
					<div v-if="!settings.categories.length" key="category-skeleton" class="flex flex-col gap-2">
						<div
							v-for="(width, index) in categorySkeletonWidths"
							:key="index"
							class="flex items-center gap-2.5 rounded-md px-3 py-2.5"
							:class="index === 0 ? 'bg-[var(--panel-primary)]' : ''">
							<div
								class="size-[18px] shrink-0 animate-pulse rounded"
								:class="index === 0 ? 'bg-black/75' : 'bg-white/20'" />
							<div
								class="h-6 animate-pulse rounded"
								:class="index === 0 ? 'bg-black/75' : 'bg-white/20'"
								:style="{ width: `${width}%` }" />
						</div>
					</div>
					<div v-else key="categories">
						<div class="flex flex-col gap-2">
							<button
								v-for="(category, index) in settings.categories"
								:key="category.id"
								type="button"
								class="flex items-center gap-2.5 rounded-md px-3 py-2.5 text-left text-base font-medium transition-colors duration-200"
								:class="categoryClass(category.id, index)"
								@click="onCategoryClick(category.id, index)">
								<component :is="categoryIcon(category.index)" :size="iS(18)" class="shrink-0 opacity-80" />
								<span class="min-w-0 flex-1 truncate">{{ categoryLabel(category) }}</span>
								<span v-if="category.pending" class="text-sm text-amber-200">{{ category.pending }}</span>
							</button>
						</div>
						<div class="mx-3 my-4 border-t border-white/15" />
						<button
							type="button"
							class="flex w-full items-center gap-2.5 rounded-md px-3 py-2.5 text-left text-base font-medium transition-colors duration-200"
							:class="categoryClass(editIntent, settings.categories.length)"
							@click="onCategoryClick(editIntent, settings.categories.length)">
							<Paintbrush :size="iS(18)" class="shrink-0 opacity-80" />
							{{ _t("ui.settings.preferences.title", "Preferences") }}
						</button>
						<button
							type="button"
							class="mt-2 flex w-full items-center gap-2.5 rounded-md px-3 py-2.5 text-left text-base font-medium transition-colors duration-200"
							:class="categoryClass(regularMenuIntent, settings.categories.length + 1)"
							@click="onCategoryClick(regularMenuIntent, settings.categories.length + 1)">
							<Menu :size="iS(18)" class="shrink-0 opacity-80" />
							{{ _t("ui.settings.regularMenu", "Regular Menu") }}
						</button>
					</div>
				</Transition>
			</aside>

			<aside
				v-if="settings.keyBindings && view === 'settings'"
				class="min-h-0 overflow-y-auto border-r border-white/15 px-5 [scrollbar-color:rgb(255_255_255/0.22)_transparent] [scrollbar-width:thin] [&::-webkit-scrollbar-thumb]:rounded-full [&::-webkit-scrollbar-thumb]:bg-white/20 [&::-webkit-scrollbar]:w-1.5">
				<Transition
					appear
					mode="out-in"
					enter-active-class="transition duration-300 ease-out"
					enter-from-class="translate-y-2 opacity-0"
					enter-to-class="translate-y-0 opacity-100"
					leave-active-class="transition duration-150 ease-in"
					leave-from-class="opacity-100"
					leave-to-class="opacity-0">
					<div v-if="settings.keyGroups.length < 2" key="group-skeleton" class="flex flex-col gap-2">
						<div
							v-for="(width, index) in keyGroupSkeletonWidths"
							:key="index"
							class="flex items-center rounded-md px-3 py-2.5"
							:class="index === 0 ? 'bg-[var(--panel-primary)]' : ''">
							<div
								class="h-6 animate-pulse rounded"
								:class="index === 0 ? 'bg-black/75' : 'bg-white/20'"
								:style="{ width: `${width}%` }" />
						</div>
					</div>
					<div v-else key="groups" class="flex flex-col gap-2">
						<button
							v-for="(group, index) in settings.keyGroups"
							:key="group.id"
							:data-group="group.id"
							type="button"
							class="flex w-full items-center rounded-md px-3 py-2.5 text-left text-base font-medium transition-colors duration-200"
							:class="groupClass(group.id, index)"
							@click="onGroupClick(group.id, index)">
							<span class="min-w-0 flex-1 truncate">{{ sharedLabel(group.label, categoryIndex()) }}</span>
						</button>
					</div>
				</Transition>
			</aside>

			<main class="flex min-h-0 min-w-0 flex-col pl-6">
				<div class="mb-3 flex shrink-0 items-center gap-3">
					<p class="min-w-0 flex-1 truncate text-lg font-semibold">
						{{ pageTitle() }}
					</p>
					<input
						v-if="view === 'settings'"
						v-model.trim="query"
						type="text"
						:placeholder="_t('ui.settings.search', 'Search')"
						class="w-72 rounded-md border border-white/10 bg-white/10 px-3 py-2 text-base text-white shadow-[inset_0_0_6px_rgb(255_255_255/0.04)] outline-none transition-colors duration-200 placeholder:text-white/35 focus:border-white/30" />
				</div>
				<p v-if="settings.keyBindings && view === 'settings'" class="mb-3 text-sm text-white/45">
					{{
						_t(
							"ui.settings.keys.secondaryNote",
							"Secondary actions cannot be changed here. Use the vanilla pause menu to change them.",
						)
					}}
				</p>
				<Transition
					mode="out-in"
					enter-active-class="transition duration-300 ease-out"
					enter-from-class="translate-y-2 opacity-0"
					enter-to-class="translate-y-0 opacity-100"
					leave-active-class="transition duration-150 ease-in"
					leave-from-class="opacity-100"
					leave-to-class="opacity-0">
					<div v-if="holdReveal || loadingRows()" key="skeleton" class="flex flex-col gap-2 pr-3">
						<template v-if="settings.keyBindings">
							<article
								v-for="(row, index) in keySkeletonRows"
								:key="index"
								class="grid grid-cols-[7fr_1.5fr] items-center gap-3 rounded-md border border-[color:var(--panel-row-border)] bg-[var(--panel-row-bg)] px-4 py-3 shadow-[var(--panel-row-shadow)]">
								<div class="min-w-0">
									<div class="h-4 animate-pulse rounded bg-white/25" :style="{ width: `${row.label}%` }" />
									<div v-if="row.badge" class="mt-2 h-3 w-14 animate-pulse rounded bg-amber-200/25" />
								</div>
								<div class="grid place-items-center">
									<div class="h-7 w-7 animate-pulse rounded-md border border-white/10 bg-white/15" />
								</div>
							</article>
						</template>
						<article
							v-for="(row, index) in settingSkeletonRows"
							v-else
							:key="index"
							class="rounded-md border border-[color:var(--panel-row-border)] bg-[var(--panel-row-bg)] px-4 py-3 shadow-[var(--panel-row-shadow)]">
							<div class="flex min-h-11 items-center gap-4">
								<div class="min-w-0 flex-1">
									<div class="h-4 animate-pulse rounded bg-white/25" :style="{ width: `${row.label}%` }" />
								</div>
								<div v-if="row.kind === 'slider'" class="flex w-[24rem] items-center gap-2">
									<div class="h-8 w-8 animate-pulse rounded-md bg-white/15" />
									<div class="h-2 flex-1 overflow-hidden rounded-md bg-white/15">
										<div class="h-full animate-pulse rounded-md bg-white/35" :style="{ width: `${row.fill}%` }" />
									</div>
									<div class="h-8 w-8 animate-pulse rounded-md bg-white/15" />
									<div class="h-4 w-8 animate-pulse rounded bg-white/20" />
								</div>
								<div v-else-if="row.kind === 'options'" class="flex items-center gap-1">
									<div class="h-8 w-8 animate-pulse rounded-md bg-white/15" />
									<div class="h-4 w-28 animate-pulse rounded bg-white/20" />
									<div class="h-8 w-8 animate-pulse rounded-md bg-white/15" />
								</div>
								<div v-else class="h-4 w-24 animate-pulse rounded bg-white/15" />
							</div>
						</article>
					</div>
					<div
						v-else-if="settings.status === 'error'"
						key="error"
						class="rounded-md border border-red-400/30 bg-red-400/10 px-4 py-3">
						<p class="text-base text-red-200">{{ settings.error }}</p>
					</div>
					<div v-else-if="view === 'preferences'" key="preferences" class="flex min-h-0 flex-1 flex-col">
						<Preferences ref="editPane" :focus-id="view === 'preferences' && focusZone === 'rows' ? selectedId : ''" />
					</div>
					<div v-else-if="!listedRows.length" key="empty" class="grid flex-1 place-items-center">
						<p class="text-base text-white/55">{{ _t("ui.settings.empty", "No matching settings") }}</p>
					</div>
					<div
						v-else-if="settings.keyBindings"
						key="keys"
						class="min-h-0 flex-1 overflow-y-auto pr-3 [scrollbar-color:rgb(255_255_255/0.22)_transparent] [scrollbar-width:thin] [&::-webkit-scrollbar-thumb]:rounded-full [&::-webkit-scrollbar-thumb]:bg-white/20 [&::-webkit-scrollbar]:w-1.5">
						<div class="mb-2 grid grid-cols-[7fr_1.5fr] items-center gap-3 px-4 text-sm text-white/40">
							<span>{{ _t("ui.settings.keys.action", "Action") }}</span>
							<span class="text-center">{{ _t("ui.settings.keys.primary", "Primary") }}</span>
						</div>
						<div class="flex flex-col gap-2">
							<article
								v-for="row in keyBindingRows()"
								:key="row.id"
								:data-focus="row.id"
								class="grid grid-cols-[7fr_1.5fr] items-center gap-3 rounded-md border border-[color:var(--panel-row-border)] bg-[var(--panel-row-bg)] px-4 py-3 shadow-[var(--panel-row-shadow)] transition-colors duration-200"
								:class="rowFocusClass(row.id)"
								@click="focusRow(row.id)">
								<div class="min-w-0">
									<p class="truncate text-base text-white/85">{{ row.action }}</p>
									<span
										v-if="row.resource"
										class="mt-1 block w-fit max-w-full truncate rounded bg-amber-300/20 px-1.5 py-0.5 text-[10px] font-medium leading-none text-amber-200">
										{{ row.resource }}
									</span>
								</div>
								<button
									type="button"
									class="justify-self-center whitespace-nowrap text-sm transition-colors duration-200"
									:class="slotVisual(row)"
									:disabled="!row.editable || settings.busy"
									@click.stop="startListen(row)">
									{{ slotLabel(row) }}
								</button>
							</article>
						</div>
					</div>
					<div
						v-else
						:key="settings.activeCategoryId"
						class="flex min-h-0 flex-1 flex-col gap-2 overflow-y-auto pr-3 [scrollbar-color:rgb(255_255_255/0.22)_transparent] [scrollbar-width:thin] [&::-webkit-scrollbar-thumb]:rounded-full [&::-webkit-scrollbar-thumb]:bg-white/20 [&::-webkit-scrollbar]:w-1.5">
						<template v-for="row in gameSettingRows()" :key="row.id">
							<div v-if="row.kind === 'info'" class="py-5 text-center text-base text-white/70">
								{{ settingLabel(row) }}
							</div>
							<div v-else-if="row.kind === 'spacer'" class="h-6 shrink-0" aria-hidden="true" />
							<article
								v-else
								:data-focus="row.id"
								class="rounded-md border border-[color:var(--panel-row-border)] bg-[var(--panel-row-bg)] px-4 py-3 shadow-[var(--panel-row-shadow)] transition-colors duration-200"
								:class="rowFocusClass(row.id)"
								@click="focusRow(row.id)">
								<div class="flex min-h-11 items-center gap-4">
									<p
										class="min-w-0 flex-1 truncate text-base"
										:class="row.kind === 'locked' || !row.editable ? 'text-white/45' : 'text-white/90'">
										{{ settingLabel(row) }}
									</p>
									<span v-if="row.kind === 'locked'" class="flex items-center gap-1.5 text-base text-white/60">
										<Lock :size="iS(16)" />
										{{ _t("ui.settings.locked", "Locked") }}
									</span>
									<button
										v-else-if="row.kind === 'button'"
										type="button"
										class="rounded-md border border-white/10 bg-white/10 px-3 py-1.5 text-base text-white/80 shadow-[inset_0_0_6px_rgb(255_255_255/0.04)] transition-colors duration-200 hover:bg-white/15 disabled:opacity-40"
										:disabled="settings.busy || !row.editable"
										@click.stop="activate(row)">
										{{ _t("ui.settings.activate", "Activate") }}
									</button>
									<div v-else-if="row.kind === 'slider'" class="flex w-[24rem] items-center gap-2">
										<button
											type="button"
											class="grid h-8 w-8 place-items-center rounded-md border border-white/10 bg-white/10 text-white/80 shadow-[inset_0_0_6px_rgb(255_255_255/0.04)] transition duration-150 hover:bg-white/20 hover:text-white active:scale-[0.98] disabled:opacity-40"
											:disabled="settings.busy || !row.editable"
											@click.stop="
												focusRow(row.id);
												change(row, -1);
											">
											<ChevronLeft :size="iS(16)" />
										</button>
										<div
											class="h-2 flex-1 cursor-pointer overflow-hidden rounded-md bg-white/15"
											role="slider"
											tabindex="0"
											:aria-label="settingLabel(row)"
											:aria-valuemin="0"
											:aria-valuemax="row.maxIndex"
											:aria-valuenow="row.selectedIndex"
											:class="settings.busy || !row.editable ? 'pointer-events-none opacity-40' : ''"
											@click.stop="
												focusRow(row.id);
												onSliderClick($event, row);
											"
											@keydown.stop.prevent.left="change(row, -1)"
											@keydown.stop.prevent.right="change(row, 1)">
											<div
												class="h-full rounded-md bg-[var(--panel-primary)] transition-[width] duration-200"
												:style="{ width: sliderWidth(row) }" />
										</div>
										<div class="flex items-center gap-1">
											<button
												type="button"
												class="grid h-8 w-8 place-items-center rounded-md border border-white/10 bg-white/10 text-white/80 shadow-[inset_0_0_6px_rgb(255_255_255/0.04)] transition duration-150 hover:bg-white/20 hover:text-white active:scale-[0.98] disabled:opacity-40"
												:disabled="settings.busy || !row.editable"
												@click.stop="
													focusRow(row.id);
													change(row, 1);
												">
												<ChevronRight :size="iS(16)" />
											</button>
											<span class="w-8 text-right text-sm tabular-nums text-white/75">{{
												displayValue(row)
											}}</span>
										</div>
									</div>
									<div v-else-if="row.kind === 'options' || row.kind === 'cycled'" class="flex items-center gap-1">
										<button
											type="button"
											class="grid h-8 w-8 place-items-center rounded-md border border-white/10 bg-white/10 text-white/80 shadow-[inset_0_0_6px_rgb(255_255_255/0.04)] transition duration-150 hover:bg-white/20 hover:text-white active:scale-[0.98] disabled:opacity-40"
											:disabled="settings.busy || !row.editable"
											@click.stop="
												focusRow(row.id);
												change(row, -1);
											">
											<ChevronLeft :size="iS(16)" />
										</button>
										<button
											type="button"
											class="min-w-36 max-w-80 truncate px-2 text-center text-base text-white/85 transition duration-150 active:scale-[0.98] disabled:opacity-40"
											:disabled="settings.busy || !row.editable"
											@click.stop="
												focusRow(row.id);
												change(row, 1);
											">
											{{ displayValue(row) }}
										</button>
										<button
											type="button"
											class="grid h-8 w-8 place-items-center rounded-md border border-white/10 bg-white/10 text-white/80 shadow-[inset_0_0_6px_rgb(255_255_255/0.04)] transition duration-150 hover:bg-white/20 hover:text-white active:scale-[0.98] disabled:opacity-40"
											:disabled="settings.busy || !row.editable"
											@click.stop="
												focusRow(row.id);
												change(row, 1);
											">
											<ChevronRight :size="iS(16)" />
										</button>
									</div>
									<span v-else-if="row.value" class="max-w-64 truncate text-base text-white/60">{{
										sharedLabel(row.value, categoryIndex())
									}}</span>
								</div>
								<div v-if="selectedId === row.id && row.kind === 'options'" class="flex flex-wrap gap-1.5 pt-3">
									<button
										v-for="(choice, choiceIndex) in row.choices"
										:key="`${row.id}:${choiceIndex}`"
										type="button"
										class="rounded-md border border-white/10 px-3 py-1.5 text-sm shadow-[inset_0_0_6px_rgb(255_255_255/0.04)] transition-colors duration-200"
										:class="
											(row.value ? choice === row.value : choiceIndex === row.selectedIndex)
												? 'bg-[var(--panel-primary)] text-[var(--panel-ink)]'
												: 'bg-white/10 text-white/70 hover:bg-white/15 hover:text-white'
										"
										:disabled="settings.busy || !row.editable"
										@click.stop="
											focusRow(row.id);
											setValue(row, choiceIndex);
										">
										{{ choiceLabel(row, choiceIndex) }}
									</button>
								</div>
							</article>
						</template>
					</div>
				</Transition>
			</main>
		</div>

		<footer class="mt-5 flex shrink-0 items-center justify-end gap-3 border-t border-white/10 pt-4">
			<span v-for="hint in keyHints" :key="hint.locale" class="flex items-center gap-1.5 text-sm text-white/70">
				<span
					class="grid min-h-7 min-w-7 place-items-center rounded-md border border-white/10 bg-white/10 px-2 py-1 font-medium tracking-wide text-white shadow-[inset_0_0_6px_rgb(255_255_255/0.04)]">
					<component :is="hint.icon" v-if="hint.icon" :size="iS(16)" />
					<template v-else>{{ hint.key }}</template>
				</span>
				{{ hint.label }}
			</span>
			<span v-if="settings.pendingCount" class="h-5 w-px bg-white/20" aria-hidden="true" />
			<button
				v-if="settings.pendingCount"
				type="button"
				class="rounded-md bg-[var(--panel-primary)] px-3 py-1.5 text-base text-[var(--panel-ink)] transition-colors duration-200 disabled:opacity-40"
				:disabled="settings.busy"
				@click="applyChanges">
				{{ _t("ui.settings.apply", "Apply Changes") }}
			</button>
		</footer>

		<Transition
			enter-active-class="transition duration-200 ease-out"
			enter-from-class="opacity-0"
			enter-to-class="opacity-100"
			leave-active-class="transition duration-200 ease-in"
			leave-from-class="opacity-100"
			leave-to-class="opacity-0">
			<div v-if="langOpen" class="fixed inset-0 z-40 grid place-items-center bg-black/40 px-6">
				<section
					class="w-full max-w-xl rounded-md border border-white/10 bg-white/10 px-5 py-5 shadow-[inset_0_0_6px_rgb(255_255_255/0.04)]"
					role="dialog"
					aria-modal="true">
					<p class="text-base leading-6 text-white/75">
						{{
							_t(
								"ui.settings.expWarning.text",
								"Experimental translation is on, but the game language is not English. Switch the game to English so the setting names stay accurate.",
							)
						}}
					</p>
					<label class="mt-4 flex cursor-pointer items-center gap-3 text-base text-white/80">
						<input v-model="hideLangAgain" type="checkbox" class="peer sr-only" />
						<span
							class="grid h-8 w-8 shrink-0 place-items-center rounded-md border border-white/10 bg-white/10 text-transparent shadow-[inset_0_0_6px_rgb(255_255_255/0.04)] transition-colors duration-200 peer-checked:bg-[var(--panel-primary)] peer-checked:text-[var(--panel-ink)] peer-focus-visible:outline peer-focus-visible:outline-2 peer-focus-visible:outline-offset-2 peer-focus-visible:outline-white/40">
							<Check :size="iS(16)" />
						</span>
						{{ _t("ui.settings.expWarning.dismiss", "Do not show again") }}
					</label>
					<div class="mt-5 flex flex-nowrap items-center justify-end gap-2">
						<button
							type="button"
							class="shrink-0 whitespace-nowrap rounded-md border border-white/10 bg-white/10 px-3 py-1.5 text-base text-white/75 transition-colors duration-200 hover:bg-white/15"
							@click="closeLangWarning">
							{{ _t("ui.settings.expWarning.close", "Close") }}
						</button>
						<button
							type="button"
							class="shrink-0 whitespace-nowrap rounded-md border border-white/10 bg-white/10 px-3 py-1.5 text-base text-white/75 transition-colors duration-200 hover:bg-white/15"
							@click="disableExperimental">
							{{ _t("ui.settings.expWarning.disable", "Disable") }}
						</button>
						<button
							type="button"
							class="shrink-0 whitespace-nowrap rounded-md bg-[var(--panel-primary)] px-3 py-1.5 text-base text-[var(--panel-ink)] transition-colors duration-200 disabled:opacity-40"
							:disabled="settings.busy"
							@click="useEnglish">
							{{ _t("ui.settings.expWarning.english", "Switch to English") }}
						</button>
					</div>
				</section>
			</div>
		</Transition>
	</div>
</template>

<script setup lang="ts">
import {
	Camera,
	Clapperboard,
	ArrowUpDown,
	Gamepad2,
	Keyboard,
	Lock,
	Menu,
	Mic,
	Monitor,
	Mouse,
	Paintbrush,
	Save,
	Sparkles,
	Sun,
	Volume2,
	ArrowLeftRight,
	Check,
	ChevronLeft,
	ChevronRight,
} from "@lucide/vue";

// page
const settingsStore = useSettingsStore();
const { settings, alert } = storeToRefs(settingsStore);
const { panelStyle, experimentalLabels } = usePreferences();
const { categoryLabel, settingLabel: labelFor, choiceLabel: choiceFor, sharedLabel } = useExperimental();
const categoryIndex = () => activeCategory()?.index ?? -1;
const settingLabel = (row: GameSettingRow) => labelFor(categoryIndex(), row);
const choiceLabel = (row: GameSettingRow, index: number) => choiceFor(categoryIndex(), row, index);
const view = ref<"settings" | "preferences">("settings");
const focusZone = ref<"categories" | "groups" | "rows">("categories");
const categoryCursor = ref(0);
const groupCursor = ref(0);
const selectedId = ref("");
const editIntent = "__edit";
const regularMenuIntent = "__regular";
const editPane = ref<{ nudge: (direction: number) => void; activate: () => void } | null>(null);
const customizeOrder = ["color", "labels", "darkMode", "portrait", "return3dAnim", "reset"];
const keyHints = computed<{ icon?: Component; key?: string; locale: string; label: string }[]>(() => [
	{ icon: ArrowUpDown, locale: "move", label: _t("ui.settings.move", "Move") },
	{ icon: ArrowLeftRight, locale: "change", label: _t("ui.settings.change", "Change") },
	{ key: "ENTER", locale: "select", label: _t("ui.settings.select", "Select") },
	{ key: "BACK", locale: "categories", label: _t("ui.settings.categories", "Categories") },
	{ key: "ESC", locale: "close", label: _t("ui.settings.close", "Close") },
]);

const pageTitle = () => {
	if (view.value === "preferences") return _t("ui.settings.preferences.title", "Preferences");
	const category = activeCategory();
	return category ? categoryLabel(category) : _t("ui.settings.loading", "Loading settings");
};

// rows
const query = ref("");
const filteredRows = computed(() => {
	const search = query.value.toLocaleLowerCase();
	if (!search) return settings.value.rows;
	return settings.value.rows.filter((row) => {
		if (row.type === "keybind") {
			return `${row.action} ${row.resource} ${row.primary}`.toLocaleLowerCase().includes(search);
		}
		return `${settingLabel(row)} ${displayValue(row)} ${row.choices.map((_, choiceIndex) => choiceLabel(row, choiceIndex)).join(" ")}`
			.toLocaleLowerCase()
			.includes(search);
	});
});
const activeKeyGroupId = computed(() => settings.value.activeKeyGroupId || settings.value.keyGroups[0]?.id || "");
const listedRows = computed(() => {
	if (!settings.value.keyBindings) return filteredRows.value;
	const groupId = activeKeyGroupId.value;
	const keyed = filteredRows.value.filter((row): row is KeyBindingRow => row.type === "keybind");
	const matched = keyed.filter((row) => row.groupId === groupId);
	return matched.length ? matched : keyed;
});
const gameSettingRows = () => filteredRows.value.filter((row): row is GameSettingRow => row.type === "setting");
const keyBindingRows = () => listedRows.value.filter((row): row is KeyBindingRow => row.type === "keybind");
const selectedRow = () => listedRows.value.find((row) => row.id === selectedId.value);
const isNavigable = (row: SettingsRow) => {
	if (row.type === "keybind") return true;
	return row.kind === "slider" || row.kind === "options" || row.kind === "cycled" || row.kind === "button" || row.kind === "locked";
};
const navigableRows = () => (settings.value.keyBindings ? listedRows.value : filteredRows.value).filter(isNavigable);
const firstNavigableId = () => navigableRows()[0]?.id ?? "";

// categories
const categorySkeletonWidths = [72, 54, 84, 48, 66, 78, 42, 60, 88, 56, 70];
const keyGroupSkeletonWidths = [68, 54, 76, 48, 82, 60, 44, 70, 58, 86, 50, 64, 72];
const activeCategory = () => settings.value.categories.find((category) => category.id === settings.value.activeCategoryId);
const categoryIcons: Component[] = [Gamepad2, Mouse, Keyboard, Volume2, Camera, Sun, Monitor, Sparkles, Mic, Clapperboard, Save];

const categoryIcon = (index: number) => categoryIcons[index] ?? Sparkles;

const groupClass = (id: string, index: number) => {
	const open = id === activeKeyGroupId.value;
	const cursor = focusZone.value === "groups" && groupCursor.value === index;
	if (open) return "bg-[var(--panel-primary)] text-[var(--panel-ink)]";
	if (cursor) return "bg-white/15 text-white";
	return "text-white/55 hover:bg-white/10 hover:text-white/85";
};

const isKeyGroupAction = (group: { button?: boolean; label?: string } | undefined, index: number) => {
	if (!group) return false;
	if (group.button) return true;
	const label = (group.label || "").toLowerCase();
	if (label.includes("restore") && label.includes("default")) return true;
	return index > 0 && index === settings.value.keyGroups.length - 1;
};

const onGroupClick = (id: string, index: number) => {
	focusZone.value = "groups";
	groupCursor.value = index;
	const group = settings.value.keyGroups[index];
	if (isKeyGroupAction(group, index)) {
		void fetchNui("SettingsActivateKey", { id }, { ok: false });
		return;
	}
	void fetchNui("SettingsSetKeyGroup", { id }, { ok: false });
};

const categoryClass = (id: string, index: number) => {
	const open =
		id === editIntent ? view.value === "preferences" : view.value === "settings" && id === settings.value.activeCategoryId;
	const cursor = focusZone.value === "categories" && settings.value.activeCategoryId !== "" && categoryCursor.value === index;
	if (open) return "bg-[var(--panel-primary)] text-[var(--panel-ink)]";
	if (cursor) return "bg-white/15 text-white";
	return "text-white/55 hover:bg-white/10 hover:text-white/85";
};

const rowFocusClass = (id: string) =>
	focusZone.value === "rows" && selectedId.value === id ? "!bg-[var(--panel-row-bg-focus)]" : "hover:bg-[var(--panel-row-bg-hover)]";

// skeleton
const keySkeletonRows: { label: number; badge?: boolean }[] = [
	{ label: 38 },
	{ label: 52 },
	{ label: 44, badge: true },
	{ label: 61 },
	{ label: 33 },
	{ label: 48 },
	{ label: 56, badge: true },
];
const settingSkeletonRows: { kind: "options" | "slider" | "value"; label: number; fill?: number }[] = [
	{ kind: "options", label: 42 },
	{ kind: "slider", label: 58, fill: 36 },
	{ kind: "options", label: 34 },
	{ kind: "value", label: 66 },
	{ kind: "slider", label: 48, fill: 72 },
	{ kind: "options", label: 54 },
	{ kind: "value", label: 38 },
];
const holdReveal = ref(false);
let revealTimer = 0;
let revealToken = 0;
let revealStarted = 0;
const loadingRows = () => view.value !== "preferences" && settings.value.status === "loading" && filteredRows.value.length === 0;

watch(
	loadingRows,
	(waiting) => {
		window.clearTimeout(revealTimer);
		if (waiting) {
			revealStarted = Date.now();
			const token = ++revealToken;
			holdReveal.value = true;
			revealTimer = window.setTimeout(() => {
				if (token !== revealToken || loadingRows()) return;
				holdReveal.value = false;
			}, 350);
			return;
		}
		const remain = 350 - (Date.now() - revealStarted);
		if (remain <= 0 || !holdReveal.value) {
			holdReveal.value = false;
			return;
		}
		const token = revealToken;
		revealTimer = window.setTimeout(() => {
			if (token !== revealToken) return;
			holdReveal.value = false;
		}, remain);
	},
	{ immediate: true },
);

const focusRow = (id: string) => {
	focusZone.value = "rows";
	selectedId.value = id;
};

const onCategoryClick = (id: string, index: number) => {
	focusZone.value = "categories";
	categoryCursor.value = index;
	void selectCategory(id);
};

// values
const displayValue = (row: GameSettingRow) => {
	const source = (() => {
		if (row.kind === "cycled") return row.value || row.choices[0] || "";
		if (row.kind === "options") return row.value || row.choices[row.selectedIndex] || "";
		if (row.choices.length > 0) return row.choices[row.selectedIndex] ?? row.value ?? row.choices[0];
		if (row.kind === "slider") return String(row.selectedIndex);
		return row.value;
	})();
	if (row.kind === "slider") return source;
	const index = row.choices.indexOf(source);
	if (index >= 0) return choiceLabel(row, index) || source;
	return sharedLabel(source, categoryIndex());
};

const langDismissKey = "0r-pausemenu:exp-lang-dismiss";
const localeStore = useLocaleStore();
// GetCurrentLanguage() ids that already match a script locale (1 fr, 2 de, 3 it, 4 es, 6 pl, 11 es-MX).
const gameLanguages: Record<string, number[]> = { fr: [1], de: [2], it: [3], es: [4, 11], pl: [6] };
const langOpen = ref(false);
const hideLangAgain = ref(false);
let langChecked = false;

const closeLangWarning = () => {
	if (hideLangAgain.value) localStorage.setItem(langDismissKey, "1");
	langOpen.value = false;
};

const disableExperimental = () => {
	experimentalLabels.value = false;
	langOpen.value = false;
};

watch(experimentalLabels, (enabled, wasEnabled) => {
	if (!wasEnabled || enabled) return;
	langOpen.value = false;
	void fetchNui("SettingsReopen", {}, { ok: false });
});

const useEnglish = () => {
	langOpen.value = false;
	void fetchNui("SettingsUseEnglish", {}, { ok: false });
};

watch(
	() => settings.value.status,
	(status) => {
		if (status !== "ready" || langChecked) return;
		langChecked = true;
		if (!experimentalLabels.value || localStorage.getItem(langDismissKey) === "1") return;
		void fetchNui<{ language: number }>("SettingsLanguage", {}, { language: 0 }).then((result) => {
			if (result.language === 0) return;
			// English labels need no translation, and a game already in the locale's language needs no switch.
			if (localeStore.locale === "en" || gameLanguages[localeStore.locale]?.includes(result.language)) return;
			hideLangAgain.value = false;
			langOpen.value = true;
		});
	},
	{ immediate: true },
);

const sliderWidth = (row: GameSettingRow) => {
	if (row.maxIndex <= 0) return "0%";
	return `${(row.selectedIndex / row.maxIndex) * 100}%`;
};

const canChange = (row: GameSettingRow) =>
	!settings.value.busy && row.editable && (row.kind === "options" || row.kind === "slider" || row.kind === "cycled");

const openCategory = async (id: string) => {
	if (id === settings.value.activeCategoryId && view.value === "settings") return;
	if (settings.value.busy) return;
	view.value = "settings";
	if (id === settings.value.activeCategoryId) return;
	selectedId.value = "";
	await fetchNui("SettingsSetCategory", { id }, { ok: false });
};

const selectCategory = async (id: string) => {
	if (settings.value.busy) return;
	if (id === regularMenuIntent) {
		openRegularMenu();
		return;
	}
	if (id === editIntent) {
		if (settings.value.busy || alert.value.open) return;
		if (settings.value.pendingCount) {
			await fetchNui("SettingsUnsaved", {}, { ok: false });
			return;
		}
		if (view.value === "preferences") return;
		view.value = "preferences";
		return;
	}
	await openCategory(id);
};

const sendChange = async (row: GameSettingRow, payload: { direction?: number; targetIndex?: number }) => {
	if (!row.editable || alert.value.open || settings.value.busy) return;
	await fetchNui("SettingsChange", { index: row.index, ...payload }, { ok: false });
};

const change = (row: GameSettingRow, direction: number) => {
	if (!canChange(row)) return;
	void sendChange(row, { direction });
};

const setValue = (row: GameSettingRow, targetIndex: number) => {
	if (!canChange(row) || row.kind === "cycled") return;
	if (row.kind === "slider") {
		if (targetIndex === row.selectedIndex) return;
	} else if (row.value ? row.choices[targetIndex] === row.value : targetIndex === row.selectedIndex) {
		return;
	}
	void sendChange(row, { targetIndex });
};

const onSliderClick = (event: MouseEvent, row: GameSettingRow) => {
	if (!canChange(row) || row.kind !== "slider") return;
	const element = event.currentTarget as HTMLElement;
	const rect = element.getBoundingClientRect();
	if (rect.width <= 0) return;
	const ratio = Math.min(1, Math.max(0, (event.clientX - rect.left) / rect.width));
	const step = row.step && row.step > 1 ? row.step : 1;
	selectedId.value = row.id;
	setValue(row, Math.round((ratio * row.maxIndex) / step) * step);
};

const activate = (row: GameSettingRow) => {
	if (row.kind !== "button" || !row.editable || settings.value.busy || alert.value.open) return;
	void fetchNui("SettingsActivate", { index: row.index }, { ok: false });
};

const listening = (row: KeyBindingRow) => settings.value.listenIndex === row.index && settings.value.listenSlot === "primary";

const slotLabel = (row: KeyBindingRow) => {
	if (listening(row) && settings.value.listenPhase === "press") return _t("ui.settings.keys.press", "Press a key");
	if (listening(row)) return _t("ui.settings.keys.wait", "Wait");
	return row.primary || _t("ui.settings.keys.unbound", "Unbound");
};

const slotChip =
	"grid w-fit min-h-7 min-w-7 shrink-0 place-items-center rounded-md border border-white/10 bg-white/10 px-2 py-1 font-medium tracking-wide text-white shadow-[inset_0_0_6px_rgb(255_255_255/0.04)]";

const slotVisual = (row: KeyBindingRow) => {
	const waiting = listening(row);
	const armed = focusZone.value === "rows" && selectedId.value === row.id;
	if (!waiting && !row.primary) {
		if (!row.editable) return "text-white/35 opacity-40";
		return armed ? "text-white" : "text-white/40 hover:text-white/70";
	}
	if (waiting) return `${slotChip} bg-[var(--panel-primary)] text-[var(--panel-ink)]`;
	if (!row.editable) return `${slotChip} text-white/35 opacity-40`;
	return armed ? `${slotChip} ring-1 ring-white/50` : `${slotChip} hover:bg-white/20`;
};

const startListen = (row: KeyBindingRow) => {
	focusZone.value = "rows";
	selectedId.value = row.id;
	if (!row.editable || settings.value.busy || alert.value.open) return;
	void fetchNui("SettingsListen", { index: row.index, slot: "primary" }, { ok: false });
};

const applyChanges = () => {
	if (!settings.value.busy) void fetchNui("SettingsApply", {}, { ok: false });
};

const leaveSettings = async () => {
	await fetchNui("PauseBack", {}, { ok: true });
};

const openRegularMenu = () => {
	if (settings.value.busy || alert.value.open) return;
	void fetchNui("PauseOpenVanilla", {}, "ok");
};

const goBack = () => {
	if (settings.value.busy || alert.value.open) return;
	void leaveSettings();
};

// keys
const enterCategory = async () => {
	const items = [...settings.value.categories.map((category) => category.id), editIntent, regularMenuIntent];
	const id = items[categoryCursor.value];
	if (!id) return;
	await selectCategory(id);
	if (id === regularMenuIntent) return;
	if (id !== editIntent && settings.value.keyBindings) {
		focusZone.value = "groups";
		groupCursor.value = Math.max(
			0,
			settings.value.keyGroups.findIndex((group) => group.id === activeKeyGroupId.value),
		);
		selectedId.value = firstNavigableId();
		return;
	}
	focusZone.value = "rows";
	selectedId.value = id === editIntent ? "color" : firstNavigableId();
};

const { onKeyDown } = useSettingsNavigation({
	focusZone,
	categoryCursor,
	groupCursor,
	selectedId,
	view,
	customizeOrder,
	alertOpen: () => alert.value.open,
	listenActive: () => settings.value.listenIndex >= 0,
	busy: () => settings.value.busy,
	pendingCount: () => settings.value.pendingCount,
	keyBindings: () => settings.value.keyBindings,
	keyGroups: () => settings.value.keyGroups,
	categoriesCount: () => settings.value.categories.length,
	navigableRows,
	selectedRow,
	editPane,
	onGroupEnter: onGroupClick,
	onEnterCategory: enterCategory,
	onGoBack: goBack,
	onApply: applyChanges,
	onChangeSetting: change,
	onActivateSetting: activate,
	onStartListen: startListen,
});

watch(listedRows, () => {
	if (view.value === "preferences") return;
	if (!navigableRows().some((row) => row.id === selectedId.value)) selectedId.value = firstNavigableId();
});

watch(activeKeyGroupId, (id) => {
	const index = settings.value.keyGroups.findIndex((group) => group.id === id);
	if (index >= 0) groupCursor.value = index;
});

watch(
	() => settings.value.activeCategoryId,
	(id) => {
		query.value = "";
		selectedId.value = firstNavigableId();
		const index = settings.value.categories.findIndex((category) => category.id === id);
		if (index >= 0) categoryCursor.value = index;
	},
);

const scrollFocused = async (id: string) => {
	if (focusZone.value !== "rows" || !id || holdReveal.value || loadingRows()) return;
	await nextTick();
	document.querySelector(`[data-focus="${CSS.escape(id)}"]`)?.scrollIntoView({ block: "nearest" });
};

watch(selectedId, (id) => {
	void scrollFocused(id);
});
watch(
	() => holdReveal.value || loadingRows(),
	() => {
		void scrollFocused(selectedId.value);
	},
);

onMounted(() => {
	window.addEventListener("keydown", onKeyDown);
});
onUnmounted(() => {
	window.clearTimeout(revealTimer);
	window.removeEventListener("keydown", onKeyDown);
});
</script>
