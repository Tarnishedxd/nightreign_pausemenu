<template>
	<Transition
		enter-active-class="transition duration-200 ease-out"
		enter-from-class="opacity-0"
		enter-to-class="opacity-100"
		leave-active-class="transition duration-200 ease-in"
		leave-from-class="opacity-100"
		leave-to-class="opacity-0">
		<div v-if="alert.open" class="fixed inset-0 z-[100] grid place-items-center bg-black/50 px-6">
			<Transition
				appear
				enter-active-class="transition duration-200 ease-out"
				enter-from-class="translate-y-2 opacity-0"
				enter-to-class="translate-y-0 opacity-100"
				leave-active-class="transition duration-200 ease-in"
				leave-from-class="translate-y-0 opacity-100"
				leave-to-class="translate-y-2 opacity-0">
				<section
					v-if="alert.open"
					ref="dialogRef"
					class="w-full max-w-md rounded-md border border-white/10 bg-white/10 px-5 py-5 shadow-[inset_0_0_6px_rgb(255_255_255/0.04)]"
					:style="panelStyle"
					role="dialog"
					aria-modal="true"
					aria-labelledby="gta-alert-title"
					tabindex="-1">
					<h2 id="gta-alert-title" class="text-base font-semibold text-white">{{ alert.title }}</h2>
					<div class="mt-3 space-y-3">
						<p v-if="alert.body" class="whitespace-pre-wrap text-base leading-6 text-white/75">{{ alert.body }}</p>
						<p v-if="alert.detail" class="whitespace-pre-wrap text-sm leading-5 text-white/50">{{ alert.detail }}</p>
						<p v-if="alert.prompt" class="text-sm leading-5 text-white/45">{{ alert.prompt }}</p>
					</div>
					<footer ref="footerRef" class="mt-5 flex flex-row-reverse justify-end gap-2">
						<button
							v-for="(button, index) in alert.buttons"
							:key="`${button.control}-${index}`"
							type="button"
							class="min-w-24 rounded-md px-4 py-2 text-base transition-colors duration-200"
							:class="
								button.control === 201
									? 'bg-[var(--panel-primary)] text-[var(--panel-ink)]'
									: 'border border-white/10 bg-white/10 text-white/75 hover:bg-white/15'
							"
							:data-control="button.control"
							@click="press(button.control)">
							{{ button.label }}
						</button>
					</footer>
				</section>
			</Transition>
		</div>
	</Transition>
</template>

<script setup lang="ts">
const settingsStore = useSettingsStore();
const { alert } = storeToRefs(settingsStore);
const { panelStyle } = usePreferences();
const resolving = ref(false);
const dialogRef = ref<HTMLElement>();
const footerRef = ref<HTMLElement>();
let previousFocus: HTMLElement | null = null;

const press = async (control: number) => {
	if (resolving.value) return;
	resolving.value = true;
	try {
		await fetchNui("GtaAlertPress", { control }, { ok: false });
	} finally {
		resolving.value = false;
	}
};

const buttonByControl = (control: number) => alert.value.buttons.find((button) => button.control === control);

const footerButtons = () => [...(footerRef.value?.querySelectorAll("button") ?? [])] as HTMLButtonElement[];

const onKeyDown = (event: KeyboardEvent) => {
	if (!alert.value.open || resolving.value) return;
	if (event.key === "Tab") {
		const buttons = footerButtons();
		if (!buttons.length) return;
		event.preventDefault();
		const current = buttons.indexOf(document.activeElement as HTMLButtonElement);
		const direction = event.shiftKey ? -1 : 1;
		buttons[(current + direction + buttons.length) % buttons.length]?.focus();
		return;
	}
	if (event.key === "Enter") {
		event.preventDefault();
		const accept = buttonByControl(201) ?? (alert.value.buttons.length === 1 ? alert.value.buttons[0] : undefined);
		if (accept) void press(accept.control);
		return;
	}
	if (event.key === " " || event.code === "Space") {
		const decline = buttonByControl(203);
		if (!decline) return;
		event.preventDefault();
		void press(decline.control);
		return;
	}
	if (event.key === "Escape" || event.key === "Backspace") {
		const cancel = buttonByControl(202);
		if (!cancel) return;
		event.preventDefault();
		void press(cancel.control);
	}
};

watch(
	() => alert.value.open,
	async (open) => {
		if (open) {
			previousFocus = document.activeElement as HTMLElement | null;
			await nextTick();
			const accept = footerButtons().find((button) => button.dataset.control === "201") ?? footerButtons().at(-1);
			(accept ?? dialogRef.value)?.focus();
			return;
		}
		previousFocus?.focus();
		previousFocus = null;
	},
);

onMounted(() => window.addEventListener("keydown", onKeyDown));
onUnmounted(() => window.removeEventListener("keydown", onKeyDown));
</script>
